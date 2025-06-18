// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPool} from "src/interfaces/IPool.sol";
import {Pool} from "src/core/Pool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransaction.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {console2} from "forge-std/console2.sol";

contract PoolWithdrawTest is PoolTest {
    function setUp() public {
        _setUp();
        _makePreDeposit();
    }

    function test_withdrawWithoutFee() public {
        uint256 balance1 = token1.balanceOf(address(pool));
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "withdraw_100_weth_without_fee"
        );

        uint224 withdrawAmt = uint224(stx.pubAssets[0]);
        console2.log("withdrawAmt");
        console2.logUint(withdrawAmt);

        uint256 balanceAfter = balance1 - withdrawAmt;
        _checkEventEmits(stx);

        assertEq(token1.balanceOf(address(pool)), balanceAfter);
        assert(pool.getCollectedWithdrawFee(asset1.id) > 0);
    }

    function test_withdrawWethWithWethFee() public {
        uint256 balance1 = token1.balanceOf(address(pool));
        uint256 balance2 = token2.balanceOf(address(pool));

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "withdraw_10_weth_with_weth_fee"
        );
        uint224 withdrawAmt = uint224(stx.pubAssets[0]);
        uint72 paymasterFeeRetained = uint72(stx.feeData);

        _checkEventEmits(stx);

        // feeValue and protocol withdraw fee amt is left back in the pool
        uint256 expectedBalPostWithdraw = balance1 -
            withdrawAmt +
            paymasterFeeRetained;

        assertEq(token1.balanceOf(address(pool)), expectedBalPostWithdraw);
    }

    function test_withdrawWethWithUsdcFee() public {
        uint256 balance1 = token1.balanceOf(address(pool));
        uint256 balance2 = token2.balanceOf(address(pool));
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "withdraw_10_weth_with_usdc_fee"
        );
        uint224 withdrawAmt = uint224(stx.pubAssets[0]);
        uint256 protocolFeeBps = pool.getProtocolFee(stx.txType);
        uint72 paymasterFeeRetained = uint72(stx.feeData);
        // uint256 protocolFeeRetained = (withdrawAmt * protocolFeeBps) / 10000; // 500e18 - 10e18 + (0.0005 * 10e18) = 490005000000000000000

        address paymaster = address(bytes20(bytes32(stx.feeData)));

        _checkEventEmits(stx);

        // full withdrawAmt should be deducted from the pool, except the withdrawal fee charged by the protocol. `paymasterFeeRetained` amt in form of WETH is no more left back. Instead `paymasterFeeRetained` is left back in form of USDC in the pool.
        uint256 expectedBalPostWithdraw = balance1 - withdrawAmt;
        // + protocolFeeRetained;

        uint256 usdcPaymasterFee = pool.getCollectedPaymasterFee(
            asset2.id,
            paymaster
        );

        assertEq(token1.balanceOf(address(pool)), expectedBalPostWithdraw);
        assertEq(usdcPaymasterFee, paymasterFeeRetained);
        // USDC bal after should remain the same for protocol, but for the user, a smaller refund note (their USDC bal - paymaster fee) will be issued.
        assertEq(token2.balanceOf(address(pool)), balance2);
    }
}
