// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "./IdentityContract.sol";
import "./ClaimCommons.sol";

contract IdentityContractFactory {
    mapping (address => bool) identityContracts;

    event IdentityContractCreation(address idcAddress, address owner);

    IdentityContract marketAuthority;
    
    constructor(IdentityContract _marketAuthority) {
        marketAuthority = _marketAuthority;
        
        // The market authority needs to be registered too.
        identityContracts[address(marketAuthority)] = true;
    }
    
    function createIdentityContract() external {
        IdentityContract idc = new IdentityContract(marketAuthority, IdentityContract.BalancePeriodConfiguration(0, 0), msg.sender);

        identityContracts[address(idc)] = true;
        emit IdentityContractCreation(address(idc), msg.sender);
    }
    
    function isRegisteredIdentityContract(address _address) external view returns (bool) {
        return identityContracts[_address];
    }
}
