pragma solidity ^0.5.0;

import "./Commons.sol";
import "./IdentityContractFactory.sol";
import "./IdentityContract.sol";
import "./ClaimVerifier.sol";
import "./../dependencies/erc-1155/contracts/ERC1155.sol";

contract EnergyToken is ERC1155 {
    using SafeMath for uint256;
    using Address for address;
    
    event RequestTransfer(address recipient, address sender, uint256 value, uint64 expiryDate, uint256 tokenId);
    
    enum TokenKind {AbsoluteForward, GenerationBasedForward, ConsumptionBasedForward, Certificate}
    
    // id => (receiver => (sender => PerishableValue))
    mapping (uint256 => mapping(address => mapping(address => PerishableValue))) receptionApproval;
    
    // id => whetherCreated
    mapping (uint256 => bool) createdGenerationBasedForwards;
    
    struct PerishableValue {
        uint256 value;
        uint64 expiryDate;
    }
    
    struct EnergyDocumentation {
        uint256 value;
        bool corrected;
        bool generated;
    }
    
    IdentityContract marketAuthority;
    IdentityContractFactory identityContractFactory;
    mapping(address => bool) meteringAuthorityExistenceLookup;
    mapping(address => mapping(uint64 => EnergyDocumentation)) energyDocumentations;
    mapping(uint64 => uint256) energyConsumpedInBalancePeriod;

    constructor(IdentityContract _marketAuthority, IdentityContractFactory _identityContractFactory) public {
        marketAuthority = _marketAuthority;
        identityContractFactory = _identityContractFactory;
    }
    
    function mint(uint256 _id, address[] memory _to, uint256[] memory _quantities) public returns(uint256 __id) {
        // Token needs to be mintable.
        (TokenKind tokenKind, uint64 balancePeriod, address generationPlant) = getTokenIdConstituents(_id);
        require(tokenKind == TokenKind.AbsoluteForward || tokenKind == TokenKind.ConsumptionBasedForward || tokenKind == TokenKind.Certificate);
        
        // msg.sender needs to be allowed to mint.
        if(tokenKind == TokenKind.Certificate) {
            require(identityContractFactory.isRegisteredIdentityContract(msg.sender));
            require(ClaimVerifier.getClaimOfType(marketAuthority, msg.sender, ClaimCommons.ClaimType.IsMeteringAuthority, true, true) != 0);
        } else {
            require(msg.sender == generationPlant);
        }
        
        require(identityContractFactory.isRegisteredIdentityContract(generationPlant));
        address payable generationPlantP = address(uint160(generationPlant));
        require(ClaimVerifier.getClaimOfType(marketAuthority, generationPlantP, ClaimCommons.ClaimType.BalanceClaim, true, true) != 0);
        require(ClaimVerifier.getClaimOfType(marketAuthority, generationPlantP, ClaimCommons.ClaimType.ExistenceClaim, true, true) != 0);
        require(ClaimVerifier.getClaimOfType(marketAuthority, generationPlantP, ClaimCommons.ClaimType.GenerationTypeClaim, true, true) != 0);
        require(ClaimVerifier.getClaimOfType(marketAuthority, generationPlantP, ClaimCommons.ClaimType.LocationClaim, true, true) != 0);
        require(ClaimVerifier.getClaimOfType(marketAuthority, generationPlantP, ClaimCommons.ClaimType.MeteringClaim, true, true) != 0);

        // balancePeriod must not be in the past. // TODO: FIX
        // require(balancePeriod >= Commons.getBalancePeriod());
        
        for (uint256 i = 0; i < _to.length; ++i) {
            address to = _to[i];
            uint256 quantity = _quantities[i];

            require(to != address(0x0), "_to must be non-zero.");

            if(to != msg.sender)
                consumeReceptionApproval(_id, to, msg.sender, quantity);

            // Grant the items to the caller.
            balances[_id][to] = quantity.add(balances[_id][to]);
            supply[_id] = supply[_id].add(balances[_id][to]);
            // Emit the Transfer/Mint event.
            // the 0x0 source address implies a mint
            // It will also provide the circulating supply info.
            emit TransferSingle(msg.sender, address(0x0), to, _id, quantity);

            if (to.isContract()) {
                _doSafeTransferAcceptanceCheck(msg.sender, msg.sender, to, _id, quantity, '');
            }
        }
        
        __id = _id;
    }
    
    modifier onlyMeteringAuthorities {
        require(ClaimVerifier.getClaimOfType(marketAuthority, msg.sender, ClaimCommons.ClaimType.IsMeteringAuthority, true, true) != 0);
        _;
    }
    
    modifier onlyGenerationPlants {
        require(ClaimVerifier.getClaimOfType(marketAuthority, msg.sender, ClaimCommons.ClaimType.ExistenceClaim, true, true) != 0);
        require(ClaimVerifier.getClaimOfType(marketAuthority, msg.sender, ClaimCommons.ClaimType.BalanceClaim, true, true) != 0);
        require(ClaimVerifier.getClaimOfType(marketAuthority, msg.sender, ClaimCommons.ClaimType.MeteringClaim, true, true) != 0);
        _;
    }
    
    function createGenerationBasedForwards(uint64 _balancePeriod, address _distributor) public onlyGenerationPlants returns(uint256 __id) {
        __id = getTokenId(TokenKind.GenerationBasedForward, _balancePeriod, msg.sender);
        
        require(!createdGenerationBasedForwards[__id]);
        createdGenerationBasedForwards[__id] = true;
        
        uint256 value = 100E18;
        balances[__id][_distributor] = value;
        supply[__id] = supply[__id].add(value);
        emit TransferSingle(msg.sender, address(0x0), _distributor, __id, value);
    }

    function addMeasuredEnergyConsumption(address _plant, uint256 _value, uint64 _balancePeriod, bool _corrected) onlyMeteringAuthorities public returns (bool __success) {
        // Don't allow a corrected value to be overwritten with a non-corrected value.
        if(energyDocumentations[_plant][_balancePeriod].corrected && !_corrected) {
            assert(false);
        }
        
        // In case this is merely a correction, remove the previously stated value from the total.
        energyConsumpedInBalancePeriod[_balancePeriod] = energyConsumpedInBalancePeriod[_balancePeriod].sub(energyDocumentations[_plant][_balancePeriod].value);
        
        EnergyDocumentation memory energyDocumentation = EnergyDocumentation(_value, _corrected, false);
        energyDocumentations[_plant][_balancePeriod] = energyDocumentation;
        
        energyConsumpedInBalancePeriod[_balancePeriod] = energyConsumpedInBalancePeriod[_balancePeriod].add(_value);
        
        return true;
    }
    
    function addMeasuredEnergyGeneration(address _plant, uint256 _value, uint64 _balancePeriod, bool _corrected) onlyMeteringAuthorities public returns (bool __success) {
        // Don't allow a corrected value to be overwritten with a non-corrected value.
        if(energyDocumentations[_plant][_balancePeriod].corrected && !_corrected) {
            assert(false);
        }
        
        EnergyDocumentation memory energyDocumentation = EnergyDocumentation(_value, _corrected, true);
        energyDocumentations[_plant][_balancePeriod] = energyDocumentation;
        
        return true;
    }
    
    function getConsumedEnergyOfBalancePeriod(uint64 _balancePeriod) public view returns (uint256) {
        return energyConsumpedInBalancePeriod[_balancePeriod];
    }
    
    /**
     * tokenId: zeros (24 bit) || tokenKind number (8 bit) || balancePeriod (64 bit) || address of IdentityContract (160 bit)
     */
    function getTokenId(TokenKind _tokenKind, uint64 _balancePeriod, address _identityContractAddress) public pure returns (uint256 __tokenId) {
        __tokenId = 0;
        
        __tokenId += tokenKind2Number(_tokenKind);
        __tokenId = __tokenId << 64;
        __tokenId += _balancePeriod;
        __tokenId = __tokenId << 160;
        __tokenId += uint256(_identityContractAddress);
    }
    
    function getTokenIdConstituents(uint256 _tokenId) public pure returns(TokenKind __tokenKind, uint64 __balancePeriod, address __identityContractAddress) {
        __identityContractAddress = address(uint160(_tokenId));
        __balancePeriod = uint64(_tokenId >> 160);
        __tokenKind = number2TokenKind(uint8(_tokenId >> (160 + 64)));
        
        // Make sure that the tokenId can actually be derived via getTokenId().
        // Without this check, it would be possible to create a second but different tokenId with the same constituents as not all bits are used.
        require(getTokenId(__tokenKind, __balancePeriod, __identityContractAddress) == _tokenId);
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
    function tokenKind2Number(TokenKind _tokenKind) public pure returns (uint8 __number) {
        if(_tokenKind == TokenKind.AbsoluteForward) {
            return 0;
        }
        if(_tokenKind == TokenKind.GenerationBasedForward) {
            return 2;
        }
        if(_tokenKind == TokenKind.ConsumptionBasedForward) {
            return 3;
        }
        if(_tokenKind == TokenKind.Certificate) {
            return 4;
        }
        
        // Invalid TokenKind.
        require(false);
    }
    
    function number2TokenKind(uint8 _number) public pure returns (TokenKind __tokenKind) {
        if(_number == 0) {
            return TokenKind.AbsoluteForward;
        }
        if(_number == 2) {
            return TokenKind.GenerationBasedForward;
        }
        if(_number == 3) {
            return TokenKind.ConsumptionBasedForward;
        }
        if(_number == 4) {
            return TokenKind.Certificate;
        }
        
        // Invalid number.
        require(false);
    }
    
    function approveSender(address _sender, uint64 _expiryDate, uint256 _value, uint256 _id) public returns (bool __success) {
        receptionApproval[_id][msg.sender][_sender] = PerishableValue(_value, _expiryDate);
        emit RequestTransfer(msg.sender, _sender, _value, _expiryDate, _id);
        return true;
    }
    
    function approveBatchSender(address _sender, uint64 _expiryDate, uint256[] memory _values, uint256[] memory _ids) public {
        require(_values.length < 4294967295);
        
        for(uint32 i; i < _values.length; i++) {
            receptionApproval[_ids[i]][msg.sender][_sender] = PerishableValue(_values[i], _expiryDate);
        }
    }
    
    /**
     * Only consumes reception approval when handling forwards. Fails iff granted reception approval is insufficient.
     */
    function consumeReceptionApproval(uint256 _id, address _to, address _from, uint256 _value) internal {
        (TokenKind tokenKind, ,) = getTokenIdConstituents(_id); // Can be optimized by simply checking the bit that determines whether it's a forward or a certificate via a bit mask. Useful when tokenId format doesn't change anymore.
        if(tokenKind == TokenKind.Certificate)
            return;
        
        require(receptionApproval[_id][_to][_from].expiryDate >= Commons.getBalancePeriod());
        require(receptionApproval[_id][_to][_from].value >= _value);
        
        receptionApproval[_id][_to][_from].value = receptionApproval[_id][_to][_from].value.sub(_value);
    }
    
    /**
     * Checks all claims required for the particular given transfer.
     * 
     * Checking a claim only makes sure that it exists. It does not verify the claim. However, this method makes sure that only non-expired claims are considered.
     */
    function checkClaimsForTransfer(address payable _from, address payable _to, uint256 _id, uint256 _value) internal view {
        (TokenKind tokenKind, ,) = getTokenIdConstituents(_id);
        if(tokenKind == TokenKind.AbsoluteForward || tokenKind == TokenKind.GenerationBasedForward || tokenKind == TokenKind.ConsumptionBasedForward) {
            require(identityContractFactory.isRegisteredIdentityContract(_from));
            require(ClaimVerifier.getClaimOfType(marketAuthority, _from, ClaimCommons.ClaimType.BalanceClaim, true, true) != 0);
            require(ClaimVerifier.getClaimOfType(marketAuthority, _from, ClaimCommons.ClaimType.ExistenceClaim, true, true) != 0);
            require(ClaimVerifier.getClaimOfType(marketAuthority, _from, ClaimCommons.ClaimType.GenerationTypeClaim, true, true) != 0);
            require(ClaimVerifier.getClaimOfType(marketAuthority, _from, ClaimCommons.ClaimType.LocationClaim, true, true) != 0);
            require(ClaimVerifier.getClaimOfType(marketAuthority, _from, ClaimCommons.ClaimType.MeteringClaim, true, true) != 0);
            
            require(identityContractFactory.isRegisteredIdentityContract(_to));
            uint256 balanceClaimId = ClaimVerifier.getClaimOfType(marketAuthority, _to, ClaimCommons.ClaimType.BalanceClaim, true, true);
            (, , address balanceAuthority, , ,) = IdentityContract(_to).getClaim(balanceClaimId);
            
            require(identityContractFactory.isRegisteredIdentityContract(balanceAuthority));
            string memory addressHexString = addressToHexString(_to);
            require(ClaimVerifier.getClaimOfTypeWithMatchingField(marketAuthority, balanceAuthority, ClaimCommons.ClaimType.AcceptedDistributorContractsClaim, "address", addressHexString, true, true) != 0);

            return;
        }
        
        if(tokenKind == TokenKind.Certificate) {
            return;
        }
        
        require(false);
    }
    
    function addressToHexString(address x) internal pure returns (string memory) {
        bytes memory b = new bytes(20);
        for (uint i = 0; i < 20; i++)
            b[i] = byte(uint8(uint(x) / (2**(8*(19 - i)))));
        return string(b);
    }
    
    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes memory _data) public {
        checkClaimsForTransfer(address(uint160(_from)), address(uint160(_to)), _id, _value);
        consumeReceptionApproval(_id, _to, _from, _value);
        ERC1155.safeTransferFrom(_from, _to, _id, _value, _data);
    }
    
    function safeBatchTransferFrom(address _from, address _to, uint256[] memory _ids, uint256[] memory _values, bytes memory _data) public {
        address payable fromPayable = address(uint160(_from));
        address payable toPayable = address(uint160(_to));
        for (uint256 i = 0; i < _ids.length; ++i) {
            checkClaimsForTransfer(fromPayable, toPayable, _ids[i], _values[i]);
            consumeReceptionApproval(_ids[i], _to, _from, _values[i]);
        }
        ERC1155.safeBatchTransferFrom(_from, _to, _ids, _values, _data);
    }
}
