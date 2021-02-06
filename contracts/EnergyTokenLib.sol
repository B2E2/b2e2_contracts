pragma solidity ^0.7.0;

import "./IEnergyToken.sol";
import "./ClaimVerifier.sol";

library EnergyTokenLib {
    struct EnergyDocumentation {
        IdentityContract documentingMeteringAuthority;
        uint256 value;
        bool corrected;
        bool generated;
        bool entered;
    }
    
    struct ForwardKindOfGenerationPlant {
        IEnergyToken.TokenKind forwardKind;
        bool set;
    }
    
    // ########################
    // # Public support functions
    // ########################
    /**
     * tokenId: zeros (24 bit) || tokenKind number (8 bit) || balancePeriod (64 bit) || address of IdentityContract (160 bit)
     */
    function getTokenId(IEnergyToken.TokenKind _tokenKind, uint64 _balancePeriod, address _identityContractAddress) public pure returns (uint256 __tokenId) {
        __tokenId = 0;
        
        __tokenId += tokenKind2Number(_tokenKind);
        __tokenId = __tokenId << 64;
        __tokenId += _balancePeriod;
        __tokenId = __tokenId << 160;
        __tokenId += uint256(_identityContractAddress);
    }
    
        /**
     * | Bit (rtl) | Meaning                                         |
     * |-----------+-------------------------------------------------|
     * |         0 | Genus (Generation-based 0; Consumption-based 1) |
     * |         1 | Genus (Absolute 0; Relative 1)                  |
     * |         2 | Family (Forwards 0; Certificates 1)             |
     * |         3 |                                                 |
     * |         4 |                                                 |
     * |         5 |                                                 |
     * |         6 |                                                 |
     * |         7 |                                                 |
     * 
     * Bits are zero unless specified otherwise.
     */
    function tokenKind2Number(IEnergyToken.TokenKind _tokenKind) public pure returns (uint8 __number) {
        if(_tokenKind == IEnergyToken.TokenKind.AbsoluteForward) {
            return 0;
        }
        if(_tokenKind == IEnergyToken.TokenKind.GenerationBasedForward) {
            return 2;
        }
        if(_tokenKind == IEnergyToken.TokenKind.ConsumptionBasedForward) {
            return 3;
        }
        if(_tokenKind == IEnergyToken.TokenKind.Certificate) {
            return 4;
        }
        
        // Invalid TokenKind.
        require(false, "Invalid TokenKind.");
    }
    
    function number2TokenKind(uint8 _number) public pure returns (IEnergyToken.TokenKind __tokenKind) {
        if(_number == 0) {
            return IEnergyToken.TokenKind.AbsoluteForward;
        }
        if(_number == 2) {
            return IEnergyToken.TokenKind.GenerationBasedForward;
        }
        if(_number == 3) {
            return IEnergyToken.TokenKind.ConsumptionBasedForward;
        }
        if(_number == 4) {
            return IEnergyToken.TokenKind.Certificate;
        }
        
        // Invalid number.
        require(false, "Invalid number.");
    }
    
    function getTokenIdConstituents(uint256 _tokenId) public pure returns(IEnergyToken.TokenKind __tokenKind, uint64 __balancePeriod, address __identityContractAddress) {
        __identityContractAddress = address(uint160(_tokenId));
        __balancePeriod = uint64(_tokenId >> 160);
        __tokenKind = number2TokenKind(uint8(_tokenId >> (160 + 64)));
        
        // Make sure that the tokenId can actually be derived via getTokenId().
        // Without this check, it would be possible to create a second but different tokenId with the same constituents as not all bits are used.
        require(getTokenId(__tokenKind, __balancePeriod, __identityContractAddress) == _tokenId, "tokenId cannot be derived via getTokenId method.");
    }
    
        /**
     * Checks all claims required for the particular given transfer regarding the sending side.
     */
    function checkClaimsForTransferSending(IdentityContract marketAuthority, mapping(uint256 => Distributor) storage id2Distributor, address payable _from, string memory _realWorldPlantId, uint256 _id) public view {
        (IEnergyToken.TokenKind tokenKind, ,) = getTokenIdConstituents(_id);
        if(tokenKind == IEnergyToken.TokenKind.AbsoluteForward || tokenKind == IEnergyToken.TokenKind.GenerationBasedForward || tokenKind == IEnergyToken.TokenKind.ConsumptionBasedForward) {
            uint256 balanceClaimId = ClaimVerifier.getClaimOfType(marketAuthority, _from, _realWorldPlantId, ClaimCommons.ClaimType.BalanceClaim);
            require(balanceClaimId != 0, "Invalid  BalanceClaim.");
            require(ClaimVerifier.getClaimOfType(marketAuthority, _from, _realWorldPlantId, ClaimCommons.ClaimType.ExistenceClaim) != 0, "Invalid  ExistenceClaim.");
            require(ClaimVerifier.getClaimOfType(marketAuthority, _from, _realWorldPlantId, ClaimCommons.ClaimType.MeteringClaim) != 0, "Invalid  MeteringClaim.");
            
            (, , address balanceAuthoritySender, , ,) = IdentityContract(_from).getClaim(balanceClaimId);
            Distributor distributor = id2Distributor[_id];
            require(ClaimVerifier.getClaimOfTypeByIssuer(marketAuthority, address(distributor), ClaimCommons.ClaimType.AcceptedDistributorClaim, balanceAuthoritySender) != 0, "Invalid AcceptedDistributorClaim.");
            return;
        }
        
        if(tokenKind == IEnergyToken.TokenKind.Certificate) {
            return;
        }
        
        require(false, "Unknown tokenKind.");
    }
    
    /**
     * Checks all claims required for the particular given transfer regarding the reception side.
     */
    function checkClaimsForTransferReception(IdentityContract marketAuthority, mapping(uint256 => Distributor) storage id2Distributor, address payable _to, string memory _realWorldPlantId, uint256 _id) public view {
        (IEnergyToken.TokenKind tokenKind, ,) = getTokenIdConstituents(_id);
        if(tokenKind == IEnergyToken.TokenKind.AbsoluteForward || tokenKind == IEnergyToken.TokenKind.GenerationBasedForward || tokenKind == IEnergyToken.TokenKind.ConsumptionBasedForward) {
            uint256 balanceClaimId = ClaimVerifier.getClaimOfType(marketAuthority, _to, _realWorldPlantId, ClaimCommons.ClaimType.BalanceClaim);
            require(balanceClaimId != 0, "Invalid  BalanceClaim.");
            require(ClaimVerifier.getClaimOfType(marketAuthority, _to, _realWorldPlantId, ClaimCommons.ClaimType.ExistenceClaim) != 0,"Invalid ExistenceClaim." );
            require(ClaimVerifier.getClaimOfType(marketAuthority, _to, _realWorldPlantId, ClaimCommons.ClaimType.MeteringClaim) != 0,"Invalid  MeteringClaim.");

            if (tokenKind == IEnergyToken.TokenKind.ConsumptionBasedForward) {
                require(ClaimVerifier.getClaimOfType(marketAuthority, _to, _realWorldPlantId, ClaimCommons.ClaimType.MaxPowerConsumptionClaim) != 0, "Invalid  MaxPowerConsumptionClaim.");
            }

            (, , address balanceAuthorityReceiver, , ,) = IdentityContract(_to).getClaim(balanceClaimId);
            Distributor distributor = id2Distributor[_id];
            require(ClaimVerifier.getClaimOfTypeByIssuer(marketAuthority, address(distributor), ClaimCommons.ClaimType.AcceptedDistributorClaim, balanceAuthorityReceiver) != 0, "Invalid AcceptedDistributorClaim.");
            return;
        }
        
        if(tokenKind == IEnergyToken.TokenKind.Certificate) {
            return;
        }
        
        require(false, "Unknown tokenKind.");
    }
    
    // ########################
    // # Internal functions
    // ########################
    function getPlantGenerationCapability(IdentityContract marketAuthority, address _plant, string memory _realWorldPlantId) public view returns (uint256 __maxGen) {
        uint256 maxPowerGenerationClaimId = ClaimVerifier.getClaimOfType(marketAuthority, _plant, _realWorldPlantId, ClaimCommons.ClaimType.MaxPowerGenerationClaim);
        (, , , , bytes memory claimData, ) = IdentityContract(_plant).getClaim(maxPowerGenerationClaimId);
        __maxGen = ClaimVerifier.getUint256Field("maxGen", claimData);
    }

    function getPlantConsumptionCapability(IdentityContract marketAuthority, address _plant, string memory _realWorldPlantId) internal view returns (uint256 __maxCon) {
        uint256 maxPowerConsumptionClaimId = ClaimVerifier.getClaimOfType(marketAuthority, _plant, _realWorldPlantId, ClaimCommons.ClaimType.MaxPowerConsumptionClaim);

        if (maxPowerConsumptionClaimId == 0)
            return 0;

        (, , , , bytes memory claimData, ) = IdentityContract(_plant).getClaim(maxPowerConsumptionClaimId);
        __maxCon = ClaimVerifier.getUint256Field("maxCon", claimData);
    }

    function setId2Distributor(mapping(uint256 => Distributor) storage id2Distributor, uint256 _id, Distributor _distributor) public {
        if(id2Distributor[_id] == _distributor)
            return;
        
        if(id2Distributor[_id] != Distributor(0))
            require(false, "Distributor _id already used.");
        
        id2Distributor[_id] = _distributor;
    }
    
    function setForwardKindOfGenerationPlant(mapping(uint64 => mapping(address => ForwardKindOfGenerationPlant)) storage forwardKindOfGenerationPlant, uint64 _balancePeriod, address _generationPlant, IEnergyToken.TokenKind _forwardKind) public {
        if(!forwardKindOfGenerationPlant[_balancePeriod][_generationPlant].set) {
            forwardKindOfGenerationPlant[_balancePeriod][_generationPlant].forwardKind = _forwardKind;
            forwardKindOfGenerationPlant[_balancePeriod][_generationPlant].set = true;
        } else {
            require(_forwardKind == forwardKindOfGenerationPlant[_balancePeriod][_generationPlant].forwardKind, "Cannot set _forwardKind.");
        }
    }
}