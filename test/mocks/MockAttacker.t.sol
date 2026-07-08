// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ShieldedTransaction} from "../../src/libraries/ShieldedTransactionLogic.sol";
import {Pool} from "../../src/core/Pool.sol";
import {console} from "forge-std/console.sol";
import {MockERC20ForReentrancyTest} from "./MockERC20ForReentrancyTest.sol";
import {Test} from "forge-std/Test.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract MockAttacker is Test {
    Pool pool;
    ShieldedTransaction withdrawStx;
    MockERC20ForReentrancyTest tokenReent;

    constructor(
        Pool pool_,
        ShieldedTransaction memory withdrawStx_,
        MockERC20ForReentrancyTest tokenReent_
    ) {
        pool = pool_;
        withdrawStx = withdrawStx_;
        tokenReent = tokenReent_;
    }

    function onTokenTransfer() external payable {
        console.logString("Initiating reentrancy attack");
        if (tokenReent.balanceOf(address(pool)) >= 500 ether) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    ReentrancyGuardUpgradeable
                        .ReentrancyGuardReentrantCall
                        .selector
                )
            );
            pool.transact(withdrawStx);
        }
    }
}
