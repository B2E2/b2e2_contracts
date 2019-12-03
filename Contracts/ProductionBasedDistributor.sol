pragma solidity ^0.5.0;
import "./Distributor.sol";

contract ProductionBasedDistributor is Distributor {
    constructor (address balanceAuthority_CAddress, address marketAuthorityAddress) Distributor(balanceAuthority_CAddress, marketAuthorityAddress, DistributorType.ProductionBasedDistributor) public {
        
    }
}
