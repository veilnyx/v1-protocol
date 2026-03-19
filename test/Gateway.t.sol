// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Gateway} from "src/core/Gateway.sol";
import {Paymaster} from "src/core/Paymaster.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {ShieldedTransaction, ShieldedTransactionType} from "src/libraries/ShieldedTransaction.sol";
import {PreVerificationDetails, Mempool} from "src/core/Mempool.sol";
import {MockWToken} from "test/mocks/MockWToken.sol";
import {Fixture, FixtureLib} from "test/fixtures/Fixture.sol";

contract MockPool {
    uint256 constant DEPOSIT_VALUE = 100 ether;
    address mockWTokenAddress;

    function transact(ShieldedTransaction calldata, bool) external {
        // Simulate gas usage
        for (uint256 i = 0; i < 10; i++) {
            new MockWToken();
        }
        IWToken(mockWTokenAddress).transferFrom(
            msg.sender,
            address(this),
            DEPOSIT_VALUE
        );
    }

    function getAsset(uint24 /*assetId*/) external pure returns (Asset memory) {
        Asset memory feeAsset = Asset({
            id: 65537,
            assetType: AssetType.ERC20,
            assetAddress: address(0),
            isActive: true,
            precision: 6
        });

        return feeAsset;
    }

    function setMockWTokenAddress(address wToken) external {
        mockWTokenAddress = wToken;
    }
}

contract MockMempool {
    function addSTXToMempool() external {
        // Simulate gas usage
        for (uint256 i = 0; i < 10; i++) {
            new MockWToken();
        }
    }
}

contract GatewayTest is Test {
    MockPool public pool;
    MockMempool public mempool;
    EntryPoint public entryPoint;
    Paymaster paymaster;

    Gateway gateway;
    address wToken;
    address payable beneficiary = payable(address(0x123));

    uint128 baseFee = 2 gwei;
    uint24 assetId = 65537;
    uint256 paymasterFeeValue = 0.1 ether;
    uint256 constant DEPOSIT_VALUE = 100 ether;

    function setUp() public {
        entryPoint = new EntryPoint();
        pool = new MockPool();
        mempool = new MockMempool();
        wToken = address(new MockWToken());
        pool.setMockWTokenAddress(wToken);
        gateway = new Gateway(
            address(entryPoint),
            address(wToken),
            address(pool),
            address(mempool)
        );
        Fixture memory fixture = FixtureLib.load(vm);

        StdCheats.deployCodeTo(
            "Paymaster.sol:Paymaster",
            abi.encode(entryPoint, address(gateway), address(pool)),
            fixture.paymaster
        );
        console2.log("paymaster:", fixture.paymaster);
        paymaster = Paymaster(fixture.paymaster);

        // Deposit to entry point
        vm.deal(address(this), DEPOSIT_VALUE);
        paymaster.depositToEntryPoint{value: DEPOSIT_VALUE}();
        paymaster.setChainlinkFeed(assetId, address(0));
    }

    function test_handleWrapAndDeposit() public {
        vm.deal(address(this), DEPOSIT_VALUE);
        ShieldedTransaction memory stx;
        stx.txType = ShieldedTransactionType.DEPOSIT;
        gateway.handleWrapAndDeposit{value: DEPOSIT_VALUE}(stx);
    }

    function test_handleUserOp() public {
        ShieldedTransaction memory stx;
        PreVerificationDetails memory preVerificationDetails;
        uint24[] memory pubAssetIds = new uint24[](1);
        uint224[] memory pubAssetValues = new uint224[](1);
        uint248[] memory pubAssets = new uint248[](1);
        pubAssetIds[0] = assetId;
        pubAssetValues[0] = 1 ether;
        pubAssets[0] = uint248(
            bytes31(
                bytes.concat(bytes3(pubAssetIds[0]), bytes28(pubAssetValues[0]))
            )
        );

        uint128 callGasLimit = uint128(2_000_000);
        uint128 verificationGasLimit = uint128(50_000);
        uint256 preVerificationGas = uint256(10_000);
        uint128 maxFeePerGas = baseFee;
        uint128 maxPriorityFeePerGas = baseFee;
        uint128 paymasterVerificationGasLimit = uint128(50_000);
        uint128 paymasterPostOpGasLimit = uint128(10_000);

        uint256 requiredGas = verificationGasLimit +
            callGasLimit +
            paymasterVerificationGasLimit +
            paymasterPostOpGasLimit +
            preVerificationGas;

        uint256 requiredPrefundEth = requiredGas * maxFeePerGas;
        console2.log("required preFundEth uint256:", requiredPrefundEth);
        console2.log("required preFundEth uint96:", uint96(requiredPrefundEth));

        stx.pubAssets = pubAssets;
        stx.feeData = uint256(
            bytes32(
                bytes.concat(
                    bytes20(address(paymaster)),
                    bytes3(assetId),
                    bytes9(uint72(requiredPrefundEth))
                )
            )
        );

        preVerificationDetails.isPreVerified = false;

        PackedUserOperation memory userOp;
        userOp.sender = address(gateway);
        userOp.callData = abi.encodeCall(
            Gateway.handleUserOp,
            (stx, preVerificationDetails)
        );
        userOp.accountGasLimits = bytes32(
            bytes.concat(bytes16(verificationGasLimit), bytes16(callGasLimit))
        );
        userOp.preVerificationGas = preVerificationGas;
        userOp.gasFees = bytes32(
            bytes.concat(bytes16(maxPriorityFeePerGas), bytes16(maxFeePerGas))
        );
        userOp.paymasterAndData = bytes.concat(
            bytes20(address(paymaster)),
            bytes16(paymasterVerificationGasLimit),
            bytes16(paymasterPostOpGasLimit)
        );

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;
        entryPoint.handleOps(userOps, beneficiary);
    }
}
