// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Pool} from "../../src/core/Pool.sol";
import {Verifier} from "../../src/core/Verifier.sol";
import {Verifier22} from "../../src/verifiers/Verifier22.sol";
import {AssetType, VerifierInfo} from "../../src/libraries/DataTypes.sol";
import {ZTransaction, ZTransactionType} from "../../src/libraries/ZTransaction.sol";

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {TransactionRequest} from "./helpers/TransactionRequest.sol";
import {ZkFi, ZAccount} from "./helpers/ZkFi.sol";
import {PoolFixture} from "./fixtures/PoolFixture.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";

contract PoolAccountTest is PoolFixture {
    EntryPoint public entryPoint2;
    address paymaster;
    address payable beneficiary;

    function setUp() public {
        _initFixture();
        _mockDeposit();
        entryPoint2 = new EntryPoint();
    }

    function test_bundlerTransferTx() public {
        TransactionRequest memory req = _createTransferReq(
            _getAssetId(asset1),
            1 ether
        );
        ZTransaction memory ztx = zkfi.getZTx(req);

        PackedUserOperation memory userOp;
        userOp.sender = address(pool);
        userOp.callData = abi.encodeCall(Pool.transact, (ztx));
        userOp.accountGasLimits = bytes32(
            bytes.concat(bytes16(uint128(500_000)), bytes16(uint128(2_000_000)))
        );
        userOp.preVerificationGas = uint256(10_000);
        userOp.paymasterAndData = bytes.concat(
            bytes20(paymaster),
            bytes32(uint256(50_000))
        );

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        entryPoint2.handleOps(userOps, beneficiary);
    }
}
