// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

/**
 * This library contains functionality that concerns the entire code base.
 */
library Commons {
    /**
    * Balance period does not start at 00:00:00 + i*15:00 but at 00:00:01 + i*15:00.
    * 
    * Timestamps are uint64 across this contract stack because they are included in identifiers
    * where space is scarce. 64 bits suffice.
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