// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {ZTransaction} from "src/libraries/ZTransaction.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {ZERO_LEAF} from "src/base/Constants.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";

contract PoolDepositTest is PoolTest {
    function setUp() public {
        _setUp();
        _mintAsset(asset1, address(this), 10000 ether);
        _mintAsset(asset2, address(this), 10000 ether);
        _approveAsset(asset1, address(pool), 10000 ether);
        _approveAsset(asset2, address(pool), 10000 ether);
    }

    function test_deposit() public {
        console2.log("ZERO_LEAF:", ZERO_LEAF);

        uint256 deposit1 = 1000 ether;
        uint256 deposit2 = 1000e6;
        uint256 balance1 = token1.balanceOf(address(pool));
        uint256 balance2 = token2.balanceOf(address(pool));

        ZTransaction memory ztx = _loadShieldedTransaction(
            "deposit_1000_weth_usdc_without_fee"
        );

        _runExpectedTx(ztx);

        assertEq(token1.balanceOf(address(pool)), balance1 + deposit1);
        assertEq(token2.balanceOf(address(pool)), balance2 + deposit2);
    }

    // function test_revertOnDoubleSpendDeposit() external {
    //     uint256 deposit1 = 1000 ether;
    //     uint256 deposit2 = 1000e6;
    //     _approveAsset(asset1, address(pool), deposit1);
    //     _approveAsset(asset2, address(pool), deposit2);
    //     ZTransaction memory ztx = _loadShieldedTransaction(
    //         "deposit_1000_weth_usdc_without_fee"
    //     );
    //     pool.transact(ztx);

    //     // re-depositing
    //     _mintAsset(asset1, address(this), deposit1);
    //     _mintAsset(asset2, address(this), deposit2);
    //     _approveAsset(asset1, address(pool), deposit1);
    //     _approveAsset(asset2, address(pool), deposit2);
    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             IPool.DoubleSpend.selector,
    //             ztx.nullifiers[0]
    //         )
    //     );
    //     pool.transact(ztx);
    // }
}
