pragma solidity ^0.5.0;

import "./IdentityContractFactory.sol";
import "./EnergyToken.sol";

contract MarketAuthority {
    IdentityContractFactory public identityContractFactory;
    EnergyToken public energyToken;
    
    constructor() public {
        identityContractFactory = new IdentityContractFactory();
        energyToken = new EnergyToken();
        
        // Todo: Add claims and publish address of MarketAuthority.
    }
}
