pragma solidity ^0.5.0;

library Commons {

    function getBalancePeriod() public view returns(uint64) {
        return getBalancePeriod(now);
    }
    
    /*
    * Balance period does not start at 00:00:00 + i*15:00 but at 00:00:01 + i*15:00.
    */
    function getBalancePeriod(uint256 _timestamp) public pure returns(uint64) {
        _timestamp--;
        return uint64(_timestamp - (_timestamp % 900) + 1);
    }
}