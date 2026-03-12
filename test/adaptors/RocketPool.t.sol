// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma abicoder v2;

import {PoolTest} from "test/fixtures/PoolTest.sol";
import {Pool} from "src/core/Pool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransaction.sol";
import {RocketPoolAdaptor} from "src/adaptors/rocketPool/RocketPoolAdaptor.sol";
import {IAdaptor} from "src/interfaces/IAdaptor.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {console} from "forge-std/console.sol";

enum Action {
    STAKE,
    UNSTAKE
}

contract RocketPoolAdpTest is PoolTest {
    using SafeERC20 for IERC20;

    error CheckChainConfig();

    RocketPoolAdaptor rocketPoolAdp;
    address rocketSwapRouter = 0x16D5A408e807db8eF7c578279BEeEe6b228f1c1C;
    address public rETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IWToken public iWETH = IWToken(WETH);
    uint256 public constant INITIAL_SUPPLY = 5 ether;
    uint256 public constant STAKE_AMT = 1 ether;
    uint256 public constant MIN_OUT_AMT = 0.8 ether;
    uint256 public constant SWAP_PORTIONS = 50;

    address public user = 0x689EcF264657302052c3dfBD631e4c20d3ED0baB;
    address fixtureAdaptorAddr = 0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8;

    function setUp() external {
        require(shouldTestRun(), "RocketPoolAdpTest: Chain not supported");
        _setUp();

        // deploying Uniswap adaptor
        rocketPoolAdp = new RocketPoolAdaptor(rETH, WETH, address(pool));

        /// @dev update convert req fixture with this adaptor addr as `to`
        console.log("RocketPool adaptor deployed:", address(rocketPoolAdp));

        // Whitelist the hardcoded adaptor address used in fixture ZK proofs
        // and etch the dynamically deployed adaptor's runtime code at that address
        vm.etch(fixtureAdaptorAddr, address(rocketPoolAdp).code);

        // Asset & Adaptor support on Veilnyx Protocol
        address poolOwner = pool.owner();
        vm.prank(poolOwner);
        pool.addAdaptorSupport(fixtureAdaptorAddr, true);

        AssetType assetType = AssetType.ERC20;
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = rETH;

        uint8[] memory assetsPrecision = new uint8[](1);
        assetsPrecision[0] = 18;
        pool.addAssets(assetType, assetAddresses, assetsPrecision);

        deal(WETH, user, INITIAL_SUPPLY);
        deal(rETH, user, INITIAL_SUPPLY);

        vm.startPrank(user);
        iWETH.approve(address(pool), INITIAL_SUPPLY); // depositing weth to pool
        ShieldedTransaction memory stxWethDeposit = _loadShieldedTransaction(
            "deposit_2_testnet_weth"
        );
        pool.transact(stxWethDeposit, false);
        vm.stopPrank();

        _processCommitmentTreeQueue();
    }

    function testRocketPoolAdaptorDeploy() external view {
        assert(fixtureAdaptorAddr != address(0));
    }

    function testStakingDirectlyOnRocketPool() external {
        vm.prank(user);
        IERC20(WETH).safeTransfer(fixtureAdaptorAddr, STAKE_AMT);

        uint24[] memory inAssetIds = new uint24[](1);
        uint256[] memory inValues = new uint256[](1);
        inAssetIds[0] = pool.getAsset(WETH).id;
        inValues[0] = STAKE_AMT;
        bytes memory payload = abi.encode(
            Action.STAKE,
            SWAP_PORTIONS,
            SWAP_PORTIONS,
            MIN_OUT_AMT
        );

        console.log("Initiating staking on RocketPool");

        (, uint256[] memory outValues) = IAdaptor(fixtureAdaptorAddr)
            .handleAssets(inAssetIds, inValues, payload); // staking directly through RocketPoolAdp

        uint256 rEthBal = IERC20(rETH).balanceOf(fixtureAdaptorAddr);
        console.log("rETH bal:", rEthBal);
        assert(rEthBal > 0);
        assertEq(outValues[0], rEthBal);
    }

    function testUnStakingDirectlyOnRocketPool() external {
        vm.prank(user);
        IERC20(rETH).safeTransfer(fixtureAdaptorAddr, STAKE_AMT);

        uint24[] memory inAssetIds = new uint24[](1);
        uint256[] memory inValues = new uint256[](1);
        inAssetIds[0] = pool.getAsset(rETH).id;
        inValues[0] = STAKE_AMT;
        bytes memory payload = abi.encode(
            Action.UNSTAKE,
            SWAP_PORTIONS,
            SWAP_PORTIONS,
            MIN_OUT_AMT
        );

        console.log("Initiating unstaking on RocketPool");
        (, uint256[] memory outValues) = IAdaptor(fixtureAdaptorAddr)
            .handleAssets(inAssetIds, inValues, payload); // unstaking directly through RocketPoolAdp

        uint256 wEthBal = IERC20(WETH).balanceOf(fixtureAdaptorAddr);
        console.log("wETH bal:", wEthBal);
        assert(wEthBal > 0);
        assertEq(outValues[0], wEthBal);
    }

    /// @dev Make sure the `RocketPoolAdaptor::receive()` is commented out for this test to work.
    function testWethStakingOnRocketPool() public {
        console.log("Initiating staking on RocketPool");
        uint256 poolrETHBalBeforeStaking = IERC20(rETH).balanceOf(
            address(pool)
        );

        ShieldedTransaction memory stxStake = _loadShieldedTransaction(
            "stake_1_testnet_weth_rocketpool"
        );
        pool.transact(stxStake, false);

        // Asserts
        uint256 poolrETHBalPostStake = IERC20(rETH).balanceOf(address(pool));
        console.log("Pool rETH bal before swap:", poolrETHBalBeforeStaking);
        console.log("Pool rETH bal after swap:", poolrETHBalPostStake);
        assert(poolrETHBalPostStake > poolrETHBalBeforeStaking);
    }

    /// @dev Only allowing RocketPool tests to run on Holesky testnet and ETH mainnet. More chains can be added.
    function shouldTestRun() internal view returns (bool) {
        if (block.chainid != 17000 && block.chainid != 1) {
            console.log(
                "Skipping RocketPool adaptor tests on the current chain as RocketPool protocol may not be deployed. To run RocketPool tests, kindly run the tests on the Tenderly Mainnet/Mainnet fork where RocketPool is deployed."
            );
            return false;
        }
        return true;
    }
}
