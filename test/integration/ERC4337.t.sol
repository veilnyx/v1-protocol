// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Paymaster} from "src/core/Paymaster.sol";
import {Gateway} from "src/core/Gateway.sol";
import {ShieldedTransaction, ShieldedTransactionType} from "src/libraries/ShieldedTransaction.sol";
import {Mempool, PreVerificationDetails} from "src/core/Mempool.sol";
import {Pool} from "src/core/Pool.sol";
import {MockPool} from "test/mocks/MockPool.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {MockWToken} from "test/mocks/MockWToken.sol";
import {console2} from "forge-std/console2.sol";

// import {PoolTransactTest} from "test/helpers/PoolTransact.t.sol";

contract ERC4337 is PoolTest {
    EntryPoint public entryPointContract;
    Paymaster public paymaster;
    Gateway public gateway;
    uint24 feeAssetId;
    uint256 feeValue = 0.002 ether;
    uint256 feeValueForOutsourcedVerification = 0.001 ether;

    function setUp() public {
        _setUp();
        _mintAsset(asset1, address(this), 10000 ether);
        _approveAsset(asset1, address(pool), 10000 ether);
        feeAssetId = asset1.id;

        // Deploying ERC4337 infra
        entryPointContract = new EntryPoint();

        gateway = new Gateway(
            address(entryPointContract),
            address(new MockWToken()),
            address(pool),
            address(mempool)
        );
        console2.log("Gateway(Sender) address:");
        console2.logAddress(address(gateway));

        paymaster = new Paymaster(
            address(entryPointContract),
            address(gateway)
        );
        console2.log("Paymaster address:");
        console2.logAddress(address(paymaster));

        // Deposit to entry point
        vm.deal(address(this), 100 ether);
        paymaster.depositToEntryPoint{value: 100 ether}();
        paymaster.setAssetFee(feeAssetId, feeValue);
        paymaster.setAssetFeeForOutsourcedVerificationTx(
            feeAssetId,
            feeValueForOutsourcedVerification
        );

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_weth_tx"
        );

        pool.transact(stx, false);
        _processCommitmentTreeQueue();
    }

    function testHandleOps() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        PackedUserOperation memory packedUserOp = _loadPackedUserOp(
            "transfer_100_weth_with_weth_fee_packed_userop"
        );

        ops[0] = packedUserOp;
        entryPointContract.handleOps(ops, payable(address(this)));
    }

    receive() external payable {
        // Handle received Ether
    }
}
