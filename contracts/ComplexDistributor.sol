// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "./AbstractDistributor.sol";
import "./EnergyToken.sol";
import "./EnergyTokenLib.sol";
import "./IEnergyToken.sol";

/**
 * The ComplexDistributor is used to distribute certificates based on the ownership of
 * property forwards.
 */
contract ComplexDistributor is AbstractDistributor {
    EnergyToken public energyToken;
    
    // consumption plant address => forward ID => certificate ID => value used up
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) distributionValueUsedUp;
    // forward ID => criteria
    mapping(uint256 => EnergyTokenLib.Criterion[]) propertyForwardsCriteria;
    // forward ID => bool
    mapping(uint256 => bool) propertyForwardsCriteriaSet;
    // debtor address => forward ID => certificate ID => amount
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) public certificates;
    // debtor address => forward ID => sum of certificate amounts
    mapping(address => mapping(uint256 => uint256)) public certificateTotals;
    
    bool testing;
    
    modifier onlyEnergyToken() {
        require(msg.sender == address(energyToken), "only the energy token contract may invoke this function");
        _;
    }

    constructor(EnergyToken _energyToken, bool _testing, address _owner)
    IdentityContract(_energyToken.marketAuthority(), IdentityContract.BalancePeriodConfiguration(0, 0, 0), _owner) {
        energyToken = _energyToken;
        testing = _testing;
    }
    
    // For the definitions of the interface identifiers, see InterfaceIds.sol.
    function supportsInterface(bytes4 interfaceID) override(IdentityContract) external pure returns (bool) {
        return
            interfaceID == 0x01ffc9a7 ||
            interfaceID == 0x6f15538d ||
            interfaceID == 0x848a042c ||
            interfaceID == 0x1fd50459 ||
            interfaceID == 0x2e33b44b;
    }
    
    function setPropertyForwardsCriteria(uint256 _tokenId, EnergyTokenLib.Criterion[] calldata _criteria) external onlyEnergyToken {
        require(!propertyForwardsCriteriaSet[_tokenId], "criteria already set");
        propertyForwardsCriteriaSet[_tokenId] = true;
        
        // Copying struct arrays directy is not supported, so this workaround needs to be used.
        for(uint32 i = 0; i < _criteria.length; i++)
            propertyForwardsCriteria[_tokenId].push(_criteria[0]);
    }
    
    function onERC1155Received(address /*_operator*/, address _from, uint256 _id, uint256 _value, bytes calldata _data) override(IdentityContract) onlyEnergyToken public returns(bytes4) {
        require(EnergyTokenLib.tokenKindFromTokenId(_id) == IEnergyToken.TokenKind.Certificate, "only certificates");
        
        // Get the forward ID the certificates are applicable to from the data field.
        require(_data.length == 32, "Wrong data length.");
        uint256 forwardId = abi.decode(_data, (uint256));
        
        // Make sure that the certificates are applicable.
        checkApplicability(_id, forwardId);
        
        // Make sure that _from is a storage plant.
        (, uint64 certificateBalancePeriod, ) = energyToken.getTokenIdConstituents(_id);
        ClaimVerifier.f_onlyStoragePlants(marketAuthority, _from, certificateBalancePeriod);
        
        // Increment internally kept balance.
        certificates[_from][forwardId][_id] += _value;

        // Make sure that no extra certificates are sent.
        certificateTotals[_from][forwardId] += _value;
        (, uint256 energyGenerated, , bool generated, ) = energyToken.energyDocumentations(_from, certificateBalancePeriod);
        require(generated, "The storage plant did not generate energy.");
        require(certificateTotals[_from][forwardId] <= energyGenerated, "Too many certificates for energy generation.");
        
        return 0xf23a6e61;
    }
    
    function onERC1155BatchReceived(address _operator, address _from, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) override(IdentityContract) external returns(bytes4) {
        require(_ids.length == _values.length, "length mismatch");
        for(uint32 i = 0; i < _ids.length; i++) {
            onERC1155Received(_operator, _from, _ids[i], _values[i], _data);
        }
        
        return 0xbc197c81;
    }
    
    function distribute(address payable _consumptionPlantAddress, uint256 _forwardId, uint256 _certificateId, uint256 _value) external {
        // Distributor applicability check. Required because this contract holding the necessary certificates to pay the consumption plant
        // is not sufficient grouns to assume that this is the correct distributor as soon as several forwards may cause payout of the
        // same certificates.
        require(energyToken.id2Distributor(_forwardId) == this, "Distributor contract does not belong to this _tokenId");
        
        // Check whether enough forwards are present.
        distributionValueUsedUp[_consumptionPlantAddress][_forwardId][_certificateId] += _value;
        uint256 forwardsBalance = energyToken.balanceOf(_consumptionPlantAddress, _forwardId);
        require(forwardsBalance >= distributionValueUsedUp[_consumptionPlantAddress][_forwardId][_certificateId], "insufficient forwards");
        
        // Time period check
        (IEnergyToken.TokenKind forwardKind, uint64 balancePeriod, address debtorAddress) = energyToken.getTokenIdConstituents(_forwardId);
        require(testing || balancePeriod < getBalancePeriod(block.timestamp), "balancePeriod has not yet ended.");
        
        // Forward kind check.
        require(forwardKind == IEnergyToken.TokenKind.PropertyForward, "incorrect forward kind");
        
        // The property check was already done when the certificates were added to this distributor.
        
        // Reduction of debtor balance (reverts on overflow).
        certificates[debtorAddress][_forwardId][_certificateId] -= _value;
        
        // Convertion to new balance period.
        uint256 newCertificateId = energyToken.temporallyTransportCertificates(_certificateId, _forwardId, _value);
        
        // Actual distribution.
        energyToken.safeTransferFrom(address(this), _consumptionPlantAddress, newCertificateId, _value, abi.encode(_forwardId));
    }
    
    /**
     * Must only be called by storage plants. Sends surplus certificates to the calling storage plant.
     */
    function withdrawSurplusCertificates(uint256 _forwardId, uint256 _certificateId, uint256 _value) external {
        certificates[msg.sender][_forwardId][_certificateId] -= _value;
        energyToken.safeTransferFrom(address(this), msg.sender, _certificateId, _value, abi.encode(_forwardId));
    }
    
    // ########################
    // # Internal functions
    // ########################
    function checkApplicability(uint256 _certificateId, uint256 _forwardId) internal view {
        (, uint64 certificateBalancePeriod, address certificateGenerationPlant) = energyToken.getTokenIdConstituents(_certificateId);
        string memory realWorldPlantId = ClaimVerifier.getRealWorldPlantId(marketAuthority, certificateGenerationPlant);
        
        require(propertyForwardsCriteriaSet[_forwardId], "criteria not set");
        
        EnergyTokenLib.Criterion[] storage criteria = propertyForwardsCriteria[_forwardId];
        require(criteria.length > 0, "criteria length is zero");
        
        for(uint32 i = 0; i < criteria.length; i++) {
            EnergyTokenLib.Criterion storage criterion = criteria[i];
            
            ClaimCommons.ClaimType claimType = ClaimCommons.topic2ClaimType(criterion.topicId);

            if(criterion.operator == EnergyTokenLib.Operator.eq) {
                if(criterion.fieldValue.length > 0)
                    require(ClaimVerifier.getClaimOfTypeWithMatchingField(marketAuthority, certificateGenerationPlant, realWorldPlantId, claimType, criterion.fieldName, string(criterion.fieldValue), certificateBalancePeriod) != 0, "certificate ID not applicable");
                else
                    require(ClaimVerifier.getClaimOfType(marketAuthority, certificateGenerationPlant, realWorldPlantId, claimType, certificateBalancePeriod) != 0, "certificate ID not applicable");
            } else {
                if(criterion.operator == EnergyTokenLib.Operator.geq) {
                    require(ClaimVerifier.getClaimOfTypeWithGeqField(marketAuthority, certificateGenerationPlant, realWorldPlantId, claimType, criterion.fieldName, string(criterion.fieldValue), certificateBalancePeriod) != 0, "certificate ID not applicable");
                } else {
                    require(ClaimVerifier.getClaimOfTypeWithLeqField(marketAuthority, certificateGenerationPlant, realWorldPlantId, claimType, criterion.fieldName, string(criterion.fieldValue), certificateBalancePeriod) != 0, "certificate ID not applicable");
                }
            }
        }
    }
}
