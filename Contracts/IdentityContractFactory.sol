pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;


import "./IdentityContract.sol";
import "./erc725-735/contracts/Identity.sol";


// Implements 735
contract IdentityContractFactory {
    Identity public identity;
    
    mapping (address => bool) plantExistenceLookup;
    mapping (address => PlantType) plantTypeLookup;
    
    enum PlantType { GenerationPlant, ConsumptionPlant }
    event PlantCreation(PlantType plantType, address plantAddress, address owner);

    constructor
    (
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
       identity = new Identity(
        _keys,
        _purposes,
        _managementRequired,
        _executionRequired,
        _issuers,
        _topics,
        _signatures,
        _datas,
        _uris);
    }
    
    function createPlant(PlantType plantType) public {
        IdentityContract plant = new IdentityContract();

        // Register plant.
        plantExistenceLookup[address(plant)] = true;
        plantTypeLookup[address(plant)] = plantType;
        emit PlantCreation(plantType, address(plant), msg.sender);
    }
    
    function isValidPlant(address plantAddress, PlantType plantType) public returns (bool) {
        return isValidPlant(plantAddress) && (plantTypeLookup[plantAddress] == plantType);
    }
    
    function isValidPlant(address plantAddress) public returns (bool) {
        return plantExistenceLookup[plantAddress];
    }
}
