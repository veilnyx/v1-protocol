// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Pool} from "src/core/Pool.sol";

contract MockPool is Pool {
    function mockVerifier(address verifier_) public {
        verifier = verifier_;
    }
}
