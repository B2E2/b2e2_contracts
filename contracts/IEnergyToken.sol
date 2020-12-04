pragma solidity ^0.7.0;

import "./Distributor.sol";

interface IEnergyToken {

	enum TokenKind {AbsoluteForward, GenerationBasedForward, ConsumptionBasedForward, Certificate}

    function decimals() external pure returns (uint8);

    function mint(uint256 _id, address[] calldata _to, uint256[] calldata _quantities) external;

    function createForwards(uint64 _balancePeriod, TokenKind _tokenKind, Distributor _distributor) external;

    function addMeasuredEnergyConsumption(address _plant, uint256 _value, uint64 _balancePeriod) external;

    function addMeasuredEnergyGeneration(address _plant, uint256 _value, uint64 _balancePeriod) external;

    // ########################
    // # ERC-1155 functions
    // ########################
    
	function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes calldata _data) external;

    function safeBatchTransferFrom(address _from, address _to, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external;

    // ########################
    // # Public support functions
    // ########################

    function getTokenId(TokenKind _tokenKind, uint64 _balancePeriod, address _identityContractAddress) external pure returns (uint256 __tokenId);

    function getTokenIdConstituents(uint256 _tokenId) external pure returns(TokenKind __tokenKind, uint64 __balancePeriod, address __identityContractAddress);

    function tokenKind2Number(TokenKind _tokenKind) external pure returns (uint8 __number);

    function number2TokenKind(uint8 _number) external pure returns (TokenKind __tokenKind);

}