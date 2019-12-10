pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./erc725-735/contracts/Identity.sol";
import "./erc725-735/contracts/SignatureVerifier.sol";

contract IdentityContract is Identity, SignatureVerifier {
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
        public {
            
        }
}
