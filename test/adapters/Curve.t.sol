// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma abicoder v2;

import {PoolTest} from "test/fixtures/PoolTest.sol";
import {Pool} from "src/core/Pool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransaction.sol";
import {CurveNGAdaptor as CurveAdaptor} from "src/adaptors/curveNG/CurveNGAdaptor.sol";
import {IAdaptor} from "src/interfaces/IAdaptor.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {console} from "forge-std/Test.sol";

contract CurveAdaptorTest is PoolTest {
    error CheckChainConfig();

    CurveAdaptor curveAdaptor;
    uint256 public constant INITIAL_SUPPLY = 5e6;
    address public user = 0x689EcF264657302052c3dfBD631e4c20d3ED0baB;
    address public USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public crvUSD = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;
    address public crvUSD_USDT_Pool =
        0x390f3595bCa2Df7d23783dFd126427CCeb997BF4;

    function setUp() external {
        require(shouldTestRun(), "CurveAdaptorTest: Chain not supported");
        _setUp();

        // deploying Curve adaptor and adding test pool support
        curveAdaptor = new CurveAdaptor(address(pool));
        /// @dev update convert req fixture with this adaptor addr as `to`
        console.log("Curve adaptor deployed:", address(curveAdaptor));

        address[] memory poolCoins = new address[](2);
        poolCoins[0] = USDT;
        poolCoins[1] = crvUSD;
        curveAdaptor.addPool(crvUSD_USDT_Pool, poolCoins);

        // Asset & Adaptor support on Labyrinth Protocol
        address poolOwner = pool.owner();
        vm.startPrank(poolOwner);
        pool.addAdaptorSupport(address(curveAdaptor), true);

        address[] memory supportedAssets = new address[](2);
        supportedAssets[0] = USDT;
        supportedAssets[1] = crvUSD;
        pool.addAssets(AssetType.ERC20, supportedAssets);
        vm.stopPrank();

        deal(USDT, user, INITIAL_SUPPLY * 2);
        deal(crvUSD, user, INITIAL_SUPPLY * 2);

        vm.startPrank(user);
        IERC20(USDT).approve(address(pool), INITIAL_SUPPLY);
        IERC20(crvUSD).approve(address(pool), INITIAL_SUPPLY);

        ShieldedTransaction memory stxDeposit = _loadShieldedTransaction(
            "deposit_2_testnet_usdt_crvusd"
        );
        pool.transact(stxDeposit);
        vm.stopPrank();

        // _processCommitmentTreeQueue();
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
            "supply_2_usdt_crvUsd_on_curve"
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
    }

    /**
     * 
    /// @dev This test bypasses the Labyrinth protocol and directly tests the Lido integration from the CurveAdaptor.
    /// @dev Pls uncomment the `receive()` on the CurveAdaptor to enable this test.
    /// @dev Will only run on Holesky testnet.
    function testWstEthUnStakingOnLidoBypassingLabyrinth() public {
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
}
