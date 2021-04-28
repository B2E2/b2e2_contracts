pragma solidity ^0.8.1;

/*
* Everything in this contract actually shouldn't be its own contract but static members of IdentityContractFactory. However, Solidity seems to be lacking this feature.
* So all contracts which need to access these enums and methods instead are subcontracts of this contract.
*/
library ClaimCommons {
    enum ClaimType {IsBalanceAuthority, IsMeteringAuthority, IsPhysicalAssetAuthority, MeteringClaim, BalanceClaim, ExistenceClaim, MaxPowerGenerationClaim, GenerationTypeClaim, LocationClaim, IdentityContractFactoryClaim, EnergyTokenContractClaim, MarketRulesClaim, AcceptedDistributorClaim, RealWorldPlantIdClaim, MaxPowerConsumptionClaim }

    function claimType2Topic(ClaimType _claimType) external pure returns (uint256 __topic) {
        if(_claimType == ClaimType.IsBalanceAuthority) {
            return 10010;
        }
        if(_claimType == ClaimType.IsMeteringAuthority) {
            return 10020;
        }
        if(_claimType == ClaimType.IsPhysicalAssetAuthority) {
            return 10030;
        }
        if(_claimType == ClaimType.MeteringClaim) {
            return 10040;
        }
        if(_claimType == ClaimType.BalanceClaim) {
            return 10050;
        }
        if(_claimType == ClaimType.ExistenceClaim) {
            return 10060;
        }
        if(_claimType == ClaimType.MaxPowerGenerationClaim) {
            return 10065;
        }
        if(_claimType == ClaimType.GenerationTypeClaim) {
            return 10070;
        }
        if(_claimType == ClaimType.LocationClaim) {
            return 10080;
        }
        if(_claimType == ClaimType.IdentityContractFactoryClaim) {
            return 10090;
        }
        if(_claimType == ClaimType.EnergyTokenContractClaim) {
            return 10100;
        }
        if(_claimType == ClaimType.MarketRulesClaim) {
            return 10110;
        }
        if(_claimType == ClaimType.AcceptedDistributorClaim) {
            return 10120;
        }
        if(_claimType == ClaimType.RealWorldPlantIdClaim) {
            return 10130;
        }
        if(_claimType == ClaimType.MaxPowerConsumptionClaim) {
            return 10140;
        }        

        require(false, "_claimType unknown.");
    }
    
    function topic2ClaimType(uint256 _topic) external pure returns (ClaimType __claimType) {
        if(_topic == 10010) {
            return ClaimType.IsBalanceAuthority;
        }
        if(_topic == 10020) {
            return ClaimType.IsMeteringAuthority;
        }
        if(_topic == 10030) {
            return ClaimType.IsPhysicalAssetAuthority;
        }
        if(_topic == 10040) {
            return ClaimType.MeteringClaim;
        }
        if(_topic == 10050) {
            return ClaimType.BalanceClaim;
        }
        if(_topic == 10060) {
            return ClaimType.ExistenceClaim;
        }
        if(_topic == 10065) {
            return ClaimType.MaxPowerGenerationClaim;
        }
        if(_topic == 10070) {
            return ClaimType.GenerationTypeClaim;
        }
        if(_topic == 10080) {
            return ClaimType.LocationClaim;
        }
        if(_topic == 10090) {
            return ClaimType.IdentityContractFactoryClaim;
        }
        if(_topic == 10100) {
            return ClaimType.EnergyTokenContractClaim;
        }
        if(_topic == 10110) {
            return ClaimType.MarketRulesClaim;
        }
        if(_topic == 10120) {
            return ClaimType.AcceptedDistributorClaim;
        }
        if(_topic == 10130) {
            return ClaimType.RealWorldPlantIdClaim;
        }
        if(_topic == 10140) {
            return ClaimType.MaxPowerConsumptionClaim;
        }        

        require(false, "_topic unknown");
    }
    
    function getHigherLevelClaim(ClaimType _claimType) external pure returns (ClaimType __higherLevelClaimType) {
        if(_claimType == ClaimType.MeteringClaim) {
            return ClaimType.IsMeteringAuthority;
        }
        if(_claimType == ClaimType.BalanceClaim) {
            return ClaimType.IsBalanceAuthority;
        }
        if(_claimType == ClaimType.ExistenceClaim) {
            return ClaimType.IsPhysicalAssetAuthority;
        }
        if(_claimType == ClaimType.GenerationTypeClaim) {
            return ClaimType.IsPhysicalAssetAuthority;
        }
        if(_claimType == ClaimType.LocationClaim) {
            return ClaimType.IsPhysicalAssetAuthority;
        }
        if(_claimType == ClaimType.MaxPowerGenerationClaim) {
            return ClaimType.IsPhysicalAssetAuthority;
        }
        if(_claimType == ClaimType.MaxPowerConsumptionClaim) {
            return ClaimType.IsPhysicalAssetAuthority;
        }        
        if(_claimType == ClaimType.AcceptedDistributorClaim) {
            return ClaimType.IsBalanceAuthority;
        }

        require(false, "no __higherLevelClaimType found.");
    }
}
