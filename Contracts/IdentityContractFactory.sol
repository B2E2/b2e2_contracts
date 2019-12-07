pragma solidity ^0.5.0;

import "./IdentityContract.sol";

// Implements 735
contract IdentityContractFactory {
    IdentityContract public physicalAssetAuthority;
    IdentityContract public meteringAuthority;
    IdentityContract public balanceAuthority_P;
    IdentityContract public balanceAuthority_C;
    
    mapping (address => bool) plantExistenceLookup;
    mapping (address => PlantType) plantTypeLookup;
    
    enum PlantType { GenerationPlant, ConsumptionPlant }
    event PlantCreation(PlantType plantType, address plantAddress, address owner);

    constructor() public {
       physicalAssetAuthority = new IdentityContract();
       meteringAuthority = new IdentityContract();
       balanceAuthority_P = new IdentityContract();
       balanceAuthority_C = new IdentityContract();
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
