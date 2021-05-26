pragma solidity ^0.8.1;

import "./IdentityContract.sol";

abstract contract AbstractDistributor is IdentityContract {
    modifier onlyConsumptionPlants(address _consumptionPlantAddress) {
        { // Block for avoiding stack too deep error.
        string memory realWorldPlantId = ClaimVerifier.getRealWorldPlantId(marketAuthority, _consumptionPlantAddress);
        require(ClaimVerifier.getClaimOfType(marketAuthority, _consumptionPlantAddress, realWorldPlantId, ClaimCommons.ClaimType.BalanceClaim) != 0, "Claim check for BalanceClaim failed.");
        require(ClaimVerifier.getClaimOfType(marketAuthority, _consumptionPlantAddress, realWorldPlantId, ClaimCommons.ClaimType.ExistenceClaim) != 0, "Claim check for ExistenceClaim failed.");
        require(ClaimVerifier.getClaimOfType(marketAuthority, _consumptionPlantAddress, realWorldPlantId, ClaimCommons.ClaimType.MeteringClaim) != 0, "Claim check for MeteringClaim failed.");
        }
        
        _;
    }
    
    modifier onlyStoragePlants(address _plant, uint64 _balancePeriod) {
        f_onlyStoragePlants(_plant, _balancePeriod);
        _;
    }
    function f_onlyStoragePlants(address _plant, uint64 _balancePeriod) internal {
        string memory realWorldPlantId = ClaimVerifier.getRealWorldPlantId(marketAuthority, _plant);
        
        require(ClaimVerifier.getClaimOfType(marketAuthority, _plant, realWorldPlantId, ClaimCommons.ClaimType.BalanceClaim, _balancePeriod) != 0, "Invalid BalanceClaim.");
        require(ClaimVerifier.getClaimOfTypeWithMatchingField(marketAuthority, _plant, realWorldPlantId, ClaimCommons.ClaimType.ExistenceClaim, "type", "storage", _balancePeriod) != 0, "Invalid ExistenceClaim (type storage).");
        require(ClaimVerifier.getClaimOfType(marketAuthority, _plant, realWorldPlantId, ClaimCommons.ClaimType.MaxPowerGenerationClaim, _balancePeriod) != 0, "Invalid MaxPowerGenerationClaim.");
        require(ClaimVerifier.getClaimOfType(marketAuthority, _plant, realWorldPlantId, ClaimCommons.ClaimType.MaxPowerConsumptionClaim, _balancePeriod) != 0, "Invalid MaxPowerConsumptionClaim.");
        require(ClaimVerifier.getClaimOfType(marketAuthority, _plant, realWorldPlantId, ClaimCommons.ClaimType.MeteringClaim, _balancePeriod) != 0, "Invalid MeteringClaim.");
    }
}