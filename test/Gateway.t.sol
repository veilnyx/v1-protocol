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
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Asset, AssetType} from "src/libraries/AssetLogic.sol";
import {ShieldedTransaction, ShieldedTransactionType} from "src/libraries/ShieldedTransactionLogic.sol";
import {MockWToken} from "test/mocks/MockWToken.sol";
import {Fixture, FixtureLib} from "test/fixtures/Fixture.sol";

contract MockPool {
    uint256 constant DEPOSIT_VALUE = 100 ether;
    address mockWTokenAddress;

    function transact(ShieldedTransaction calldata) external {
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
            precision: 6,
            usdPriceFeed: AggregatorV3Interface(address(0)),
            feedDecimals: 0
        });

        return feeAsset;
    }

    /// nativeWToken's asset id, as the Gateway resolves it
    function getAsset(address /*assetAddress*/) external pure returns (Asset memory a) {
        a.id = 65537;
    }

    function setMockWTokenAddress(address nativeWToken) external {
        mockWTokenAddress = nativeWToken;
    }
}

contract GatewayTest is Test {
    MockPool public pool;
    EntryPoint public entryPoint;
    Paymaster paymaster;

    Gateway gateway;
    address nativeWToken;
    address payable beneficiary = payable(address(0x123));

    uint128 baseFee = 2 gwei;
    uint24 assetId = 65537;
    uint256 paymasterFeeValue = 0.1 ether;
    uint256 constant DEPOSIT_VALUE = 100 ether;

    function setUp() public {
        entryPoint = new EntryPoint();
        pool = new MockPool();
        nativeWToken = address(new MockWToken());
        pool.setMockWTokenAddress(nativeWToken);
        gateway = new Gateway(
            IEntryPoint(address(entryPoint)),
            IWToken(address(nativeWToken)),
            IPool(address(pool))
        );
        Fixture memory fixture = FixtureLib.load(vm);

        StdCheats.deployCodeTo(
            "Paymaster.sol:Paymaster",
            abi.encode(
                entryPoint,
                address(gateway),
                address(pool),
                uint256(1 days)
            ),
            fixture.paymaster
        );
        console2.log("paymaster:", fixture.paymaster);
        paymaster = Paymaster(fixture.paymaster);

        // Deposit to entry point
        vm.deal(address(this), DEPOSIT_VALUE);
        paymaster.depositToEntryPoint{value: DEPOSIT_VALUE}();
        paymaster.setChainlinkFeed(assetId, AggregatorV3Interface(address(0)));
    }

    function _wrapDeposit(
        ShieldedTransactionType txType,
        uint24 id,
        uint224 value
    ) internal pure returns (ShieldedTransaction memory stx) {
        stx.txType = txType;
        stx.pubAssets = new uint248[](1);
        stx.pubAssets[0] = uint248(bytes31(bytes.concat(bytes3(id), bytes28(value))));
    }

    function test_handleWrapAndDeposit() public {
        vm.deal(address(this), DEPOSIT_VALUE);
        ShieldedTransaction memory stx = _wrapDeposit(
            ShieldedTransactionType.DEPOSIT,
            assetId,
            uint224(DEPOSIT_VALUE)
        );
        gateway.handleWrapAndDeposit{value: DEPOSIT_VALUE}(stx);
        assertEq(IWToken(nativeWToken).balanceOf(address(gateway)), 0, "nothing stranded");
    }

    /// msg.value must equal the deposit's nativeWToken amount: any surplus would stay wrapped in
    /// the Gateway, and a non-DEPOSIT transaction pulls nothing at all.
    function test_handleWrapAndDeposit_rejectsMismatch() public {
        vm.deal(address(this), 4 * DEPOSIT_VALUE);

        ShieldedTransaction memory empty;
        empty.txType = ShieldedTransactionType.DEPOSIT;
        vm.expectRevert(abi.encodeWithSelector(Gateway.WrapAmountMismatch.selector, DEPOSIT_VALUE, 0));
        gateway.handleWrapAndDeposit{value: DEPOSIT_VALUE}(empty);

        ShieldedTransaction memory less = _wrapDeposit(ShieldedTransactionType.DEPOSIT, assetId, uint224(DEPOSIT_VALUE - 1));
        vm.expectRevert(abi.encodeWithSelector(Gateway.WrapAmountMismatch.selector, DEPOSIT_VALUE, DEPOSIT_VALUE - 1));
        gateway.handleWrapAndDeposit{value: DEPOSIT_VALUE}(less);

        ShieldedTransaction memory otherAsset = _wrapDeposit(ShieldedTransactionType.DEPOSIT, assetId + 1, uint224(DEPOSIT_VALUE));
        vm.expectRevert(abi.encodeWithSelector(Gateway.WrapAmountMismatch.selector, DEPOSIT_VALUE, 0));
        gateway.handleWrapAndDeposit{value: DEPOSIT_VALUE}(otherAsset);

        ShieldedTransaction memory transfer = _wrapDeposit(ShieldedTransactionType.TRANSFER, assetId, uint224(DEPOSIT_VALUE));
        vm.expectRevert(abi.encodeWithSelector(Gateway.WrapAmountMismatch.selector, DEPOSIT_VALUE, 0));
        gateway.handleWrapAndDeposit{value: DEPOSIT_VALUE}(transfer);

        ShieldedTransaction memory zero = _wrapDeposit(ShieldedTransactionType.DEPOSIT, assetId, 0);
        vm.expectRevert(abi.encodeWithSelector(Gateway.WrapAmountMismatch.selector, 0, 0));
        gateway.handleWrapAndDeposit{value: 0}(zero);
    }

    function test_handleUserOp() public {
        ShieldedTransaction memory stx;
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

        // A bundler-sponsored op is never a deposit (see Paymaster.t.sol createPackedUserOps).
        stx.txType = ShieldedTransactionType.WITHDRAW;
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

        PackedUserOperation memory userOp;
        userOp.sender = address(gateway);
        userOp.callData = abi.encodeCall(Gateway.handleUserOp, (stx));
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
