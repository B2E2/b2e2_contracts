pragma solidity ^0.5.0;

import "./IdentityContractFactory.sol";
import "./IdentityContract.sol";
import "./ClaimVerifier.sol";
import "./erc-1155/contracts/ERC1155.sol";

contract EnergyToken is ERC1155, ClaimCommons {
    using SafeMath for uint256;
    using Address for address;
    
    enum TokenKind {AbsoluteForward, GenerationBasedForward, ConsumptionBasedForward, Certificate}
    
    struct EnergyDocumentation {
        uint256 value;
        string signature;
        bool corrected;
        bool generated;
    }
    
    ClaimVerifier claimVerifier;
    IdentityContractFactory identityContractFactory;
    mapping(address => bool) meteringAuthorityExistenceLookup;
    mapping(address => mapping(uint64 => EnergyDocumentation)) energyDocumentations; // TODO: powerConsumption or energyConsumption? Document talks about energy and uses units of energy but uses the word "power".

    constructor(IdentityContract _marketAuthority, IdentityContractFactory _identityContractFactory) public {
        claimVerifier = new ClaimVerifier(_marketAuthority);
        identityContractFactory = _identityContractFactory;
    }

    function mint(uint256 _id, address[] memory _to, uint256[] memory _quantities) public returns(uint256 __id) {
        // Token needs to be mintable.
        (TokenKind tokenKind, uint64 balancePeriod, address identityContractAddress) = getTokenIdConstituents(_id);
        require(tokenKind == TokenKind.AbsoluteForward);
        
        // msg.sender needs to be allowed to mint.
        require(msg.sender == identityContractAddress);
        require(claimVerifier.verifySecondLevelClaim(msg.sender, ClaimType.ExistenceClaim));
        require(claimVerifier.verifySecondLevelClaim(msg.sender, ClaimType.GenerationTypeClaim));
        require(claimVerifier.verifySecondLevelClaim(msg.sender, ClaimType.LocationClaim));
        
        // balancePeriod must not be in the past.
        require(balancePeriod >= getBalancePeriod());
        
        for (uint256 i = 0; i < _to.length; ++i) {
            address to = _to[i];
            uint256 quantity = _quantities[i];
            
            require(to != address(0x0), "_to must be non-zero.");
            consumeReceptionApproval(_id, to, msg.sender, quantity);

            // Grant the items to the caller
            balances[_id][to] = quantity.add(balances[_id][to]);

            // Emit the Transfer/Mint event.
            // the 0x0 source address implies a mint
            // It will also provide the circulating supply info.
            emit TransferSingle(msg.sender, address(0x0), to, _id, quantity);

            if (to.isContract()) {
                _doSafeTransferAcceptanceCheck(msg.sender, msg.sender, to, _id, quantity, ''); // TOOD: Prüfen
            }
        }
        
        __id = _id;
    }
    
    modifier onlyMeteringAuthorities {
        require(claimVerifier.verifyFirstLevelClaim(msg.sender, ClaimType.IsMeteringAuthority));
        _;
    }
    
    modifier onlyGenerationPlants {
        require(claimVerifier.verifySecondLevelClaim(msg.sender, ClaimType.ExistenceClaim));
        // Todo: Don't only check ExistenceClaim but also whether it's a generation plant (as opposed to being a consumption plant).
        _;
    }
    
    // TODO: Emissions
    function createForwards(uint64 _balancePeriod, address _distributor) public onlyGenerationPlants returns(uint256 __id) {
        // Todo: Wie funktioniert "Der Distributor Contract bestimmt die Gattung der Forwards Art."?
        __id = getTokenId(TokenKind.GenerationBasedForward, _balancePeriod, _distributor);
        balances[__id][_distributor] = 100E18;
    }
    
    function createCertificates(address _generationPlant, uint64 _balancePeriod) public view onlyMeteringAuthorities returns(uint256 __id) {
        __id = getTokenId(TokenKind.Certificate, _balancePeriod, _generationPlant);
        // Nothing to do. All balances of this token remain zero.
    }

    function addMeasuredEnergyConsumption(address _plant, uint256 _value, uint64 _balancePeriod, string memory _signature, bool _corrected) onlyMeteringAuthorities public returns (bool __success) {
        // Don't allow a corrected value to be overwritten with a non-corrected value.
        if(energyDocumentations[_plant][_balancePeriod].corrected && !_corrected) {
            return false;
        }
        
        EnergyDocumentation memory energyDocumentation = EnergyDocumentation(_value, _signature, _corrected, false);
        energyDocumentations[_plant][_balancePeriod] = energyDocumentation;
        
        return true;
    }
    
    function addMeasuredEnergyGeneration(address _plant, uint256 _value, uint64 _balancePeriod, string memory _signature, bool _corrected) onlyMeteringAuthorities public returns (bool __success) {
        // Don't allow a corrected value to be overwritten with a non-corrected value.
        if(energyDocumentations[_plant][_balancePeriod].corrected && !_corrected) {
            return false;
        }
        
        EnergyDocumentation memory energyDocumentation = EnergyDocumentation(_value, _signature, _corrected, true);
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

    function getBalancePeriod() public view returns(uint64) {
        return uint64(now - (now % 900));
    }
}
