// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Paymaster} from "src/core/Paymaster.sol";
import {ShieldedTransaction, ShieldedTransactionType} from "src/libraries/ShieldedTransaction.sol";
import {Mempool, PreVerificationDetails} from "src/core/Mempool.sol";
import {Pool} from "src/core/Pool.sol";
import {MockPool} from "test/mocks/MockPool.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {console2} from "forge-std/console2.sol";

// import {PoolTransactTest} from "test/helpers/PoolTransact.t.sol";

contract PaymasterTest is PoolTest {
    Paymaster public paymaster;

    uint24 feeAssetId;
    uint256 feeValue = 0.002 ether;
    uint256 feeValueForOutsourcedVerification = 0.001 ether;

    ShieldedTransaction stx;
    PreVerificationDetails preVerificationDetails;
    PackedUserOperation userOp;

    modifier createPackedUserOps() {
        stx.pubAssets = new uint248[](1);
        stx.pubAssets[0] = uint248(
            bytes31(bytes.concat(bytes3(feeAssetId), bytes12(uint96(10 ether))))
        );

        stx.feeData = uint256(
            bytes32(
                bytes.concat(
                    bytes20(address(paymaster)),
                    bytes3(uint24(feeAssetId)),
                    bytes9(uint72(feeValue))
                )
            )
        );

        uint256[] memory publicInputs = new uint256[](2);
        publicInputs[0] = 0;
        publicInputs[1] = 0;

        preVerificationDetails = PreVerificationDetails({
            isPreVerified: false,
            circuitId: bytes32(0),
            publicInputs: publicInputs,
            verifierAddr: address(0)
        });

        userOp.sender = address(pool);
        userOp.callData = abi.encodeCall(
            MockPool.transactForPaymasterTestSetup,
            (stx, preVerificationDetails)
        );
        _;
    }

    function setUp() public {
        _setUp();
        feeAssetId = asset1.id;
        entryPoint = address(new EntryPoint());
        paymaster = new Paymaster(entryPoint, address(pool));
        console2.log("paymaster:", address(paymaster));
        paymaster.setAssetFee(feeAssetId, feeValue);
        paymaster.setAssetFeeForPreVerifiedTx(
            feeAssetId,
            feeValueForOutsourcedVerification
        );
    }

    function test_updateFeeAsset() public {
        uint24 assetId = 65538;
        uint256 newFeeValue = 0.1 ether;
        paymaster.setAssetFee(assetId, newFeeValue);
        assertEq(paymaster.getAssetFee(assetId), newFeeValue);

        bool isSupported = paymaster.isAssetFeeSupported(assetId);
        assertTrue(isSupported);
    }

    function test_depositAndWithdrawEntryPoint() public {
        uint256 value = 1000 ether;
        vm.deal(address(this), value);

        paymaster.depositToEntryPoint{value: value}();

        uint256 deposit = paymaster.getEntryPointDeposit();
        assertEq(deposit, value);

        address withdrawAddress = makeAddr("withdraw");
        uint256 withdrawValue = 100 ether;
        paymaster.withdrawFromEntryPoint(
            payable(withdrawAddress),
            withdrawValue
        );

        uint256 depositBal = paymaster.getEntryPointDeposit();

        assertEq(depositBal, value - withdrawValue);
        assertEq(withdrawAddress.balance, withdrawValue);
    }

    function test_withdrawAsset() public {
        uint256 value = 10 ether;
        vm.deal(address(this), value);
        (bool success, ) = address(paymaster).call{value: value}("");
        assertTrue(success);

        address withdraw = makeAddr("withdraw");
        paymaster.withdrawAsset(address(0), payable(withdraw), value);

        assertEq(withdraw.balance, value);
    }

    ///////////////////////////////////////////
    /// Paymaster UserOp Validation tests /////
    //////////////////////////////////////////
    /// @dev The test cases are designed to have Pool as the sender. In actuality, the sender is the Gateway contract.
    function test_revertWhenSenderIsNotPool() public createPackedUserOps {
        userOp.sender = address(0);

        vm.expectRevert(
            abi.encodeWithSelector(Paymaster.InvalidSender.selector, address(0))
        );
        vm.startPrank(entryPoint);
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0);
        vm.stopPrank();
    }

    function test_revertWhenPaymasterFeesIsNotEnough() public {
        uint256 lowFeeValue = feeValue / 2;

        stx.feeData = uint256(
            bytes32(
                bytes.concat(
                    bytes20(address(paymaster)),
                    bytes3(uint24(feeAssetId)),
                    bytes9(uint72(lowFeeValue))
                )
            )
        );

        userOp.sender = address(pool);
        userOp.callData = abi.encodeCall(
            MockPool.transactForPaymasterTestSetup,
            (stx, preVerificationDetails)
        );

        vm.prank(entryPoint);
        vm.expectRevert(
            abi.encodeWithSelector(
                Paymaster.InsufficientFee.selector,
                lowFeeValue,
                feeValue
            )
        );
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0);
    }

    function test_revertWhenPaymasterFeesIsNotEnoughForPreVerifiedTx()
        public
        createPackedUserOps
    {
        uint256 lowFeeValue = feeValueForOutsourcedVerification - 0.00005 ether;
        // feeding the required values for outsourced verification in userops.calldata
        preVerificationDetails.isPreVerified = true;
        stx.feeData = uint256(
            bytes32(
                bytes.concat(
                    bytes20(address(paymaster)),
                    bytes3(uint24(feeAssetId)),
                    bytes9(uint72(lowFeeValue))
                )
            )
        );

        userOp.callData = abi.encodeCall(
            MockPool.transactForPaymasterTestSetup,
            (stx, preVerificationDetails)
        );

        vm.startPrank(entryPoint);
        vm.expectRevert(
            abi.encodeWithSelector(
                Paymaster.InsufficientFee.selector,
                lowFeeValue,
                feeValueForOutsourcedVerification
            )
        );
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0);
        vm.stopPrank();
    }

    function test_revertWhenFeeAssetIdIsInvalid() public createPackedUserOps {
        // feeding the wrong feeAssetId in STX and packedUserOp
        stx.feeData = uint256(
            bytes32(
                bytes.concat(
                    bytes20(address(paymaster)),
                    bytes3(uint24(0)),
                    bytes9(uint72(feeValue))
                )
            )
        );

        userOp.callData = abi.encodeCall(
            MockPool.transactForPaymasterTestSetup,
            (stx, preVerificationDetails)
        );

        vm.prank(entryPoint);
        vm.expectRevert(
            abi.encodeWithSelector(
                Paymaster.UnsupportedFeeAsset.selector,
                uint24(0)
            )
        );
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0);
    }

    function test_validatePaymasterUserOp() public createPackedUserOps {
        vm.startPrank(entryPoint);
        (, uint256 flag) = paymaster.validatePaymasterUserOp(
            userOp,
            bytes32(0),
            0
        );
        vm.stopPrank();

        assertEq(flag, 0);
    }

    function test_validatePaymasterUserOpForOutsourcedTx()
        public
        createPackedUserOps
    {
        // feeding the required values for outsourced verification in userops.calldata
        preVerificationDetails.isPreVerified = true;
        stx.feeData = uint256(
            bytes32(
                bytes.concat(
                    bytes20(address(paymaster)),
                    bytes3(uint24(feeAssetId)),
                    bytes9(uint72(feeValueForOutsourcedVerification))
                )
            )
        );

        userOp.callData = abi.encodeCall(
            MockPool.transactForPaymasterTestSetup,
            (stx, preVerificationDetails)
        );

        vm.startPrank(entryPoint);
        (, uint256 flag) = paymaster.validatePaymasterUserOp(
            userOp,
            bytes32(0),
            0
        );
        vm.stopPrank();

        assertEq(flag, 0);
    }

    function test_paymasterFeeBalUpdateInPool() external {
        _makePreDeposit();

        uint256 value = 1000 ether;
        vm.deal(address(this), value);
        paymaster.depositToEntryPoint{value: value}();

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "withdraw_10_weth_with_weth_fee"
        );
        pool.transact(stx, false);

        uint256 assetFeeByPaymaster = paymaster.getAssetFee(feeAssetId);
        vm.prank(address(paymaster));
        assertEq(
            pool.getCollectedPaymasterFee(feeAssetId, address(paymaster)),
            assetFeeByPaymaster
        );
    }

    function test_paymasterFeeClaim() external {
        _makePreDeposit();

        uint256 value = 1000 ether;
        vm.deal(address(this), value);
        paymaster.depositToEntryPoint{value: value}();

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "withdraw_10_weth_with_weth_fee"
        );
        pool.transact(stx, false);

        vm.startPrank(address(paymaster));
        pool.withdrawPaymasterFee(feeAssetId, address(paymaster));

        assertEq(
            pool.getCollectedPaymasterFee(feeAssetId, address(paymaster)),
            0
        );
        assertEq(token1.balanceOf(address(paymaster)), feeValue);
    }

    /**
    function testDecodePackedUserOp() public {
        PackedUserOperation memory packedUserOp = _loadPackedUserOp(
            "deposit_weth_tx_packed_userop"
        );

        (
            address paymaster,
            uint24 feeAssetId,
            uint256 feeValue,
            bool isVeriOutsourced
        ) = paymaster.parseFeeAndPaymasterData(packedUserOp);

        assertEq(isVeriOutsourced, false);
    }
     */
}
