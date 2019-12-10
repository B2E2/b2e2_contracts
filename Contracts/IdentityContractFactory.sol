pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./IdentityContract.sol";
import "./erc725-735/contracts/Identity.sol";
import "./erc725-735/contracts/ERC735.sol";


// Implements 735
contract IdentityContractFactory {
    mapping (address => bool) plantExistenceLookup;
    mapping (address => PlantType) plantTypeLookup;
    
    enum PlantType { GenerationPlant, ConsumptionPlant }
    event PlantCreation(PlantType plantType, address plantAddress, address owner);
    
    address owner;
    
    enum ClaimType {IsBalanceAuthority, IsMeteringAuthority, IsPhysicalAssetAuthority, MeteringClaim, BalanceClaim, ExistenceClaim, GenerationTypeClaim, LocationClaim, IdentityContractFactoryClaim, EnergyTokenContractClaim, MarketRulesClaim, AcceptedDistributorContractsClaim }
    

    constructor() public {
        owner = msg.sender;
    }
    
    modifier ownerOwnly {
        require(owner == msg.sender);
        _;
    }
    
    function registerAuthority(address payable _authorityAddress, ClaimType _claimType, bytes memory _signature, bytes memory _data) public ownerOwnly {
        require(_claimType == ClaimType.IsBalanceAuthority || _claimType == ClaimType.IsMeteringAuthority || _claimType == ClaimType.IsPhysicalAssetAuthority);
        IdentityContract(_authorityAddress).addClaim(claimType2Topic(_claimType), IdentityContract(_authorityAddress).ECDSA_SCHEME(), msg.sender, _signature, _data, "");
    }

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
            _keys,
            _purposes,
            _managementRequired,
            _executionRequired,
            _issuers,
            _topics,
            _signatures,
            _datas,
            _uris);

        // Register plant.
        plantExistenceLookup[address(plant)] = true;
        plantTypeLookup[address(plant)] = plantType;
        emit PlantCreation(plantType, address(plant), msg.sender);
    }
    
    function isValidPlant(address plantAddress, PlantType plantType) public view returns (bool) {
        return isValidPlant(plantAddress) && (plantTypeLookup[plantAddress] == plantType);
    }
    
    function isValidPlant(address plantAddress) public view returns (bool) {
        return plantExistenceLookup[plantAddress];
    }
}
