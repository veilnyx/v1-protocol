// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma abicoder v2;

import {PoolTest} from "test/fixtures/PoolTest.sol";
import {Pool} from "src/core/Pool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransactionLogic.sol";
import {CurveNGAdaptor as CurveAdaptor, Payload} from "src/adaptors/curveNG/CurveNGAdaptor.sol";
import {IAdaptor} from "src/interfaces/IAdaptor.sol";
import {IAdaptorHandler} from "src/interfaces/IAdaptorHandler.sol";
import {AssetAmount} from "src/interfaces/IAdaptor.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Asset, AssetType} from "src/libraries/AssetLogic.sol";
import {ICurvePool} from "src/adaptors/curveNG/ICurvePool.sol";
import {console} from "forge-std/Test.sol";

contract CurveAdaptorTest is PoolTest {
    error CheckChainConfig();

    CurveAdaptor curveAdaptor;
    uint256 public constant INITIAL_SUPPLY_USDT = 5e6;
    uint256 public constant INITIAL_SUPPLY_CRVUSD = 5e18;
    address public user = 0x689EcF264657302052c3dfBD631e4c20d3ED0baB;
    address public USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public crvUSD = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;
    address public crvUSD_USDT_Pool =
        0x390f3595bCa2Df7d23783dFd126427CCeb997BF4;
    uint256 public constant MAX_SLIPPAGE_BPS = 70_00; // allowing max 50% slippage for testing purposes

    function setUp() external {
        if (!shouldTestRun()) {
            vm.skip(true);
        }

        _setUp();

        // deploying Curve adaptor and adding test pool support
        curveAdaptor = new CurveAdaptor(pool);
        /// @dev update convert req fixture with this adaptor addr as `to`
        console.log("Curve adaptor deployed:", address(curveAdaptor));

        // Whitelist the hardcoded adaptor address used in fixture ZK proofs
        // and etch the dynamically deployed adaptor's runtime code at that address
        address fixtureAdaptorAddr = 0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8;
        vm.etch(fixtureAdaptorAddr, address(curveAdaptor).code);

        // Adaptor support on Veilnyx Protocol
        address poolOwner = pool.owner();
        vm.startPrank(poolOwner);
        pool.addAdaptorSupport(IAdaptorHandler(fixtureAdaptorAddr), true);

        AssetType assetType = AssetType.ERC20;
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = USDT;
        assetAddresses[1] = crvUSD;
        assetAddresses[2] = crvUSD_USDT_Pool;
        uint8[] memory precisions = new uint8[](3);
        precisions[0] = 6;
        precisions[1] = 18;
        precisions[2] = 18;

        pool.addAssets(
            assetType,
            _toAssetInitParams(
                assetAddresses,
                precisions,
                _mockFeedsArray(assetAddresses.length)
            )
        );
        vm.stopPrank();

        vm.startPrank(user);
        _dealUSDT(user, INITIAL_SUPPLY_USDT);
        deal(crvUSD, user, INITIAL_SUPPLY_CRVUSD);

        SafeERC20.forceApprove(
            IERC20(USDT),
            address(pool),
            INITIAL_SUPPLY_USDT
        );
        SafeERC20.forceApprove(
            IERC20(crvUSD),
            address(pool),
            INITIAL_SUPPLY_CRVUSD
        );

        ShieldedTransaction memory stxDeposit = _loadShieldedTransaction(
            "deposit_5_testnet_usdt_crvusd"
        );
        pool.transact(stxDeposit);
        vm.stopPrank();

        _processCommitmentTreeQueue();
    }

    function testCurveAdaptorDeploy() external view {
        assert(address(curveAdaptor) != address(0));
    }

    /// @dev Make sure the `CurveAdaptor::receive()` is commented out for this test to work.
    function testDepositOnCurve() public {
        console.log("Initiating deposit on Curve");

        uint256 curveLPTokenBalBeforeSupply = IERC20(crvUSD_USDT_Pool)
            .balanceOf(address(pool));

        ShieldedTransaction memory stxSupply = _loadShieldedTransaction(
            "supply_5_usdt_crvUsd_on_curve"
        );

        pool.transact(stxSupply);

        // Asserts
        uint256 curveLPTokenBalPostSupply = IERC20(crvUSD_USDT_Pool).balanceOf(
            address(pool)
        );

        console.log(
            "Pool lp token bal before supply:",
            curveLPTokenBalBeforeSupply
        );
        console.log(
            "Pool lp token bal after supply:",
            curveLPTokenBalPostSupply
        );
        assert(curveLPTokenBalPostSupply > curveLPTokenBalBeforeSupply);

        // direct adaptor testing
        /**
        (
            uint24[] memory outAssetIds,
            uint256[] memory outValues
        ) = _depositInCurve();

        assert(outAssetIds.length == 1);
        assert(outValues[0] > 0);
        console.log(
            "LP token amount received:",
            IERC20(crvUSD_USDT_Pool).balanceOf(address(curveAdaptor))
        );
         */
    }

    function testBalancedWithdraw() public {
        AssetAmount[] memory depositOutAssets = _depositInCurve();

        /// @todo uncommet
        // _performSwapsToGenerateFee(); // ("Underlying tokens received:", 1966937 [1.966e6], 3035599336757587327 [3.035e18])

        uint256[] memory underlyingTokenAmts = new uint256[](2);
        underlyingTokenAmts[0] = uint256(0);
        underlyingTokenAmts[1] = uint256(0);

        Payload memory payload = Payload({
            curvePool: crvUSD_USDT_Pool,
            action: 1,
            withdrawType: 0,
            singleCoinIndex: 0,
            underlyingTokenAmts: underlyingTokenAmts,
            slippageBps: MAX_SLIPPAGE_BPS
        });

        bytes memory payloadEncoded = abi.encode(payload);

        vm.startPrank(user);
        /// @dev We don't need to transfer the LP tokens to the CurveAdaptor as during the deposit, LP tokens were received by the CurveAdaptor itself.
        AssetAmount[] memory outAssets = IAdaptor(address(curveAdaptor))
            .handleAssets(depositOutAssets, payloadEncoded);
        vm.stopPrank();

        console.log(
            "Underlying tokens received:",
            IERC20(USDT).balanceOf(address(curveAdaptor)),
            IERC20(crvUSD).balanceOf(address(curveAdaptor))
        );

        assert(outAssets.length == 2);
        assert(outAssets[0].value > 0);
        assert(outAssets[1].value > 0);
        assert(IERC20(USDT).balanceOf(address(curveAdaptor)) > 0);
        assert(IERC20(crvUSD).balanceOf(address(curveAdaptor)) > 0);
    }

    function testOneCoinWithdraw() public {
        AssetAmount[] memory depositOutAssets = _depositInCurve();

        /// @todo uncommet
        // _performSwapsToGenerateFee();

        uint256[] memory underlyingTokenAmts = new uint256[](2);
        underlyingTokenAmts[0] = uint256(0);
        underlyingTokenAmts[1] = uint256(0);

        Payload memory payload = Payload({
            curvePool: crvUSD_USDT_Pool,
            action: uint8(1),
            withdrawType: uint8(1),
            singleCoinIndex: uint8(0),
            underlyingTokenAmts: underlyingTokenAmts,
            slippageBps: MAX_SLIPPAGE_BPS
        });

        bytes memory payloadEncoded = abi.encode(payload);

        vm.startPrank(user);
        AssetAmount[] memory outAssets = IAdaptor(address(curveAdaptor))
            .handleAssets(depositOutAssets, payloadEncoded); // staking directly through CurveAdaptor
        vm.stopPrank();

        console.log(
            "Underlying tokens received:",
            IERC20(USDT).balanceOf(address(curveAdaptor)),
            IERC20(crvUSD).balanceOf(address(curveAdaptor))
        );

        assert(outAssets.length == 1);
        assert(outAssets[0].value > 0);
        assert(IERC20(USDT).balanceOf(address(curveAdaptor)) > 0);
        assert(IERC20(crvUSD).balanceOf(address(curveAdaptor)) == 0);
    }

    function testImbalanceWithdraw() public {
        AssetAmount[] memory depositOutAssets = _depositInCurve();

        // _performSwapsToGenerateFee();

        // max USDT based on deposit: 3.9e6 USDT
        uint256 usdtWithdrawAmt = 2e6;
        // max crvUSD based on deposit: 6.04 crvUSD
        uint256 crvUSDWithdrawAmt = 4e18;

        uint256[] memory underlyingTokenAmts = new uint256[](2);
        // not withdrawing all underlying tokens
        underlyingTokenAmts[0] = uint256(usdtWithdrawAmt);
        underlyingTokenAmts[1] = uint256(crvUSDWithdrawAmt);

        Payload memory payload = Payload({
            curvePool: crvUSD_USDT_Pool,
            action: uint8(1),
            withdrawType: uint8(2),
            singleCoinIndex: uint8(0),
            underlyingTokenAmts: underlyingTokenAmts,
            slippageBps: MAX_SLIPPAGE_BPS
        });

        bytes memory payloadEncoded = abi.encode(payload);

        vm.startPrank(user);
        AssetAmount[] memory outAssets = IAdaptor(address(curveAdaptor))
            .handleAssets(depositOutAssets, payloadEncoded); // staking directly through CurveAdaptor
        vm.stopPrank();

        console.log(
            "Underlying tokens received:",
            IERC20(USDT).balanceOf(address(curveAdaptor)),
            IERC20(crvUSD).balanceOf(address(curveAdaptor)),
            IERC20(crvUSD_USDT_Pool).balanceOf(address(curveAdaptor))
        );

        assert(outAssets.length == 2);
        assert(outAssets[0].value > 0);
        assert(outAssets[1].value > 0);
        assert(IERC20(USDT).balanceOf(address(curveAdaptor)) > 0);
        assert(IERC20(crvUSD).balanceOf(address(curveAdaptor)) > 0);
        // since not withdrawing all underlying tokens, some LP token bal should be left
        assert(IERC20(crvUSD_USDT_Pool).balanceOf(address(curveAdaptor)) > 0);
    }

    function testGetLPTokenCount() public view {
        uint256[] memory underlyingTokenAmts = new uint256[](2);
        underlyingTokenAmts[0] = uint256(2);
        underlyingTokenAmts[1] = uint256(4);

        uint256 lpTokenCount = curveAdaptor.getLPTokenCount(
            crvUSD_USDT_Pool,
            underlyingTokenAmts,
            true
        );

        console.log("LP token count for 2 USDT and 4 crvUSD:", lpTokenCount);
        assert(lpTokenCount > 0);
    }

    function _depositInCurve() internal returns (AssetAmount[] memory) {
        AssetAmount[] memory inAssets = new AssetAmount[](2);
        inAssets[0] = AssetAmount(pool.getAsset(USDT).id, INITIAL_SUPPLY_USDT);
        inAssets[1] = AssetAmount(
            pool.getAsset(crvUSD).id,
            INITIAL_SUPPLY_CRVUSD
        );

        uint256[] memory underlyingTokenAmts = new uint256[](2);
        underlyingTokenAmts[0] = uint256(0);
        underlyingTokenAmts[1] = uint256(0);

        Payload memory payload = Payload({
            curvePool: crvUSD_USDT_Pool,
            action: 0,
            withdrawType: 0,
            singleCoinIndex: 0,
            underlyingTokenAmts: underlyingTokenAmts,
            slippageBps: MAX_SLIPPAGE_BPS
        });

        bytes memory payloadEncoded = abi.encode(payload);
        console.log("Test payload:");
        console.logBytes(payloadEncoded);

        // Re-fund user since initial balance was consumed during setUp deposit
        _dealUSDT(user, INITIAL_SUPPLY_USDT);
        deal(crvUSD, user, INITIAL_SUPPLY_CRVUSD);

        vm.startPrank(user);
        SafeERC20.forceApprove(
            IERC20(USDT),
            address(curveAdaptor),
            INITIAL_SUPPLY_USDT
        );
        SafeERC20.forceApprove(
            IERC20(crvUSD),
            address(curveAdaptor),
            INITIAL_SUPPLY_CRVUSD
        );
        SafeERC20.safeTransfer(
            IERC20(USDT),
            address(curveAdaptor),
            INITIAL_SUPPLY_USDT
        );
        SafeERC20.safeTransfer(
            IERC20(crvUSD),
            address(curveAdaptor),
            INITIAL_SUPPLY_CRVUSD
        );

        AssetAmount[] memory outAssets = IAdaptor(address(curveAdaptor))
            .handleAssets(inAssets, payloadEncoded); // staking directly through CurveAdaptor
        vm.stopPrank();

        return outAssets;
    }

    function _performSwapsToGenerateFee() internal {
        deal(crvUSD, user, 50e18);
        console.log("Performing crvUSD swaps");
        for (uint i; i < 5; i++) {
            vm.startPrank(user);
            SafeERC20.forceApprove(
                IERC20(crvUSD),
                address(crvUSD_USDT_Pool),
                10e18
            );
            ICurvePool(crvUSD_USDT_Pool).exchange(1, 0, 10e18, 0, user);
            vm.stopPrank();
        }

        deal(USDT, user, 50e6);
        console.log("Performing USDT swaps");
        for (uint i; i < 5; i++) {
            vm.startPrank(user);
            SafeERC20.forceApprove(
                IERC20(USDT),
                address(crvUSD_USDT_Pool),
                10e6
            );
            ICurvePool(crvUSD_USDT_Pool).exchange(0, 1, 10e6, 0, user);
            vm.stopPrank();

            vm.warp(vm.getBlockTimestamp() + 1 days);
            vm.roll(vm.getBlockNumber() + 100);
        }
    }

    /**
     * 
    /// @dev This test bypasses the Veilnyx protocol and directly tests the Lido integration from the CurveAdaptor.
    /// @dev Pls uncomment the `receive()` on the CurveAdaptor to enable this test.
    /// @dev Will only run on Holesky testnet.
    function testWstEthUnStakingOnLidoBypassingVeilnyx() public {
        require(
            block.chainid == 17000,
            "Unstaking test only on Holesky testnet"
        );
        uint256 initialDeposit = 10 ether;
        vm.deal(address(curveAdaptor), initialDeposit);
        vm.prank(address(curveAdaptor));
        IWToken(WETH).deposit{value: initialDeposit}();

        uint24[] memory inAssetIds = new uint24[](1);
        uint256[] memory inValues = new uint256[](1);
        bytes memory payload = bytes("");

        inAssetIds[0] = pool.getAsset(WETH).id;
        inValues[0] = initialDeposit;

        IAdaptor(address(curveAdaptor)).handleAssets(
            inAssetIds,
            inValues,
            payload
        ); // staking directly through CurveAdaptor

        console.log("Initiating Unstaking on Lido");
        uint256 adpWstETHBalBeforeUnStaking = IERC20(wstETH).balanceOf(
            address(curveAdaptor)
        );

        inAssetIds[0] = pool.getAsset(wstETH).id;
        inValues[0] = adpWstETHBalBeforeUnStaking;
        payload = abi.encode(user);

        IAdaptor(address(curveAdaptor)).handleAssets(
            inAssetIds,
            inValues,
            payload
        ); // unstaking directly through LidoAdp

        // Asserts
        uint256 adpWstETHBalPostUnStake = IERC20(wstETH).balanceOf(
            address(pool)
        );
        console.log(
            "Pool wstEth bal before unstaking:",
            adpWstETHBalBeforeUnStaking
        );
        console.log(
            "Pool wstEth bal after unstaking:",
            adpWstETHBalPostUnStake
        );

        assert(adpWstETHBalPostUnStake < adpWstETHBalBeforeUnStaking);
        assert(IERC721(withdrawalQueueERC721).balanceOf(user) > 0); // NFT received check
    }

     */

    /// @dev Only allowing Lido tests to run on Holesky testnet and ETH mainnet. More chains can be added.
    function shouldTestRun() internal view returns (bool) {
        if (block.chainid != 1) {
            console.log(
                "Skipping Curve adaptor tests on the current chain as Curve protocol may not be deployed. To run Lido tests, kindly run the tests on the Mainnet or Tenderly fork"
            );
            return false;
        }
        return true;
    }

    function _dealUSDT(address to, uint256 amount) internal {
        // USDT balance storage slot is at position 2
        bytes32 slot = keccak256(abi.encode(to, uint256(2)));
        vm.store(USDT, slot, bytes32(amount));

        // Also update total supply if needed
        bytes32 totalSupplySlot = bytes32(uint256(1));
        uint256 currentSupply = uint256(vm.load(USDT, totalSupplySlot));
        vm.store(USDT, totalSupplySlot, bytes32(currentSupply + amount));
    }
}
