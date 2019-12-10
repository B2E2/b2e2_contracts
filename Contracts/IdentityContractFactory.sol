pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./IdentityContract.sol";
import "./ClaimCommons.sol";
import "./erc725-735/contracts/Identity.sol";
import "./erc725-735/contracts/ERC735.sol";


// Implements 735
contract IdentityContractFactory is ClaimCommons {
    mapping (address => bool) plantExistenceLookup;
    mapping (address => PlantType) plantTypeLookup;
    
    enum PlantType { GenerationPlant, ConsumptionPlant }
    event PlantCreation(PlantType plantType, address plantAddress, address owner);
    
    address owner;
    
    constructor() public {
        owner = msg.sender;
    }
    
    modifier ownerOwnly {
        require(owner == msg.sender);
        _;
    }
    
    function registerAuthority(address payable _authorityAddress, ClaimType _claimType, bytes memory _signature, bytes memory _data) public ownerOwnly {
        require(_claimType == ClaimType.IsBalanceAuthority || _claimType == ClaimType.IsMeteringAuthority || _claimType == ClaimType.IsPhysicalAssetAuthority);
        IdentityContract(_authorityAddress).addClaim(claimType2Topic(_claimType), IdentityContract(_authorityAddress).ECDSA_SCHEME(), msg.sender, _signature, _data, "");
    }
    
    function createPlant(
        PlantType plantType,
        bytes32[] memory _keys,
        uint256[] memory _purposes,
        uint256 _managementRequired,
        uint256 _executionRequired,
        address[] memory _issuers,
        uint256[] memory _topics,
        bytes[] memory _signatures,
        bytes[] memory _datas,
        string[] memory _uris
        ) public {
        IdentityContract plant = new IdentityContract(
            _keys,
            _purposes,
            _managementRequired,
            _executionRequired,
            _issuers,
            _topics,
            _signatures,
            _datas,
            _uris);

        // Register plant.
        plantExistenceLookup[address(plant)] = true;
        plantTypeLookup[address(plant)] = plantType;
        emit PlantCreation(plantType, address(plant), msg.sender);
    }
    
    function isValidPlant(address plantAddress, PlantType plantType) public view returns (bool) {
        return isValidPlant(plantAddress) && (plantTypeLookup[plantAddress] == plantType);
    }
    
    function isValidPlant(address plantAddress) public view returns (bool) {
        return plantExistenceLookup[plantAddress];
    }
}
