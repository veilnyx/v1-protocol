// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ShieldedTransaction} from "src/libraries/ShieldedTransaction.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {ZERO_LEAF} from "src/base/Constants.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";

contract PoolDepositTest is PoolTest {
    uint256 public constant ETH_SEPOLIA = 11155111;

    function setUp() public {
        _setUp();
        _mintAsset(asset1, address(this), 10000 ether);
        _mintAsset(asset2, address(this), 10000 ether);
        _approveAsset(asset1, address(pool), 10000 ether);
        _approveAsset(asset2, address(pool), 10000 ether);
    }

    function test_weth_deposit() public {
        uint256 deposit1 = 100 ether;
        uint256 balance1 = token1.balanceOf(address(pool));

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_weth_tx"
        );
        _checkEventEmits(stx);

        assertEq(token1.balanceOf(address(pool)), balance1 + deposit1);
    }

    function test_weth_testnet_deposit() public {
        if (block.chainid != ETH_SEPOLIA) {
            vm.skip(true);
        }
        address testnet_weth = config.wToken();
        uint256 deposit1 = 2 ether;
        uint256 balance1 = IWToken(testnet_weth).balanceOf(address(pool));

        vm.deal(address(this), deposit1);
        IWToken(testnet_weth).deposit{value: deposit1}();
        IWToken(testnet_weth).approve(address(pool), deposit1);
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_2_testnet_weth"
        );
        _checkEventEmits(stx);

        assertEq(
            IWToken(testnet_weth).balanceOf(address(pool)),
            balance1 + deposit1
        );
    }

    function test_deposit() public {
        uint256 deposit1 = 10000 ether;
        uint256 deposit2 = 10000e6;
        uint256 balance1 = token1.balanceOf(address(pool));
        uint256 balance2 = token2.balanceOf(address(pool));
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_pre_tx"
        );
        _checkEventEmits(stx);

        assertEq(token1.balanceOf(address(pool)), balance1 + deposit1);
        assertEq(token2.balanceOf(address(pool)), balance2 + deposit2);
    }

    function test_revertOnDoubleSpendDeposit() external {
        uint256 deposit1 = 1000 ether;
        uint256 deposit2 = 1000e6;

        _makePreDeposit();

        // Re-using the same transaction should revert
        _mintAsset(asset1, address(this), deposit1);
        _mintAsset(asset2, address(this), deposit2);
        _approveAsset(asset1, address(pool), deposit1);
        _approveAsset(asset2, address(pool), deposit2);
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_pre_tx"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.DoubleSpend.selector,
                stx.nullifiers[0]
            )
        );
        pool.transact(stx, false);
    }
}
