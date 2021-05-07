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
        // TODO
    }
}