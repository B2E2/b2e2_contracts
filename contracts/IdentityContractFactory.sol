pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./IdentityContract.sol";
import "./ClaimCommons.sol";
import "./../dependencies/erc725-735/contracts/Identity.sol";
import "./../dependencies/erc725-735/contracts/ERC735.sol";


// Implements 735
contract IdentityContractFactory is ClaimCommons {
    mapping (address => bool) authorityExistenceLookup;
    mapping (address => bool) plantExistenceLookup;
    mapping (address => AuthorityType) authorityTypeLookup;
    mapping (address => PlantType) plantTypeLookup;
    
    enum AuthorityType { BalanceAuthority, MeteringAuthority, PhysicalAssetAuthority }
    enum PlantType { GenerationPlant, ConsumptionPlant }
    event AuthorityCreation(AuthorityType authorityType, address authorityAddress, address owner);
    event PlantCreation(PlantType plantType, address plantAddress, address owner);

    address owner;
    IdentityContract marketAuthority;
    
    constructor(IdentityContract _marketAuthority) public {
        owner = msg.sender;
        marketAuthority = _marketAuthority;
    }
    
    modifier ownerOwnly {
        require(owner == msg.sender);
        _;
    }
    
    function createAuthority(
        AuthorityType authorityType,
        bytes32[] memory _keys,
        uint256[] memory _purposes,
        uint256 _managementRequired,
        uint256 _executionRequired,
        address[] memory _issuers,
        uint256[] memory _topics,
        bytes[] memory _signatures,
        bytes[] memory _datas,
        string[] memory _uris
        ) public {
        IdentityContract authority = new IdentityContract(
            marketAuthority,
            _keys,
            _purposes,
            _managementRequired,
            _executionRequired,
            _issuers,
            _topics,
            _signatures,
            _datas,
            _uris);

        authorityExistenceLookup[address(authority)] = true;
        authorityTypeLookup[address(authority)] = authorityType;
        emit AuthorityCreation(authorityType, address(authority), msg.sender);
    }
    
    function createPlant(
        PlantType plantType,
        bytes32[] memory _keys,
        uint256[] memory _purposes,
        uint256 _managementRequired,
        uint256 _executionRequired,
        address[] memory _issuers,
        uint256[] memory _topics,
        bytes[] memory _signatures,
        bytes[] memory _datas,
        string[] memory _uris
        ) public {
        IdentityContract plant = new IdentityContract(
            marketAuthority,
            _keys,
            _purposes,
            _managementRequired,
            _executionRequired,
            _issuers,
            _topics,
            _signatures,
            _datas,
            _uris);

        plantExistenceLookup[address(plant)] = true;
        plantTypeLookup[address(plant)] = plantType;
        emit PlantCreation(plantType, address(plant), msg.sender);
    }
    
    function registerAuthority(address payable _authorityAddress, AuthorityType _authorityType, bytes memory _signature, bytes memory _data) public ownerOwnly {
        require(_authorityType == AuthorityType.BalanceAuthority || _authorityType == AuthorityType.MeteringAuthority || _authorityType == AuthorityType.PhysicalAssetAuthority);
        
        ClaimType claimType;
        if(_authorityType == AuthorityType.BalanceAuthority)
            claimType = ClaimType.IsBalanceAuthority;
        else if(_authorityType == AuthorityType.MeteringAuthority)
            claimType = ClaimType.IsMeteringAuthority;
        else if(_authorityType == AuthorityType.PhysicalAssetAuthority)
            claimType = ClaimType.IsPhysicalAssetAuthority;
        else
            require(false);
        
        require(isValidAuthority(_authorityAddress, _authorityType));
        
        IdentityContract(_authorityAddress).addClaim(claimType2Topic(claimType), IdentityContract(_authorityAddress).ECDSA_SCHEME(), msg.sender, _signature, _data, "");
    }

    function registerPlant(address payable _plantAddress, PlantType _plantType, bytes memory _signature, bytes memory _data) public ownerOwnly {
        require(_plantType == PlantType.GenerationPlant || _plantType == PlantType.ConsumptionPlant);
        
        ClaimType claimType = ClaimType.ExistenceClaim;
        
        require(isValidPlant(_plantAddress, _plantType));
        
        IdentityContract(_plantAddress).addClaim(claimType2Topic(claimType), IdentityContract(_plantAddress).ECDSA_SCHEME(), msg.sender, _signature, _data, "");
    }
    
    function isValidAuthority(address _authorityAddress, AuthorityType _authorityType) public view returns (bool) {
        return isValidAuthority(_authorityAddress) && (authorityTypeLookup[_authorityAddress] == _authorityType);
    }
    
    function isValidAuthority(address _authorityAddress) public view returns (bool) {
        // TODO: Check claim.
        return authorityExistenceLookup[_authorityAddress];
    }
    
    function isValidPlant(address _plantAddress, PlantType _plantType) public view returns (bool) {
        return isValidPlant(_plantAddress) && (plantTypeLookup[_plantAddress] == _plantType);
    }
    
    function isValidPlant(address _plantAddress) public view returns (bool) {
        // TODO: Check claim.
        return plantExistenceLookup[_plantAddress];
    }
}
