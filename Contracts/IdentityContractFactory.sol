pragma solidity ^0.5.0;

import "./PhysicalAssetAuthority.sol";
import "./MeteringAuthority.sol";
import "./BalanceAuthority_P.sol";
import "./BalanceAuthority_C.sol";
import "./Plant.sol";
import "./GenerationPlant.sol";
import "./ConsumptionPlant.sol";

contract IdentityContractFactory {
    PhysicalAssetAuthority public physicalAssetAuthority;
    MeteringAuthority public meteringAuthority;
    BalanceAuthority_P public balanceAuthority_P;
    BalanceAuthority_C public balanceAuthority_C;
    
    enum PlantType { GenerationPlant, ConsumptionPlant }
    event PlantCreation(PlantType plantType, address plantAddress, address owner);

    constructor() public {
       physicalAssetAuthority = new PhysicalAssetAuthority();
       meteringAuthority = new MeteringAuthority();
       balanceAuthority_P = new BalanceAuthority_P();
       balanceAuthority_C = new BalanceAuthority_C();
    }
    
    function createPlant(PlantType plantType) public {
        Plant plant;
        if(plantType == PlantType.GenerationPlant) {
            plant = new GenerationPlant();
        }
        
        if(plantType == PlantType.ConsumptionPlant) {
            plant = new ConsumptionPlant();
        }
        
        // Make sure that this code doesn't break when new types of plants are added.
        // TODO: require(plant != null); // How can this be done in Solidity? Is the line below correct?
        require(plant != Plant(0));
        
        emit PlantCreation(plantType, address(plant), msg.sender);
    }
}
