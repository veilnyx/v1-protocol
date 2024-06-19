// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {Pool} from "src/core/Pool.sol";
import {ZTransaction} from "src/libraries/ZTransaction.sol";
import {PoolTest} from "test/fixtures/PoolTest.t.sol";
import {PoolTransactTest} from "test/helpers/PoolTransact.t.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract PoolWithdrawTest is PoolTest {
    Pool internal _pool;
    ZTransaction withdrawZTx;
    PoolTransactTest poolTransactTestHelper;

    function setUp() public {
        _initFixture();
        _mintAsset(asset1, address(this), INITIAL_DEPOSIT);
        _mintAsset(asset2, address(this), INITIAL_DEPOSIT);

        // running the js-ffi `getBalances` script
        /**
        string memory depositFixture = vm.readFile(
            "test/fixtures/ztx/deposit_1000_weth_without_fee"
        );

        string memory withdrawFixture = vm.readFile(
            "test/fixtures/ztx/withdraw_500_weth_without_fee"
        );

        if (
            bytes(depositFixture).length == 0 ||
            bytes(withdrawFixture).length == 0
        ) {
            string[] memory shellScripts = new string[](1);
            shellScripts[0] = "script/shell/genFixtures.sh";
            vm.ffi(shellScripts);
        }
         */

        ZTransaction memory initialDepositZTrxn = _loadZTx(
            "deposit_1000_weth_without_fee"
        ); // deposit setup

        withdrawZTx = _loadZTx("withdraw_500_weth_without_fee"); // actual ztx to test

        poolTransactTestHelper = new PoolTransactTest(
            withdrawZTx,
            INITIAL_DEPOSIT,
            token1,
            token2,
            pool
        );

        // deposit setup
        _transferAssetsToPoolTransactHelper();
        poolTransactTestHelper.makeInitialDeposit(initialDepositZTrxn);
    }

    function test_assetBalPostWithdraw() external {
        uint256 balance1 = token1.balanceOf(address(pool));
        pool.transact(withdrawZTx);
        assertEq(token1.balanceOf(address(pool)), balance1 - 500 ether);
    }

     function test_revertOnDoubleSpend() external {
        pool.transact(withdrawZTx);
        vm.expectRevert(abi.encodeWithSelector(IPool.DoubleSpend.selector, withdrawZTx.nullifiers[0]));
        pool.transact(withdrawZTx);
    }

    function test_nullifiersMarkedPostWithdraw500WethWithoutFee() public {
        poolTransactTestHelper.test_nullifiersMarked();
    }

    function test_nullifiersMarkedPostWithdraw500WethWithFee() public {
        ZTransaction memory updatedZTx = _loadZTx(
            "withdraw_500_weth_with_weth_fee"
        );
        poolTransactTestHelper.updateZTxToExecute(updatedZTx);

        poolTransactTestHelper.test_nullifiersMarked();
    }

    function test_leafAddedToCommitmentTreePostWithdraw500WethWithoutFee()
        public
    {
        poolTransactTestHelper.test_leafAddedToCommitmentTree();
    }

    function test_leafAddedToCommitmentTreePostWithdraw500WethWithFee() public {
        ZTransaction memory updateZTx = _loadZTx(
            "withdraw_500_weth_with_weth_fee"
        );
        poolTransactTestHelper.updateZTxToExecute(updateZTx);
        poolTransactTestHelper.test_leafAddedToCommitmentTree();
    }

    function test_AnnoucementEventsOnWithdraw500WethWithoutFee() external {
        poolTransactTestHelper.test_Annoucements();
    }

    function test_AnnoucementEventsOnWithdraw500WethWithFee() external {
        ZTransaction memory updateZTx = _loadZTx(
            "withdraw_500_weth_with_weth_fee"
        );
        poolTransactTestHelper.updateZTxToExecute(updateZTx);

        poolTransactTestHelper.test_Annoucements();
    }

    function test_ComplianceMemoEventOnWithdraw500WethWithoutFee() external {
        poolTransactTestHelper.test_ComplianceMemo();
    }

    function test_ComplianceMemoEventOnWithdraw500WethWithFee() external {
        ZTransaction memory updateZTx = _loadZTx(
            "withdraw_500_weth_with_weth_fee"
        );
        poolTransactTestHelper.updateZTxToExecute(updateZTx);

        poolTransactTestHelper.test_ComplianceMemo();
    }

    function _transferAssetsToPoolTransactHelper() internal {
        MockERC20(token1).transfer(
            address(poolTransactTestHelper),
            INITIAL_DEPOSIT
        );
        MockERC20(token2).transfer(
            address(poolTransactTestHelper),
            INITIAL_DEPOSIT
        );
    }
}
