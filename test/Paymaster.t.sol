// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Paymaster} from "src/core/Paymaster.sol";
import {Asset} from "src/libraries/Asset.sol";
import {ShieldedTransaction, ShieldedTransactionType} from "src/libraries/ShieldedTransaction.sol";
import {Mempool, PreVerificationDetails} from "src/core/Mempool.sol";
import {Pool} from "src/core/Pool.sol";
import {Gateway} from "src/core/Gateway.sol";
import {MockPool} from "test/mocks/MockPool.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {console2} from "forge-std/console2.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

// import {PoolTransactTest} from "test/helpers/PoolTransact.t.sol";

contract PaymasterTest is PoolTest {
    Paymaster public paymaster;
    Gateway public gateway;
    address public constant CHAINLINK_ETH_USDC_FEED_SEPOLIA =
        0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address public constant CHAINLINK_ETH_USDC_FEED_MAINNET =
        0x5147eA642CAEF7BD9c1265AadcA78f997AbB9649;
    uint8 public constant ETH_DECIMALS = 18;
    uint8 public constant USDC_DECIMALS = 6;
    uint256 public constant ETH_SEPOLIA = 11155111;
    uint256 public constant ETH_MAINNET = 1;

    uint24 feeAssetId;
    uint256 feeValue = 0.002 ether;
    uint256 feeValueForOutsourcedVerification = 0.001 ether;

    ShieldedTransaction stx;
    PreVerificationDetails preVerificationDetails;
    PackedUserOperation userOp;

    modifier createPackedUserOps(address gatewayAddr) {
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

        userOp.sender = gatewayAddr;
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
        gateway = new Gateway(
            address(entryPoint),
            makeAddr("wToken"),
            address(pool),
            address(mempool)
        );

        StdCheats.deployCodeTo(
            "Paymaster.sol:Paymaster",
            abi.encode(entryPoint, address(gateway), address(pool)),
            fixture.paymaster
        );
        console2.log("paymaster:", fixture.paymaster);
        paymaster = Paymaster(fixture.paymaster);

        // Setting chainlink feed address to fetch prices
        paymaster.setChainlinkFeed(asset1.id, address(0));

        // asset 2 (USDC)
        if (block.chainid == ETH_SEPOLIA) {
            // Sepolia
            paymaster.setChainlinkFeed(
                asset2.id,
                CHAINLINK_ETH_USDC_FEED_SEPOLIA
            );
        } else if (block.chainid == ETH_MAINNET) {
            // Mainnet
            paymaster.setChainlinkFeed(
                asset2.id,
                CHAINLINK_ETH_USDC_FEED_MAINNET
            );
        } else {
            paymaster.setChainlinkFeed(asset2.id, address(0));
        }
    }

    function _getEthUsdcFeed() internal view returns (AggregatorV3Interface) {
        if (block.chainid == ETH_MAINNET) {
            return AggregatorV3Interface(CHAINLINK_ETH_USDC_FEED_MAINNET);
        }
        return AggregatorV3Interface(CHAINLINK_ETH_USDC_FEED_SEPOLIA);
    }

    function _getEthUsdcFeedData()
        internal
        view
        returns (int256 price, uint256 updatedAt, uint8 decimals)
    {
        AggregatorV3Interface feed = _getEthUsdcFeed();
        (, price, , updatedAt, ) = feed.latestRoundData();
        decimals = feed.decimals();
    }

    function test_convertFeeFromGasTokenToUSDC() public {
        if (block.chainid != ETH_SEPOLIA && block.chainid != ETH_MAINNET) {
            vm.skip(true);
        }

        uint256 feeValueInEth = 2e18;
        uint24 feeAssetIdUSDC = 65538; // USDC

        uint256 feeValueInUSDC = paymaster.convertFeeFromGasTokenToFeeAsset(
            feeValueInEth,
            feeAssetIdUSDC
        );

        (int256 ethInUSDC, , uint8 feedDecimals) = _getEthUsdcFeedData();

        uint256 expectedFeeValueInUSDC = (feeValueInEth *
            uint256(ethInUSDC) *
            10 ** USDC_DECIMALS) / 10 ** (ETH_DECIMALS + feedDecimals);

        assertEq(feeValueInUSDC, expectedFeeValueInUSDC);
    }

    function test_convertFeeFromGasTokenToFeeAsset_whenFeeAssetIsGasTokenItself()
        public
        view
    {
        uint256 feeInEth = 5 ether;

        uint256 feeInGasToken = paymaster.convertFeeFromGasTokenToFeeAsset(
            feeInEth,
            feeAssetId
        );

        assertEq(feeInGasToken, feeInEth);
    }

    function test_revert_convertFeeFromGasTokenToFeeAsset_whenFeeAssetInactive()
        public
    {
        uint24 invalidFeeAssetId = 99999;

        vm.expectRevert(
            abi.encodeWithSelector(
                Paymaster.FeeAssetNotSupportedByVeilnyx.selector,
                invalidFeeAssetId
            )
        );
        paymaster.convertFeeFromGasTokenToFeeAsset(1 ether, invalidFeeAssetId);
    }

    function test_revert_convertFeeFromGasTokenToFeeAsset_whenFeeAssetNotSupport()
        public
    {
        Asset memory asset3 = pool.getAsset(address(tokenReent));
        vm.expectRevert(
            abi.encodeWithSelector(
                Paymaster.AssetNotSupportedAsFeeAsset.selector,
                asset3.id
            )
        );
        paymaster.convertFeeFromGasTokenToFeeAsset(1 ether, asset3.id);
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

    function test_revert_convertFeeFromGasTokenToFeeAsset_whenPriceIsStale()
        public
    {
        (
            int256 ethInUSDC,
            uint256 updatedAt,
            uint8 feedDecimals
        ) = _getEthUsdcFeedData();

        vm.warp(block.timestamp + 2 hours); // Move forward in time to make the price feed stale
        vm.expectRevert(
            abi.encodeWithSelector(
                Paymaster.ChainlinkPriceInvalid.selector,
                ethInUSDC,
                feedDecimals,
                updatedAt
            )
        );
        paymaster.convertFeeFromGasTokenToFeeAsset(1 ether, asset2.id);
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
    function test_revertWhenSenderIsNotPool()
        public
        createPackedUserOps(address(gateway))
    {
        userOp.sender = address(0);

        vm.expectRevert(
            abi.encodeWithSelector(Paymaster.InvalidSender.selector, address(0))
        );
        vm.startPrank(entryPoint);
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0);
        vm.stopPrank();
    }

    /**
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
     */

    function test_revertWhenPaymasterFeesInETHIsNotEnough()
        public
        createPackedUserOps(address(gateway))
    {
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
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), feeValue); // feeValue is maxCostEth (paymaster) / requiredPreFund (entrypoint)
    }

    function test_revertWhenPaymasterFeesInUSDCIsNotEnough()
        public
        createPackedUserOps(address(gateway))
    {
        if (block.chainid != ETH_SEPOLIA && block.chainid != ETH_MAINNET) {
            vm.skip(true);
        }

        (int256 ethInUSDC, , uint8 feedDecimals) = _getEthUsdcFeedData();

        // altering the fee value to be less than the required fee
        uint256 lowFeeValueEth = feeValue / 2;
        uint256 lowFeeValueUSDC = (lowFeeValueEth *
            uint256(ethInUSDC) *
            10 ** USDC_DECIMALS) / 10 ** (ETH_DECIMALS + feedDecimals);

        stx.feeData = uint256(
            bytes32(
                bytes.concat(
                    bytes20(address(paymaster)),
                    bytes3(uint24(asset2.id)),
                    bytes9(uint72(lowFeeValueUSDC))
                )
            )
        );

        userOp.callData = abi.encodeCall(
            MockPool.transactForPaymasterTestSetup,
            (stx, preVerificationDetails)
        );

        // calc required fee in USDC
        // convert `feeValue` (in ETH) to USDC
        uint256 requiredUSDC = (feeValue *
            uint256(ethInUSDC) *
            10 ** USDC_DECIMALS) / 10 ** (ETH_DECIMALS + feedDecimals);

        vm.prank(entryPoint);
        vm.expectRevert(
            abi.encodeWithSelector(
                Paymaster.InsufficientFee.selector,
                lowFeeValueUSDC,
                requiredUSDC
            )
        );
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), feeValue); // feeValue is maxCostEth
    }

    function test_revertWhenPaymasterFeesInETHIsNotEnoughForPreVerifiedTx()
        public
        createPackedUserOps(address(gateway))
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
        paymaster.validatePaymasterUserOp(
            userOp,
            bytes32(0),
            feeValueForOutsourcedVerification
        );
        vm.stopPrank();
    }

    function test_revertWhenFeeAssetIdIsInvalid()
        public
        createPackedUserOps(address(gateway))
    {
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
                Paymaster.FeeAssetNotSupportedByVeilnyx.selector,
                uint24(0)
            )
        );
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0);
    }

    function test_validatePaymasterUserOp()
        public
        createPackedUserOps(address(gateway))
    {
        vm.startPrank(entryPoint);
        (, uint256 flag) = paymaster.validatePaymasterUserOp(
            userOp,
            bytes32(0),
            0
        );
        vm.stopPrank();

        assertEq(flag, 0);
    }

    function test_validatePaymasterUserOpWhenFeesInUSDC()
        public
        createPackedUserOps(address(gateway))
    {
        if (block.chainid != ETH_SEPOLIA && block.chainid != ETH_MAINNET) {
            vm.skip(true);
        }

        (int256 ethInUSDC, , uint8 feedDecimals) = _getEthUsdcFeedData();

        // converting `feeValue` in ETH to USDC
        uint256 feeValueUSDC = ((feeValue *
            uint256(ethInUSDC) *
            10 ** USDC_DECIMALS) / 10 ** (ETH_DECIMALS + feedDecimals));

        stx.feeData = uint256(
            bytes32(
                bytes.concat(
                    bytes20(address(paymaster)),
                    bytes3(uint24(asset2.id)),
                    bytes9(uint72(feeValueUSDC))
                )
            )
        );

        userOp.callData = abi.encodeCall(
            MockPool.transactForPaymasterTestSetup,
            (stx, preVerificationDetails)
        );

        vm.prank(entryPoint);
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), feeValue); // feeValue is maxCostEth
    }

    function test_validatePaymasterUserOpForPreVerifiedTx()
        public
        createPackedUserOps(address(gateway))
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

        ShieldedTransaction memory withdrawSTX = _loadShieldedTransaction(
            "withdraw_10_weth_with_weth_fee"
        );
        pool.transact(withdrawSTX, false);

        uint256 expectedFeeValue = uint256(uint72(withdrawSTX.feeData));

        vm.prank(address(paymaster));
        assertEq(
            pool.getCollectedPaymasterFee(feeAssetId, address(paymaster)),
            expectedFeeValue
        );
    }

    function test_paymasterFeeClaim() external {
        _makePreDeposit();

        uint256 value = 1000 ether;
        vm.deal(address(this), value);
        paymaster.depositToEntryPoint{value: value}();

        ShieldedTransaction memory withdrawSTX = _loadShieldedTransaction(
            "withdraw_10_weth_with_weth_fee"
        );
        pool.transact(withdrawSTX, false);

        vm.startPrank(address(paymaster));
        pool.withdrawPaymasterFee(feeAssetId, address(paymaster));

        /// assertions
        uint256 expectedFeeValue = uint256(uint72(withdrawSTX.feeData));
        assertEq(
            pool.getCollectedPaymasterFee(feeAssetId, address(paymaster)),
            0
        );
        assertEq(token1.balanceOf(address(paymaster)), expectedFeeValue);
    }
}
