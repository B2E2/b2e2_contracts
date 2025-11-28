// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./IdentityContract.sol";

/**
 * This contract may in the future contain shared functionality between the
 * simple and complex distributor that is not contained in IdentityContract.
 */
abstract contract AbstractDistributor is IdentityContract {
}
