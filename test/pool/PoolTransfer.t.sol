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

contract PoolTransferTest is PoolTest {
    Pool internal _pool;
    ZTransaction transferZTx;
    PoolTransactTest poolTransactTestHelper;
    uint256 defaultFeeValue = 0.001 ether;
    address withdrawerUsedInZTxFixture =
        0x855511cc3694f64379908437D6D64458dC76D024;
    address paymasterUsedInZTxFixture =
        0xFEFcc139ED357999ED60C6a013947328d52e7D97;

    function setUp() public {
        _initFixture();
        _mintAsset(asset1, address(this), INITIAL_DEPOSIT);
        _mintAsset(asset2, address(this), INITIAL_DEPOSIT);

        ZTransaction memory initialDepositZTrxn = _loadZTx(
            "deposit_1000_weth_usdc_without_fee"
        ); // deposit setup

        transferZTx = _loadZTx("transfer_500_weth_without_fee"); // actual ztx to test

        poolTransactTestHelper = new PoolTransactTest(
            transferZTx,
            INITIAL_DEPOSIT,
            token1,
            token2,
            pool
        );

        // deposit setup
        _transferAssetsToPoolTransactHelper();
        poolTransactTestHelper.makeInitialDeposit(initialDepositZTrxn);
    }

    function test_assetBalPostTransfer() external {
        uint256 balance1 = token1.balanceOf(address(pool));
        pool.transact(transferZTx);
        assertEq(token1.balanceOf(address(pool)), balance1);
    }

    function test_assetBalPostTransferWithFee() public {
        // setup
        uint256 balance1 = token1.balanceOf(address(pool));
        ZTransaction memory transferZTxWithFee = _loadZTx(
            "transfer_500_weth_with_weth_fee"
        );
        // transferring fees to pool
        _mintAsset(asset1, address(this), defaultFeeValue);
        token1.transfer(address(pool), defaultFeeValue);

        // action
        pool.transact(transferZTxWithFee);

        vm.prank(paymasterUsedInZTxFixture);
        uint256 paymasterFee = pool.getPaymasterFee(
            asset1.id,
            paymasterUsedInZTxFixture
        );
        assertEq(token1.balanceOf(address(pool)), balance1 + paymasterFee);
        assertEq(paymasterFee, defaultFeeValue);
    }

    function test_revertOnDoubleSpendTransfer() external {
        pool.transact(transferZTx);
        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.DoubleSpend.selector,
                transferZTx.nullifiers[1]
            )
        );
        pool.transact(transferZTx);
    }

    function test_nullifiersMarkedPostTransfer500WethWithoutFee() public {
        poolTransactTestHelper.test_nullifiersMarked();
    }

    function test_nullifiersMarkedPostTransfer500WethWithFee() public {
        ZTransaction memory updatedZTx = _loadZTx(
            "transfer_500_weth_with_weth_fee"
        );
        poolTransactTestHelper.updateZTxToExecute(updatedZTx);

        poolTransactTestHelper.test_nullifiersMarked();
    }

    function test_leafAddedToCommitmentTreePostTransfer500WethWithoutFee()
        public
    {
        poolTransactTestHelper.test_leafAddedToCommitmentTree();
    }

    function test_leafAddedToCommitmentTreePostTransfer500WethWithFee() public {
        ZTransaction memory updateZTx = _loadZTx(
            "transfer_500_weth_with_weth_fee"
        );
        poolTransactTestHelper.updateZTxToExecute(updateZTx);
        poolTransactTestHelper.test_leafAddedToCommitmentTree();
    }

    function test_AnnoucementEventsOnTransfer500WethWithoutFee() external {
        poolTransactTestHelper.test_Annoucements();
    }

    function test_AnnoucementEventsOnTransfer500WethWithFee() external {
        ZTransaction memory updateZTx = _loadZTx(
            "transfer_500_weth_with_weth_fee"
        );
        poolTransactTestHelper.updateZTxToExecute(updateZTx);

        poolTransactTestHelper.test_Annoucements();
    }

    function test_ComplianceMemoEventOnTransfer500WethWithoutFee() external {
        // poolTransactTestHelper.test_ComplianceMemo();
    }

    function test_ComplianceMemoEventOnTransfer500WethWithFee() external {
        ZTransaction memory updateZTx = _loadZTx(
            "transfer_500_weth_with_weth_fee"
        );
        poolTransactTestHelper.updateZTxToExecute(updateZTx);

        // poolTransactTestHelper.test_ComplianceMemo();
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
