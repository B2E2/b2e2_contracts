pragma solidity ^0.5.0;

contract Commons {

    function getBalancePeriod() public view returns(uint64) {
        return getBalancePeriod(now);
    }
    
    function getBalancePeriod(uint256 _timestamp) public pure returns(uint64) {
        return uint64(_timestamp - (_timestamp % 900));
    }
}