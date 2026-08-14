// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Paymaster} from "src/core/Paymaster.sol";
import {Gateway} from "src/core/Gateway.sol";
import {ShieldedTransaction, ShieldedTransactionLogic, ShieldedTransactionType} from "src/libraries/ShieldedTransactionLogic.sol";
import {Pool} from "src/core/Pool.sol";
import {MockPool} from "test/mocks/MockPool.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {MockWToken} from "test/mocks/MockWToken.sol";
import {console2} from "forge-std/console2.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

// import {PoolTransactTest} from "test/helpers/PoolTransact.t.sol";

contract ERC4337 is PoolTest {
    EntryPoint public entryPointContract;
    Paymaster public paymaster;
    Gateway public gateway;
    uint24 feeAssetId;
    uint256 feeValue = 0.002 ether;
    uint256 feeValueForOutsourcedVerification = 0.001 ether;
    address public constant CHAINLINK_ETH_USDC_FEED_SEPOLIA =
        0x694AA1769357215DE4FAC081bf1f309aDC325306;

    function setUp() public {
        _setUp();
        _mintAsset(asset1, address(this), 10000 ether);
        _approveAsset(asset1, address(pool), 10000 ether);
        feeAssetId = asset1.id;

        // Deploying ERC4337 infra
        entryPointContract = new EntryPoint();

        StdCheats.deployCodeTo(
            "Gateway.sol:Gateway",
            abi.encode(
                address(entryPointContract),
                address(new MockWToken()),
                address(pool)
            ),
            fixture.gateway
        );
        gateway = Gateway(fixture.gateway);

        console2.log("Gateway(Sender) address:");
        console2.logAddress(address(gateway));

        StdCheats.deployCodeTo(
            "Paymaster.sol:Paymaster",
            abi.encode(
                entryPointContract,
                fixture.gateway,
                address(pool),
                pool.priceFeedStalenessThreshold()
            ),
            fixture.paymaster
        );
        console2.log("paymaster:", fixture.paymaster);
        paymaster = Paymaster(fixture.paymaster);

        console2.log("Paymaster address:");
        console2.logAddress(address(paymaster));

        // Deposit to entry point
        vm.deal(address(this), 100 ether);
        paymaster.depositToEntryPoint{value: 100 ether}();

        // Set Chainlink Oracle Price Feed address to fetch prices
        paymaster.setChainlinkFeed(
            asset1.id,
            AggregatorV3Interface(address(0))
        );
        if (block.chainid == 11155111) {
            // Sepolia
            paymaster.setChainlinkFeed(
                asset2.id,
                AggregatorV3Interface(CHAINLINK_ETH_USDC_FEED_SEPOLIA)
            );
        } else {
            paymaster.setChainlinkFeed(
                asset2.id,
                AggregatorV3Interface(address(0))
            );
        }

        // Deposit funds to test transfer/withdraw tx supported by ERC4337
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_weth_tx"
        );

        pool.transact(stx);
        _processCommitmentTreeQueue();
    }

    // Since this tx is not preVerfied, it will go to the pool
    function testHandleOpsForBundlerInstanTx() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        PackedUserOperation memory packedUserOp = _loadPackedUserOp(
            "transfer_20_weth_with_weth_fee_packed_userop"
        );

        ops[0] = packedUserOp;
        entryPointContract.handleOps(ops, payable(address(this)));

        // assertion
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "transfer_20_weth_with_weth_fee"
        );
        (, uint24 parsedFeeAssetId, uint256 parsedFeeValue) = _parseFeeParams(
            stx
        );
        uint256 paymasterFeeCollected = pool.getCollectedPaymasterFee(
            parsedFeeAssetId,
            address(paymaster)
        );
        assert(paymasterFeeCollected == parsedFeeValue);
    }

    function testHandleOpsAcceptsEffectiveGasPriceFee() public {
        uint256 verificationGasLimit = 75_000;
        uint256 callGasLimit = 900_000;
        uint256 preVerificationGas = 75_000;
        uint256 paymasterVerificationGasLimit = 50_000;
        uint256 paymasterPostOpGasLimit = 5;
        uint256 maxFeePerGas = 100 gwei;
        uint256 maxPriorityFeePerGas = 2 gwei;
        uint256 baseFeePerGas = 20 gwei;

        uint256 requiredGas = verificationGasLimit +
            callGasLimit +
            preVerificationGas +
            paymasterVerificationGasLimit +
            paymasterPostOpGasLimit;
        uint256 effectiveFee = requiredGas *
            (baseFeePerGas + maxPriorityFeePerGas);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "transfer_20_weth_with_weth_fee_effective_gas_price"
        );
        PackedUserOperation memory packedUserOp = _loadPackedUserOp(
            "transfer_20_weth_with_weth_fee_effective_gas_price_packed_userop"
        );

        (, uint24 parsedFeeAssetId, uint256 parsedFeeValue) = _parseFeeParams(
            stx
        );
        assertEq(parsedFeeAssetId, feeAssetId);
        assertEq(parsedFeeValue, effectiveFee);
        assertEq(
            uint256(packedUserOp.accountGasLimits >> 128),
            verificationGasLimit
        );
        assertEq(
            uint256(uint128(uint256(packedUserOp.accountGasLimits))),
            callGasLimit
        );
        assertEq(packedUserOp.preVerificationGas, preVerificationGas);
        assertEq(uint256(packedUserOp.gasFees >> 128), maxPriorityFeePerGas);
        assertEq(uint256(uint128(uint256(packedUserOp.gasFees))), maxFeePerGas);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;
        vm.fee(baseFeePerGas);

        uint256 depositBefore = paymaster.getEntryPointDeposit();
        entryPointContract.handleOps(ops, payable(address(this)));

        assertLt(effectiveFee, requiredGas * maxFeePerGas);
        assertLt(paymaster.getEntryPointDeposit(), depositBefore);
        assertEq(
            pool.getCollectedPaymasterFee(feeAssetId, address(paymaster)),
            effectiveFee
        );
    }

    /**
    // Since this tx will be preVerified, it will go to the mempool
    function testHandleOpsForBundlerPreVerifiedTx() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1); // Entrypoint contract requires an array of ops
        PackedUserOperation memory packedUserOp = _loadPackedUserOp(
            "transfer_20_weth_with_weth_fee_packed_userop_preVerified"
        );

        ops[0] = packedUserOp;
        entryPointContract.handleOps(ops, payable(address(this))); // add STX to Mempool

        // exiting mempool for being processed by the Pool
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "transfer_20_weth_with_weth_fee"
        );
        PreVerificationDetails
            memory preVerificationDetails = _loadPreVerificationDetails(
                "transfer_20_weth_with_weth_fee_preVerificationEncodedStruct"
            );
        bytes32 proofId = keccak256(
            abi.encodePacked(
                preVerificationDetails.circuitId,
                preVerificationDetails.publicInputs
            )
        );
        console2.log("Transfer tx proofId");
        console2.logBytes32(proofId);

        mempool.exitSTXFromMempool(
            ShieldedTransactionLogic.hash(stx),
            stx,
            proofId
        );
    }
     */

    receive() external payable {
        // Handle received Ether
    }

    function _parseFeeParams(
        ShieldedTransaction memory stx
    ) internal pure returns (address, uint24, uint256) {
        // FeeData is packed as follows (in order):
        // 20 bytes - paymaster address
        // 3 bytes - feeAssetId (24 bits)
        // 9 bytes - feeValue (72 bits)
        address paymasterAddr = address(uint160(stx.feeData >> (24 + 72)));

        // Extract the feeAssetId (3 bytes)
        uint24 parsedFeeAssetId = uint24(stx.feeData >> 72);

        // Extract the feeValue (9 bytes)
        uint256 parsedFeeValue = uint256(uint72(stx.feeData));

        return (paymasterAddr, parsedFeeAssetId, parsedFeeValue);
    }
}
