pragma solidity ^0.5.0;

/*
* Everything in this contract actually shouldn't be its own contract but static members of IdentityContractFactory. However, Solidity seems to be lacking this feature.
* So all contracts which need to access these enums and methods instead are subcontracts of this contract.
*/
contract ClaimCommons {
    enum ClaimType {IsBalanceAuthority, IsMeteringAuthority, IsPhysicalAssetAuthority, MeteringClaim, BalanceClaim, ExistenceClaim, GenerationTypeClaim, LocationClaim, IdentityContractFactoryClaim, EnergyTokenContractClaim, MarketRulesClaim, AcceptedDistributorContractsClaim }

    function claimType2Topic(ClaimType _claimType) public pure returns (uint256 __topic) {
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
        if(_claimType == ClaimType.AcceptedDistributorContractsClaim) {
            return 10120;
        }

        require(false);
    }
}