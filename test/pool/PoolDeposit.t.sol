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
        if (block.chainid != ETH_SEPOLIA && block.chainid != 1) {
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
        pool.transact(stx);
    }

    /////////////////////////////////////////////////////////
    //         NATIVE ETH DEPOSIT (msg.value) TESTS        //
    //                                                     //
    // These tests reuse the `deposit_2_testnet_weth`      //
    // fixture (a 2 WETH deposit on Sepolia/Mainnet fork)  //
    // and exercise `Pool.transact{value: ...}` so the     //
    // Pool wraps native ETH instead of pulling WETH from  //
    // the caller's wallet.                                //
    /////////////////////////////////////////////////////////

    /// @dev Caller funds the entire deposit with native ETH; Pool wraps the
    ///      full msg.value into WETH on the caller's behalf. No prior wrap or
    ///      WETH approval is required.
    function test_nativeEth_fullDeposit() public {
        if (block.chainid != ETH_SEPOLIA && block.chainid != 1) {
            vm.skip(true);
        }
        address testnet_weth = config.wToken();
        uint256 deposit1 = 2 ether;
        uint256 balance1 = IWToken(testnet_weth).balanceOf(address(pool));
        uint256 ethBalanceBefore = address(this).balance;

        vm.deal(address(this), ethBalanceBefore + deposit1);
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_2_testnet_weth"
        );
        pool.transact{value: deposit1}(stx);

        // Pool should hold the wrapped 2 WETH and the caller's ETH balance
        // should have decreased by exactly `deposit1`.
        assertEq(
            IWToken(testnet_weth).balanceOf(address(pool)),
            balance1 + deposit1
        );
        assertEq(address(this).balance, ethBalanceBefore);
    }

    /// @dev Caller splits funding: half native ETH, half pre-wrapped WETH
    ///      approved to the Pool. Pool wraps the ETH portion and pulls the
    ///      remainder via transferFrom so the deposit is fully funded.
    function test_nativeEth_partialDeposit() public {
        if (block.chainid != ETH_SEPOLIA && block.chainid != 1) {
            vm.skip(true);
        }
        address testnet_weth = config.wToken();
        uint256 deposit1 = 2 ether;
        uint256 ethPortion = 1 ether;
        uint256 wethPortion = deposit1 - ethPortion;
        uint256 balance1 = IWToken(testnet_weth).balanceOf(address(pool));

        // Fund the caller with `deposit1` ETH; wrap half of it ahead of time
        // and approve the resulting WETH to the Pool. The remaining ETH is
        // sent as msg.value.
        vm.deal(address(this), deposit1);
        IWToken(testnet_weth).deposit{value: wethPortion}();
        IWToken(testnet_weth).approve(address(pool), wethPortion);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_2_testnet_weth"
        );
        pool.transact{value: ethPortion}(stx);

        // Pool should still end up with the full pubAsset value of WETH and
        // the caller's leftover ETH/WETH balance should be zero.
        assertEq(
            IWToken(testnet_weth).balanceOf(address(pool)),
            balance1 + deposit1
        );
        assertEq(IWToken(testnet_weth).balanceOf(address(this)), 0);
        assertEq(address(this).balance, 0);
    }

    /// @dev msg.value strictly exceeds the wToken pubAsset value: Pool refuses
    ///      to wrap to avoid locking surplus ETH and reverts with
    ///      `NativeEthExceedsDeposit`.
    function test_revertOnNativeEthExceedsDeposit() public {
        if (block.chainid != ETH_SEPOLIA && block.chainid != 1) {
            vm.skip(true);
        }
        uint256 deposit1 = 2 ether;
        uint256 oversend = deposit1 + 1 wei;

        vm.deal(address(this), oversend);
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_2_testnet_weth"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.NativeEthExceedsDeposit.selector,
                oversend,
                deposit1
            )
        );
        pool.transact{value: oversend}(stx);
    }

    /// @dev Sending msg.value before `wToken` has been configured by the
    ///      owner must revert with `WTokenNotConfigured`. ERC20-only deposits
    ///      (msg.value == 0) are unaffected by this.
    function test_revertOnNativeEthWhenWTokenNotConfigured() public {
        if (block.chainid != ETH_SEPOLIA && block.chainid != 1) {
            vm.skip(true);
        }
        uint256 deposit1 = 2 ether;
        vm.deal(address(this), deposit1);

        // Temporarily set wToken to address(0) to simulate unconfigured state. The fixture sets a valid wToken address, so we need to override it here to test this scenario.
        pool.setWToken(IWToken(address(0)));
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_2_testnet_weth"
        );

        vm.expectRevert(IPool.WTokenNotConfigured.selector);
        pool.transact{value: deposit1}(stx);
    }

    /// @dev Allow the test contract to receive ETH (for `vm.deal` accounting
    ///      sanity and in case any path refunds residual ETH).
    receive() external payable {}
}
