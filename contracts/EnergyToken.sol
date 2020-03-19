pragma solidity ^0.5.0;

import "./Commons.sol";
import "./IdentityContractFactory.sol";
import "./Distributor.sol";
import "./ClaimVerifier.sol";
import "./../dependencies/erc-1155/contracts/ERC1155.sol";

contract EnergyToken is ERC1155 {
    using SafeMath for uint256;
    using Address for address;
    
    enum TokenKind {AbsoluteForward, GenerationBasedForward, ConsumptionBasedForward, Certificate}
    
    event ForwardsCreated(TokenKind tokenKind, uint64 balancePeriod, Distributor distributor, uint256 id);
    
    // id => whetherCreated
    mapping (uint256 => bool) createdGenerationBasedForwards;
    
    struct EnergyDocumentation {
        uint256 value;
        bool corrected;
        bool generated;
    }
    
    IdentityContract marketAuthority;
    IdentityContractFactory identityContractFactory;
    mapping(address => bool) meteringAuthorityExistenceLookup;
    mapping(address => mapping(uint64 => EnergyDocumentation)) public energyDocumentations;
    mapping(uint64 => uint256) public energyConsumpedInBalancePeriod;
    mapping(uint256 => Distributor) id2Distributor;

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
            require(ClaimVerifier.getClaimOfType(marketAuthority, msg.sender, ClaimCommons.ClaimType.IsMeteringAuthority) != 0);
        } else {
            require(msg.sender == generationPlant);
            require(balancePeriod > Commons.getBalancePeriod());
        }
        
        address payable generationPlantP = address(uint160(generationPlant));
        require(ClaimVerifier.getClaimOfType(marketAuthority, generationPlantP, ClaimCommons.ClaimType.BalanceClaim, balancePeriod) != 0);
        require(ClaimVerifier.getClaimOfType(marketAuthority, generationPlantP, ClaimCommons.ClaimType.ExistenceClaim, balancePeriod) != 0);
        require(ClaimVerifier.getClaimOfType(marketAuthority, generationPlantP, ClaimCommons.ClaimType.GenerationTypeClaim, balancePeriod) != 0);
        require(ClaimVerifier.getClaimOfType(marketAuthority, generationPlantP, ClaimCommons.ClaimType.LocationClaim, balancePeriod) != 0);
        require(ClaimVerifier.getClaimOfType(marketAuthority, generationPlantP, ClaimCommons.ClaimType.MeteringClaim, balancePeriod) != 0);
        
        for (uint256 i = 0; i < _to.length; ++i) {
            address to = _to[i];
            uint256 quantity = _quantities[i];

            require(to != address(0x0), "_to must be non-zero.");

            if(to != msg.sender) {
                checkClaimsForTransfer(address(uint160(msg.sender)), address(uint160(to)), _id);
            }

            // Grant the items to the caller.
            balances[_id][to] = quantity.add(balances[_id][to]);
            supply[_id] = supply[_id].add(balances[_id][to]);
            // Emit the Transfer/Mint event.
            // the 0x0 source address implies a mint
            // It will also provide the circulating supply info.
            emit TransferSingle(msg.sender, address(0x0), to, _id, quantity);

            if (to.isContract() && to != msg.sender) {
                _doSafeTransferAcceptanceCheck(msg.sender, msg.sender, to, _id, quantity, '');
            }
        }
        
        __id = _id;
    }
    
    modifier onlyMeteringAuthorities {
        require(ClaimVerifier.getClaimOfType(marketAuthority, msg.sender, ClaimCommons.ClaimType.IsMeteringAuthority) != 0);
        _;
    }
    
    modifier onlyGenerationPlants(address _plant, uint64 _balancePeriod) {
        require(ClaimVerifier.getClaimOfType(marketAuthority, _plant, ClaimCommons.ClaimType.BalanceClaim, _balancePeriod) != 0);
        require(ClaimVerifier.getClaimOfType(marketAuthority, _plant, ClaimCommons.ClaimType.ExistenceClaim, _balancePeriod) != 0);
        require(ClaimVerifier.getClaimOfType(marketAuthority, _plant, ClaimCommons.ClaimType.GenerationTypeClaim, _balancePeriod) != 0);
        require(ClaimVerifier.getClaimOfType(marketAuthority, _plant, ClaimCommons.ClaimType.LocationClaim, _balancePeriod) != 0);
        require(ClaimVerifier.getClaimOfType(marketAuthority, _plant, ClaimCommons.ClaimType.MeteringClaim, _balancePeriod) != 0);
        _;
    }
    
    function createForwards(uint64 _balancePeriod, TokenKind _tokenKind, Distributor _distributor) public onlyGenerationPlants(msg.sender, _balancePeriod) returns(uint256 __id) {
        require(_tokenKind != TokenKind.Certificate);
        require(_balancePeriod > Commons.getBalancePeriod());
        __id = getTokenId(_tokenKind, _balancePeriod, msg.sender);
        
        setId2Distributor(__id, _distributor);
        
        emit ForwardsCreated(_tokenKind, _balancePeriod, _distributor, __id);
        
        if(_tokenKind == TokenKind.GenerationBasedForward) {
            require(!createdGenerationBasedForwards[__id]);
            createdGenerationBasedForwards[__id] = true;
            
            uint256 value = 100E18;
            balances[__id][msg.sender] = value;
            supply[__id] = supply[__id].add(value);
            emit TransferSingle(msg.sender, address(0x0), msg.sender, __id, value);
        }
    }

    function addMeasuredEnergyConsumption(address _plant, uint256 _value, uint64 _balancePeriod, bool _corrected) onlyMeteringAuthorities onlyGenerationPlants(_plant, Commons.getBalancePeriod()) public returns (bool __success) {
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
    
    function addMeasuredEnergyGeneration(address _plant, uint256 _value, uint64 _balancePeriod, bool _corrected) onlyMeteringAuthorities onlyGenerationPlants(_plant, Commons.getBalancePeriod()) public returns (bool __success) {
        // Don't allow a corrected value to be overwritten with a non-corrected value.
        if(energyDocumentations[_plant][_balancePeriod].corrected && !_corrected) {
            assert(false);
        }
        
        EnergyDocumentation memory energyDocumentation = EnergyDocumentation(_value, _corrected, true);
        energyDocumentations[_plant][_balancePeriod] = energyDocumentation;
        
        return true;
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
    
    /**
     * Checks all claims required for the particular given transfer.
     * 
     * Checking a claim only makes sure that it exists. It does not verify the claim. However, this method makes sure that only non-expired claims are considered.
     */
    function checkClaimsForTransfer(address payable _from, address payable _to, uint256 _id) internal view {
        (TokenKind tokenKind, ,) = getTokenIdConstituents(_id);
        if(tokenKind == TokenKind.AbsoluteForward || tokenKind == TokenKind.GenerationBasedForward || tokenKind == TokenKind.ConsumptionBasedForward) {
            require(ClaimVerifier.getClaimOfType(marketAuthority, _to, ClaimCommons.ClaimType.BalanceClaim) != 0);
            require(ClaimVerifier.getClaimOfType(marketAuthority, _to, ClaimCommons.ClaimType.ExistenceClaim) != 0);
            require(ClaimVerifier.getClaimOfType(marketAuthority, _to, ClaimCommons.ClaimType.MeteringClaim) != 0);

            uint256 balanceClaimId = ClaimVerifier.getClaimOfType(marketAuthority, _to, ClaimCommons.ClaimType.BalanceClaim);
            (, , address balanceAuthority, , ,) = IdentityContract(_to).getClaim(balanceClaimId);
            
            require(ClaimVerifier.getClaimOfTypeByIssuer(marketAuthority, _to, ClaimCommons.ClaimType.AcceptedDistributorClaim, balanceAuthority) != 0);
            return;
        }
        
        if(tokenKind == TokenKind.Certificate) {
            return;
        }
        
        require(false);
    }
    
    function addressToHexString(address a) internal pure returns (string memory) {
        bytes memory h = new bytes(40);
        uint160 asInt = uint160(a);
        uint160 mask = 0x00ff00000000000000000000000000000000000000;
        for (uint i = 0; i < 20; i++) {
            uint8 currentByte = uint8(asInt >> (160-(i+1)*8));
            
            h[2*i] = numberToHexDigit(currentByte / 16);
            h[2*i + 1] = numberToHexDigit(currentByte % 16);
        }
        
        return string(h);
    }
    
    function numberToHexDigit(uint8 number) internal pure returns (bytes1) {
        if(number < 10) {
            return bytes1(number + 48);
        } else {
            return bytes1(number - 10 + 97);
        }
    }
    
    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes memory _data) public {
        (TokenKind tokenKind, uint64 balancePeriod, ) = getTokenIdConstituents(_id);
         if(tokenKind != TokenKind.Certificate) {
            require(balancePeriod > Commons.getBalancePeriod());
        }
        
        checkClaimsForTransfer(address(uint160(_from)), address(uint160(_to)), _id);
        ERC1155.safeTransferFrom(_from, _to, _id, _value, _data);
    }
    
    function safeBatchTransferFrom(address _from, address _to, uint256[] memory _ids, uint256[] memory _values, bytes memory _data) public {
        address payable fromPayable = address(uint160(_from));
        address payable toPayable = address(uint160(_to));
        
        uint64 currentBalancePeriod = Commons.getBalancePeriod();
        
        for (uint256 i = 0; i < _ids.length; ++i) {
            (TokenKind tokenKind, uint64 balancePeriod, ) = getTokenIdConstituents(_ids[i]);
            if(tokenKind != TokenKind.Certificate) {
                require(balancePeriod > currentBalancePeriod);
            }

            checkClaimsForTransfer(fromPayable, toPayable, _ids[i]);
        }
        ERC1155.safeBatchTransferFrom(_from, _to, _ids, _values, _data);
    }
    
    function setId2Distributor(uint256 _id, Distributor _distributor) internal {
        if(id2Distributor[_id] == _distributor)
            return;
        
        if(id2Distributor[_id] != Distributor(0))
            require(false);
        
        id2Distributor[_id] = _distributor;
    }
}
