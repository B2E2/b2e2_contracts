pragma solidity ^0.5.0;

library Commons {
    
    /*
    * Balance period does not start at 00:00:00 + i*15:00 but at 00:00:01 + i*15:00.
    */
    function getBalancePeriod(uint32 balancePeriodLength, uint256 _timestamp) public pure returns(uint64 __beginningOfBalancePeriod) {
        _timestamp--;
        return uint64(_timestamp - (_timestamp % balancePeriodLength) + 1);
    }
    
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if(a <= b)
            return a;
        else
            return b;
    }
    
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        if(a >= b)
            return a;
        else
            return b;
    }
}