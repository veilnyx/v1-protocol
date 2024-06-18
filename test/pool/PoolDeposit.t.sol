// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ZTransaction} from "src/libraries/ZTransaction.sol";
import {PoolTransactTest} from "test/helpers/PoolTransact.t.sol";
import {PoolTest} from "test/fixtures/PoolTest.t.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract PoolDepositTest is PoolTest {
    ZTransaction ztx;
    PoolTransactTest poolTransactTestHelper;

    function setUp() public {
        _initFixture();
        _mintAsset(asset1, address(this), INITIAL_DEPOSIT);
        _mintAsset(asset2, address(this), INITIAL_DEPOSIT);

        ztx = _loadZTx("deposit_1000_weth_usdc_with_fee");
        poolTransactTestHelper = new PoolTransactTest(
            ztx,
            INITIAL_DEPOSIT,
            token1,
            token2,
            pool
        );
    }

    function test_depositAssetBalances() public {
        uint256 balance1 = token1.balanceOf(address(pool));
        uint256 balance2 = token2.balanceOf(address(pool));

        _approveAsset(asset1, address(pool), INITIAL_DEPOSIT);
        _approveAsset(asset2, address(pool), 1000e6);
        pool.transact(ztx);

        assertEq(token1.balanceOf(address(pool)), balance1 + INITIAL_DEPOSIT);
        assertEq(token2.balanceOf(address(pool)), balance2 + 1000e6); // USDC is 6 decimals
    }

    function test_nullifiersMarkedPostDeposit() public {
        _transferAssetsToPoolTransactHelper();
        poolTransactTestHelper.test_nullifiersMarked();
    }

    function test_leafAddedToCommitmentTreePostDeposit() external {
        _transferAssetsToPoolTransactHelper();
        poolTransactTestHelper.test_leafAddedToCommitmentTree();
    }

    function test_AnnoucementEventsOnDeposit() external {
        _transferAssetsToPoolTransactHelper();
        poolTransactTestHelper.test_Annoucements();
    }

    function test_InputNotesMemoEventPostDeposit() external {
        _transferAssetsToPoolTransactHelper();
        poolTransactTestHelper.test_InputNotesMemoEvent();
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
