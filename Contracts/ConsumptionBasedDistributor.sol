pragma solidity ^0.5.0;
import "./Distributor.sol";

contract ConsumptionBasedDistributor is Distributor {
    constructor (address balanceAuthority_CAddress, address marketAuthorityAddress) Distributor(balanceAuthority_CAddress, marketAuthorityAddress, DistributorType.ConsumptionBasedDistributor) public {
        
    }
}
