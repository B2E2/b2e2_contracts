pragma solidity ^0.8.1;

import "./SimpleDistributor.sol";
import "./ComplexDistributor.sol";

interface IEnergyToken {

	enum TokenKind {AbsoluteForward, GenerationBasedForward, ConsumptionBasedForward, Certificate, PropertyForward}

    function decimals() external pure returns (uint8);

    function mint(uint256 _id, address[] calldata _to, uint256[] calldata _quantities) external;

    function createForwards(uint64 _balancePeriod, TokenKind _tokenKind, SimpleDistributor _distributor) external;
    
    function createPropertyForwards(uint64 _balancePeriod, ComplexDistributor _distributor, EnergyTokenLib.Criterion[] calldata _criteria) external;

    function addMeasuredEnergyConsumption(address _plant, uint256 _value, uint64 _balancePeriod) external;

    function addMeasuredEnergyGeneration(address _plant, uint256 _value, uint64 _balancePeriod) external;
    
    function createTokenFamily(uint64 _balancePeriod, address _generationPlant, uint248 _previousTokenFamilyBase) external;
    
    function createPropertyTokenFamily(uint64 _balancePeriod, address _generationPlant, uint248 _previousTokenFamilyBase, bytes32 _criteriaHash) external;
    
    function temporallyTransportCertificates(uint256 _originalCertificateId, uint256 _targetForwardId, uint256 _value) external returns(uint256 __targetCertificateId);

    // ########################
    // # ERC-1155 functions
    // ########################
    
	function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes calldata _data) external;

    function safeBatchTransferFrom(address _from, address _to, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external;

    // ########################
    // # Public support functions
    // ########################

    function getTokenId(TokenKind _tokenKind, uint64 _balancePeriod, address _identityContractAddress, uint248 _previousTokenFamilyBase) external pure returns (uint256 __tokenId);
    
    function getPropertyTokenId(uint64 _balancePeriod, address _generationPlant, uint248 _previousTokenFamilyBase, bytes32 _criteriaHash) external pure returns (uint256 __tokenId);
    
    function getCriteriaHash(EnergyTokenLib.Criterion[] calldata _criteria) external pure returns(bytes32);

    function getTokenIdConstituents(uint256 _tokenId) external view returns(TokenKind __tokenKind, uint64 __balancePeriod, address __identityContractAddress);

    function tokenKind2Number(TokenKind _tokenKind) external pure returns (uint8 __number);

    function number2TokenKind(uint8 _number) external pure returns (TokenKind __tokenKind);

    function getInitialGenerationPlant(uint256 _tokenId) external view returns(address __initialGenerationPlant);
}