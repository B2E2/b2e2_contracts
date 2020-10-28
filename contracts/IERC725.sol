// https://github.com/ERC725Alliance/erc725/blob/master/docs/ERC-725.md
// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.7.0;

interface IERC725 /* is IERC725X, IERC725Y */ {
    event ContractCreated(address indexed contractAddress);
    event Executed(uint256 indexed operation, address indexed to, uint256 indexed  value, bytes data);
    event DataChanged(bytes32 indexed key, bytes value);

    function execute(uint256 operationType, address to, uint256 value, bytes calldata data) external;
    function getData(bytes32 key) external view returns (bytes memory value);
    function setData(bytes32 key, bytes calldata value) external;
}