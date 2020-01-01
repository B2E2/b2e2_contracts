pragma solidity ^0.5.0;
import "./IdentityContract.sol";

// Abstract contract
contract Distributor {
    IdentityContract public marketAuthority;
    IdentityContract public balanceAuthority_P;
    IdentityContract public balanceAuthority_C;

    enum DistributorType { ProductionBasedDistributor, ConsumptionBasedDistributor, AbsoluteDistributor }
    
    event DistributorCreation(address balanceAuthority_PAddress, address balanceAuthority_CAddress, DistributorType distributorType, address distributorAddress);
    
    // Internal constructor makes this contract abstract.
    constructor(address payable balanceAuthority_CAddress, address payable marketAuthorityAddress, DistributorType distributorType) internal {
        marketAuthority = IdentityContract(marketAuthorityAddress);
        balanceAuthority_P = IdentityContract(msg.sender);
        balanceAuthority_C = IdentityContract(balanceAuthority_CAddress);
        
        // Todo: Check whether msg.sender is affected by the call to super() in this contract's implementing contracts.
        emit DistributorCreation(msg.sender, balanceAuthority_CAddress, distributorType, address(this));
    }
}
