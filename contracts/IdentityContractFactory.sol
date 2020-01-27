pragma solidity ^0.5.0;

import "./IdentityContract.sol";
import "./ClaimCommons.sol";

contract IdentityContractFactory {
    mapping (address => bool) identityContracts;

    event IdentityContractCreation(address idcAddress, address owner);

    IdentityContract marketAuthority;
    
    constructor(IdentityContract _marketAuthority) public {
        marketAuthority = _marketAuthority;
        
        // The market authority needs to be registered too.
        identityContracts[address(marketAuthority)] = true;
    }
    
    function createIdentityContract() public {
        IdentityContract idc = new IdentityContract(marketAuthority);
        idc.changeOwner(msg.sender);

        identityContracts[address(idc)] = true;
        emit IdentityContractCreation(address(idc), msg.sender);
    }
    
    function isRegisteredIdentityContract(address _address) public view returns (bool) {
        return identityContracts[_address];
    }
}
