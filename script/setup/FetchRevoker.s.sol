// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "../BaseScript.sol";
import {Pool} from "src/core/Pool.sol";
import {RevokerData} from "src/libraries/ShieldedTransaction.sol";
import {console2} from "forge-std/console2.sol";

contract FetchRevoker is BaseScript {
    function run() external broadcast {
        address poolProxy = address(0x0369Cb46F2CBE32C775A2F00177d8dBf84fCB4af);
        Pool pool = Pool(poolProxy);

        uint256 revokerId = uint256(2);
        RevokerData memory revokerData = pool.getRevokerData(revokerId);

        console2.log("Revoker ID:", revokerData.id);
        console2.log("Revoker Active:", revokerData.isActive);
        console2.log("Revoker pub key:", revokerData.revokerPublicKey[0]);
    }
}
