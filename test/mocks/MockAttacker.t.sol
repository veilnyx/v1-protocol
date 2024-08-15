// SPDX-License-Identifier: MTI
pragma solidity ^0.8.24;

import {ZTransaction} from "../../src/libraries/ZTransaction.sol";
import {Pool} from "../../src/core/Pool.sol";
import {console} from "forge-std/console.sol";
import {MockERC20} from "./MockERC20.sol";
import {Test} from "forge-std/Test.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract MockAttacker is Test {
    Pool pool;
    ZTransaction withdrawZTx;
    MockERC20 token1;

    constructor(
        Pool pool_,
        ZTransaction memory withdrawZTx_,
        MockERC20 token1_
    ) {
        pool = pool_;
        withdrawZTx = withdrawZTx_;
        token1 = token1_;
    }

    function onTokenTransfer() external payable {
        console.logString("Initiating reentrancy attack");
        if (MockERC20(token1).balanceOf(address(pool)) >= 500 ether) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    ReentrancyGuardUpgradeable
                        .ReentrancyGuardReentrantCall
                        .selector
                )
            );
            pool.transact(withdrawZTx);
        }
    }
}
