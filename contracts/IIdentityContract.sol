pragma solidity ^0.7.0;

interface IIdentityContract {

    function selfdestructIdc() external;

    // Functions ERC-725
    function changeOwner(address _owner) external;

    function getData(bytes32 _key) external view returns (bytes memory _value);

    function setData(bytes32 _key, bytes calldata _value) external;

    function execute(uint256 _operationType, address _to, uint256 _value, bytes calldata _data) external;

    // Functions ERC-735
    function getClaim(uint256 _claimId) external view returns(uint256 __topic, uint256 __scheme, address __issuer, bytes memory __signature, bytes memory __data, string memory __uri);

    function getClaimIdsByTopic(uint256 _topic) external view returns(uint256[] memory claimIds);

    function addClaim(uint256 _topic, uint256 _scheme, address _issuer, bytes memory _signature, bytes memory _data, string memory _uri) external returns (uint256 claimRequestId);

    function removeClaim(uint256 _claimId) external returns (bool success);

    function burnClaimId(uint256 _topic) external;

    function reinstateClaimId(uint256 _topic) external;

    // Funtions ERC-1155 and related
    function onERC1155Received(address /*_operator*/, address _from, uint256 _id, uint256 _value, bytes calldata /*_data*/) external returns(bytes4);

    function onERC1155BatchReceived(address /*_operator*/, address _from, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata /*_data*/) external returns(bytes4);

    function approveSender(address _energyToken, address _sender, uint64 _expiryDate, uint256 _value, uint256 _id) external;

    function approveBatchSender(address _energyToken, address _sender, uint64 _expiryDate, uint256[] calldata _values, uint256[] calldata _ids) external;

}