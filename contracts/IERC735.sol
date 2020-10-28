// https://github.com/ethereum/eips/issues/735
pragma solidity ^0.7.0;

interface IERC735 {

    event ClaimRequested(uint256 indexed claimRequestId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    event ClaimAdded(bytes32 indexed claimId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    event ClaimRemoved(bytes32 indexed claimId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    event ClaimChanged(bytes32 indexed claimId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);

    struct Claim {
        uint256 topic;
        uint256 scheme;
        address issuer; // msg.sender
        bytes signature; // this.address + topic + data
        bytes data;
        string uri;
    }

    function getClaim(uint256 _claimId) external view returns(uint256 topic, uint256 scheme, address issuer, bytes memory signature, bytes memory data, string memory uri); // For some reason, this is bytes32 in the standard. Corrected because that doesn't make any sense.
    function getClaimIdsByTopic(uint256 _topic) external view returns(uint256[] memory claimIds); // For some reason, this is bytes32[] in the standard. Corrected because that doesn't make any sense.
    function addClaim(uint256 _topic, uint256 _scheme, address _issuer, bytes calldata _signature, bytes calldata _data, string calldata _uri) external returns (uint256 claimRequestId);
    // function changeClaim(bytes32 _claimId, uint256 _topic, uint256 _scheme, address _issuer, bytes calldata _signature, bytes calldata _data, string calldata _uri) external returns (bool success);
    function removeClaim(uint256 _claimId) external returns (bool success); // For some reason, this is bytes32 in the standard. Corrected because that doesn't make any sense.
}