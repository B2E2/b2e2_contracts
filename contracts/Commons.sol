// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

/**
 * This library contains functionality that concerns the entire code base.
 */
library Commons {
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