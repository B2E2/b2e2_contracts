pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./erc725-735/contracts/Identity.sol";
import "./erc725-735/contracts/SignatureVerifier.sol";
import "./ClaimCommons.sol";

contract IdentityContract is Identity, SignatureVerifier, ClaimCommons {
    IdentityContract marketAuthority;
    
    constructor
    (
        IdentityContract _marketAuthority,
        bytes32[] memory _keys,
        uint256[] memory _purposes,
        uint256 _managementRequired,
        uint256 _executionRequired,
        address[] memory _issuers,
        uint256[] memory _topics,
        bytes[] memory _signatures,
        bytes[] memory _datas,
        string[] memory _uris
    ) Identity(
            _keys,
            _purposes,
            _managementRequired,
            _executionRequired,
            _issuers,
            _topics,
            _signatures,
            _datas,
            _uris)
        public
    {
            marketAuthority = _marketAuthority;
    }
    
    function addClaim(
        uint256 _topic,
        uint256 _scheme,
        address issuer,
        bytes memory _signature,
        bytes memory _data,
        string memory _uri
    )
        public
        returns (uint256 claimRequestId)
    {
        // Make sure that operative authority claims are only added by the market authority.
        ClaimType claimType = topic2ClaimType(_topic);
        if(claimType == ClaimType.IsBalanceAuthority || claimType == ClaimType.IsMeteringAuthority || claimType == ClaimType.IsPhysicalAssetAuthority) {
            require(issuer == address(marketAuthority));
        }
        
        return super.addClaim(_topic, _scheme, issuer, _signature, _data, _uri);
    }
}
