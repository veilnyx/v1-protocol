// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {AaveV3Adaptor} from "src/adaptors/aave-v3/AaveV3Adaptor.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {Pool} from "src/core/Pool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransaction.sol";
import {IAdaptor} from "src/interfaces/IAdaptor.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {console} from "forge-std/console.sol";

contract AaveAdaptorTest is PoolTest {
    error CheckChainConfig();

    AaveV3Adaptor aaveAdaptor;
    address aave = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant WETH_AAVE_UNDERLYING =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // Laby pool WETH contract is diff. than the one supported by Aave.

    uint256 public constant INITIAL_SUPPLY = 2 ether;
    uint256 public constant INITIAL_SUPPLY_USDC = 10e6;
    address public user = 0x689EcF264657302052c3dfBD631e4c20d3ED0baB;
    address public constant STATIC_A_TOKEN_FACTORY =
        0x411D79b8cC43384FDE66CaBf9b6a17180c842511;
    address public constant WETH_STATIC_A_TOKEN =
        0x252231882FB38481497f3C767469106297c8d93b;

    function setUp() external {
        require(shouldTestRun(), "LidoAdaptorTest: Chain not supported");
        PoolTest._setUp();

        // deploying aave adaptor
        aaveAdaptor = new AaveV3Adaptor(
            aave,
            address(pool),
            STATIC_A_TOKEN_FACTORY
        );
        /// @dev update convert req fixture with this adaptor addr as `to`
        console.log("Aave adaptor deployed:", address(aaveAdaptor));

        // Asset & Adaptor support on Labyrinth Protocol
        address poolOwner = pool.owner();
        vm.startPrank(poolOwner);
        pool.addAdaptorSupport(address(aaveAdaptor), true);

        AssetType assetType = AssetType.ERC20;
        address[] memory assetAddresses = new address[](1);
        // assetAddresses[0] = WETH_AAVE_UNDERLYING; // already added to the pool
        assetAddresses[0] = WETH_STATIC_A_TOKEN;
        pool.addAssets(assetType, assetAddresses);
        vm.stopPrank();

        deal(WETH_AAVE_UNDERLYING, user, INITIAL_SUPPLY);
        deal(USDC, user, INITIAL_SUPPLY_USDC);

        vm.startPrank(user);
        IWToken(WETH_AAVE_UNDERLYING).approve(address(pool), INITIAL_SUPPLY);
        IERC20(USDC).approve(address(pool), INITIAL_SUPPLY_USDC);
        ShieldedTransaction memory ztxDeposits = _loadShieldedTransaction(
            "deposit_aaveWeth_testnetUsdc"
        );
        pool.transact(ztxDeposits, false);
        vm.stopPrank();
        _processCommitmentTreeQueue();
    }

    function testAaveAdaptorDeploy() external view {
        assert(address(aaveAdaptor) != address(0));
    }

    /// @dev Make sure the `LidoAdaptor::receive()` is commented out for this test to work.
    function testWethLending() public {
        console.log("Initiating staking on aave");
        uint256 poolwETHStaticTokenBalBeforeLending = IERC20(
            WETH_STATIC_A_TOKEN
        ).balanceOf(address(pool));

        ShieldedTransaction memory ztxLend = _loadShieldedTransaction(
            "lend_1_aave_weth"
        );
        pool.transact(ztxLend, false);

        // Asserts
        uint256 poolwETHStaticTokenBalAfterLending = IERC20(WETH_STATIC_A_TOKEN)
            .balanceOf(address(pool));
        console.log(
            "Pool static aToken bal before lending:",
            poolwETHStaticTokenBalBeforeLending
        );
        console.log(
            "Pool static aToken bal after lending:",
            poolwETHStaticTokenBalAfterLending
        );
        assert(
            poolwETHStaticTokenBalAfterLending >
                poolwETHStaticTokenBalBeforeLending
        );
    }

    function testWethLendingThroughBundler() public {
        console.log("Initiating staking on aave");
        uint256 poolwETHStaticTokenBalBeforeLending = IERC20(
            WETH_STATIC_A_TOKEN
        ).balanceOf(address(pool));

        ShieldedTransaction memory ztxLend = _loadShieldedTransaction(
            "lend_1_aave_weth_through_bundler"
        );
        pool.transact(ztxLend, false);

        // Asserts
        uint256 poolwETHStaticTokenBalAfterLending = IERC20(WETH_STATIC_A_TOKEN)
            .balanceOf(address(pool));
        console.log(
            "Pool static aToken bal before lending:",
            poolwETHStaticTokenBalBeforeLending
        );
        console.log(
            "Pool static aToken bal after lending:",
            poolwETHStaticTokenBalAfterLending
        );
        assert(
            poolwETHStaticTokenBalAfterLending >
                poolwETHStaticTokenBalBeforeLending
        );

        uint24 feeAssetId = uint24(ztxLend.feeData >> 72);
        uint72 feeValue = uint72(ztxLend.feeData);
        address paymaster = address(bytes20(bytes32(ztxLend.feeData)));
        uint256 paymasterFee = pool.getCollectedPaymasterFee(
            feeAssetId,
            paymaster
        );
        assertEq(paymasterFee, feeValue);
        assertEq(IERC20(USDC).balanceOf(address(pool)), INITIAL_SUPPLY_USDC);
    }

    /// @dev This test bypasses the Labyrinth protocol and directly tests the Aave integration from the Aave adaptor.
    /// @dev Pls uncomment the `receive()` on the Aave adp to enable this test.
    function testWEthLendingAndUnLendingOnAaveBypassingLabyrinth() public {
        uint256 initialDeposit = 10 ether;
        vm.deal(address(aaveAdaptor), initialDeposit);
        vm.prank(address(aaveAdaptor));
        IWToken(WETH_AAVE_UNDERLYING).deposit{value: initialDeposit}();

        uint24[] memory inAssetIds = new uint24[](1);
        uint256[] memory inValues = new uint256[](1);
        bytes memory payload = abi.encode(uint8(0)); // supply action

        inAssetIds[0] = pool.getAsset(WETH_AAVE_UNDERLYING).id;
        inValues[0] = initialDeposit;

        uint256 adaptorwETHStaticTokenBalBeforeLending = IERC20(
            WETH_STATIC_A_TOKEN
        ).balanceOf(address(aaveAdaptor));

        IAdaptor(address(aaveAdaptor)).handleAssets(
            inAssetIds,
            inValues,
            payload
        ); // lending directly through Aave Adaptor

        uint256 adaptorwETHStaticTokenBalAfterLending = IERC20(
            WETH_STATIC_A_TOKEN
        ).balanceOf(address(aaveAdaptor));

        assert(
            adaptorwETHStaticTokenBalAfterLending >
                adaptorwETHStaticTokenBalBeforeLending
        );

        console.log("Initiating Unlending on Aave");

        inAssetIds[0] = pool.getAsset(WETH_STATIC_A_TOKEN).id;
        inValues[0] = adaptorwETHStaticTokenBalAfterLending;
        payload = abi.encode(uint8(1)); // withdraw action

        IAdaptor(address(aaveAdaptor)).handleAssets(
            inAssetIds,
            inValues,
            payload
        ); // unlending directly through Aave adp

        // Asserts
        uint256 adaptorwETHStaticBalAfterUnlending = IERC20(WETH_STATIC_A_TOKEN)
            .balanceOf(address(pool));
        uint256 adpWETHBalAfterUnLending = IWToken(WETH_AAVE_UNDERLYING)
            .balanceOf(address(aaveAdaptor));

        assertEq(adaptorwETHStaticBalAfterUnlending, 0);
        assert(adpWETHBalAfterUnLending > 0);
    }

    /// @dev Only allowing Lido tests to run on Holesky testnet and ETH mainnet. More chains can be added.
    function shouldTestRun() internal view returns (bool) {
        if (block.chainid != 11155111 && block.chainid != 1) {
            console.log(
                "Skipping Aave adaptor tests on the current chain as Aave protocol may not be deployed. To run Aave tests, kindly run the tests on the ETH Sepolia testnet where Aave is deployed. Ref: https://github.com/bgd-labs/aave-address-book/blob/main/src/AaveV3Sepolia.sol"
            );
            return false;
        }
        return true;
    }
}
