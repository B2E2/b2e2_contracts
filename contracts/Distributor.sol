pragma solidity ^0.5.0;
import "./MarketAuthority.sol";
import "./BalanceAuthority_P.sol";
import "./BalanceAuthority_C.sol";

// Abstract contract
contract Distributor {
    MarketAuthority public marketAuthority;
    BalanceAuthority_P public balanceAuthority_P;
    BalanceAuthority_C public balanceAuthority_C;

    enum DistributorType { ProductionBasedDistributor, ConsumptionBasedDistributor, AbsoluteDistributor }
    
    event DistributorCreation(address balanceAuthority_PAddress, address balanceAuthority_CAddress, DistributorType distributorType, address distributorAddress);
    
    // Internal constructor makes this contract abstract.
    constructor(address balanceAuthority_CAddress, address marketAuthorityAddress, DistributorType distributorType) internal {
        marketAuthority = MarketAuthority(marketAuthorityAddress);
        balanceAuthority_P = BalanceAuthority_P(msg.sender);
        balanceAuthority_C = BalanceAuthority_C(balanceAuthority_CAddress);
        
        // Todo: Check whether msg.sender is affected by the call to super() in this contract's implementing contracts.
        emit DistributorCreation(msg.sender, balanceAuthority_CAddress, distributorType, address(this));
    }
}
