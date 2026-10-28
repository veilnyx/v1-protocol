// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransactionLogic.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {VerifierTransact44} from "src/verifiers/VerifierTransact44.sol";
import {Verifier, TransactionVerifierInfo} from "src/core/Verifier.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

/// @dev Tests the transact44 circuit (4 inputs, 4 outputs).
/// Two sequential deposits of 1000 WETH + 1000 USDC each produce 4 input notes;
/// the transfer consumes all 4 and emits 4 output notes (2 receiver + 2 change).
contract PoolTransfer44Test is PoolTest {
    function setUp() public {
        _setUp();
        _registerVerifierTransact44();
        _makePreDeposit4x2A();
        _makePreDeposit4x2B();
    }

    function _registerVerifierTransact44() internal {
        VerifierTransact44 vt44 = new VerifierTransact44();
        TransactionVerifierInfo memory info = TransactionVerifierInfo({
            id: 44,
            addr: address(vt44),
            selector: vt44.verifyProof.selector
        });
        verifier.addTransactionVerifier(info);
    }

    function _makePreDeposit4x2A() internal {
        uint256 deposit1 = 1000 ether;
        uint256 deposit2 = 1000e6;
        _mintAsset(asset1, address(this), deposit1);
        _mintAsset(asset2, address(this), deposit2);
        _approveAsset(asset1, address(pool), deposit1);
        _approveAsset(asset2, address(pool), deposit2);
        ShieldedTransaction memory stx = _loadShieldedTransaction("deposit_pre_tx_4x2_a");
        pool.transact(stx);
        _processCommitmentTreeQueue();
    }

    function _makePreDeposit4x2B() internal {
        uint256 deposit1 = 1000 ether;
        uint256 deposit2 = 1000e6;
        _mintAsset(asset1, address(this), deposit1);
        _mintAsset(asset2, address(this), deposit2);
        _approveAsset(asset1, address(pool), deposit1);
        _approveAsset(asset2, address(pool), deposit2);
        ShieldedTransaction memory stx = _loadShieldedTransaction("deposit_pre_tx_4x2_b");
        pool.transact(stx);
        _processCommitmentTreeQueue();
    }

    function test_transfer4x4WethUsdcWithoutFee() external {
        uint256 balance1 = token1.balanceOf(address(pool));
        uint256 balance2 = token2.balanceOf(address(pool));

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "transfer_4x4_weth_usdc_without_fee"
        );
        console2.log(
            "Fixture::transfer_4x4_weth_usdc_without_fee::MerkleRoot:",
            stx.commitmentTreeRoot
        );

        _checkEventEmits(stx);

        // Private transfer — pool token balances must not change
        assertEq(token1.balanceOf(address(pool)), balance1);
        assertEq(token2.balanceOf(address(pool)), balance2);
    }

    function test_revertOnDoubleSpend4x4Transfer() external {
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "transfer_4x4_weth_usdc_without_fee"
        );
        pool.transact(stx);
        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.DoubleSpend.selector,
                stx.nullifiers[0]
            )
        );
        pool.transact(stx);
    }
}
