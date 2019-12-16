pragma solidity ^0.5.0;

import "./IdentityContract.sol";
import "./ClaimCommons.sol";

contract ClaimVerifier is ClaimCommons {
    IdentityContract marketAuthority; // TODO: Set value.

    function verifyFirstLevelClaim(address payable _subject, ClaimType _firstLevelClaim) internal view returns(bool) {
        // Make sure the given claim actually is a first level claim.
        require(_firstLevelClaim == ClaimType.IsBalanceAuthority || _firstLevelClaim == ClaimType.IsMeteringAuthority || _firstLevelClaim == ClaimType.IsPhysicalAssetAuthority || _firstLevelClaim == ClaimType.IdentityContractFactoryClaim || _firstLevelClaim == ClaimType.EnergyTokenContractClaim || _firstLevelClaim == ClaimType.MarketRulesClaim);
        
        uint256 topic = claimType2Topic(_firstLevelClaim);
        bytes32[] memory claimIds = IdentityContract(_subject).getClaimIdsByType(topic);
        
        for(uint64 i = 0; i < claimIds.length; i++) {
            (uint256 cTopic, uint256 cScheme, address cIssuer, bytes memory cSignature, bytes memory cData,) = IdentityContract(_subject).getClaim(claimIds[i]);
            
            if(cTopic != topic)
                continue;
                
            if(cIssuer != address(marketAuthority))
                continue;
            
            bool correct = marketAuthority.verifySignature(cTopic, cScheme, cIssuer, cSignature, cData);
            if(correct)
                return true;
        }
        
        return false;
    }
    
    function verifySecondLevelClaim(address payable _subject, ClaimType _secondLevelClaim) internal view returns(bool) {
        // Make sure the given claim actually is a second level claim.
        require(_secondLevelClaim == ClaimType.MeteringClaim || _secondLevelClaim == ClaimType.BalanceClaim || _secondLevelClaim == ClaimType.ExistenceClaim || _secondLevelClaim == ClaimType.GenerationTypeClaim || _secondLevelClaim == ClaimType.LocationClaim || _secondLevelClaim == ClaimType.AcceptedDistributorContractsClaim);
        uint256 topic = claimType2Topic(_secondLevelClaim);
        bytes32[] memory claimIds = IdentityContract(_subject).getClaimIdsByType(topic);
        
        for(uint64 i = 0; i < claimIds.length; i++) {
            (uint256 cTopic, uint256 cScheme, address cIssuer, bytes memory cSignature, bytes memory cData,) = IdentityContract(_subject).getClaim(claimIds[i]);
            
            if(cTopic != topic)
                continue;
                
            bool correctAccordingToSecondLevelAuthority = IdentityContract(address(uint160(cIssuer))).verifySignature(cTopic, cScheme, cIssuer, cSignature, cData);
            if(correctAccordingToSecondLevelAuthority && verifyFirstLevelClaim(address(uint160(cIssuer)), getHigherLevelClaim(_secondLevelClaim))) {
                return true;
            }
        }
        
        return false;
    }
}