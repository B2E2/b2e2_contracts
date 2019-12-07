pragma solidity ^0.5.0;

import "./erc-1155/contracts/ERC1155.sol";
import "./IdentityContractFactory.sol";

contract EnergyToken is ERC1155 {
    using SafeMath for uint256;
    using Address for address;
    
    enum TokenKind {AbsoluteForward, GenerationBasedForward, ConsumptionBasedForward, Certificate}
    
    IdentityContractFactory identityContractFactory;
    mapping(address => bool) meteringAuthorityExistenceLookup;
    mapping(address => mapping(uint256 => uint256)) energyConsumption; // TODO: powerConsumption or energyConsumption? Document talks about energy and uses units of energy but uses the word "power".
    
    function mint(uint256 _id, address[] memory _to, uint256[] memory _quantities) onlyCreators public returns(uint256 __id) {
        for(uint32 i=0; i < _to.length; i++) {
            require(identityContractFactory.isValidPlant(_to[i]));
            balances[_id][_to[i]]   = _quantities[i].add(balances[_id][_to[i]]);
        }
        
        __id = _id;
    }
    
    modifier onlyCreators {
        // TODO: Implement
        _;
    }
    
    modifier onlyMeteringAuthorities {
        // TODO: Design decision: Implement verification of metering authorities via claims or simply via entries in this contract?
        require(meteringAuthorityExistenceLookup[msg.sender]);
        _;
    }
    
    function addMeasuredPowerConsumption(address _plant, uint256 _value, uint256 _balancePeriod, string memory _signature, bool _corrected) onlyMeteringAuthorities public returns (bool success) {
        
    }
    
    /**
     * tokenId: zeros (24 bit) || tokenKind number (8 bit) || balancePeriod (64 bit) || address of IdentityContract (160 bit)
     */
    function getTokenId(TokenKind tokenKind, uint64 balancePeriod, address identityContractAddress) public pure returns (uint256 tokenId) {
        tokenId = 0;
        
        tokenId += tokenKind2Number(tokenKind);
        tokenId = tokenId << 64;
        tokenId += balancePeriod;
        tokenId = tokenId << 160;
        tokenId += uint256(identityContractAddress);
    }
    
    /**
     * | Bit (rtl) | Meaning                                         |
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
    function tokenKind2Number(TokenKind tokenKind) public pure returns (uint8) {
        if(tokenKind == TokenKind.AbsoluteForward) {
            return 0;
        }
        if(tokenKind == TokenKind.GenerationBasedForward) {
            return 2;
        }
        if(tokenKind == TokenKind.AbsoluteForward) {
            return 3;
        }
        if(tokenKind == TokenKind.AbsoluteForward) {
            return 4;
        }
        
        // Invalid TokenKind.
        require(false);
    }
}
