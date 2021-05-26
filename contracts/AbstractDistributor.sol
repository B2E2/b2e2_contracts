pragma solidity ^0.8.1;

import "./IdentityContract.sol";

abstract contract AbstractDistributor is IdentityContract {
    // Moving this modifier to the ClaimVerifier library does not affect the size of the
    // complex distributor at all. But it does affect the size of the ClaimVerifier library.
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
        ClaimVerifier.f_onlyStoragePlants(marketAuthority, _plant, _balancePeriod);
        _;
    }
}