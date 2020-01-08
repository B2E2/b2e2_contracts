pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./IdentityContract.sol";
import "./ClaimCommons.sol";

contract IdentityContractFactory {
    mapping (address => bool) identityContracts;

    enum AuthorityType { BalanceAuthority, MeteringAuthority, PhysicalAssetAuthority }
    enum PlantType { GenerationPlant, ConsumptionPlant }
    event IdentityContractCreation(address idcAddress, address owner);

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
    
    function createIdentityContract(address _ownerAddress) public {
        IdentityContract idc = new IdentityContract(marketAuthority);

        identityContracts[address(idc)] = true;
        emit IdentityContractCreation(address(idc), msg.sender);
    }
    
    function isRegisteredIdentityContract(address _address) public view returns (bool) {
        return identityContracts[_address];
    }
}
