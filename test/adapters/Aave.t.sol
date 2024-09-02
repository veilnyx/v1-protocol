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
    address aave;
    address public WETH;
    address public constant WETH_AAVE_UNDERLYING =
        0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c; // Laby pool WETH contract is diff. than the one supported by Aave.

    uint256 public constant INITIAL_SUPPLY = 2 ether;
    address public user = 0x689EcF264657302052c3dfBD631e4c20d3ED0baB;
    address public constant STATIC_A_TOKEN_FACTORY =
        0xd210dFB43B694430B8d31762B5199e30c31266C8;
    address public constant WETH_STATIC_A_TOKEN = 0x162B500569F42D9eCe937e6a61EDfef660A12E98;

    function setUp() external {
        require(shouldTestRun(), "LidoAdaptorTest: Chain not supported");
        PoolTest._setUp();
        WETH = _config.wToken();
        if (WETH == address(0)) {
            revert CheckChainConfig();
        }

        aave = _config.aave();
        if (aave == address(0)) {
            revert CheckChainConfig();
        }

        // deploying aave adaptor
        aaveAdaptor = new AaveV3Adaptor(aave, address(pool), STATIC_A_TOKEN_FACTORY);
        /// @dev update convert req fixture with this adaptor addr as `to`
        console.log("Aave adaptor deployed:", address(aaveAdaptor));

        // Asset & Adaptor support on Labyrinth Protocol
        address poolOwner = pool.owner();
        vm.startPrank(poolOwner);
        pool.addAdaptorSupport(address(aaveAdaptor), true);

        AssetType assetType = AssetType.ERC20;
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = WETH_AAVE_UNDERLYING;
        assetAddresses[1] = WETH_STATIC_A_TOKEN;
        pool.addAssets(assetType, assetAddresses);
        vm.stopPrank();

        vm.deal(user, INITIAL_SUPPLY);
        vm.startPrank(user);
        IWToken(WETH_AAVE_UNDERLYING).deposit{value: INITIAL_SUPPLY}(); // wrapping eth to weth
        IWToken(WETH_AAVE_UNDERLYING).approve(address(pool), INITIAL_SUPPLY); // depositing weth to pool
        ShieldedTransaction memory ztxWethDeposit = _loadShieldedTransaction(
            "deposit_2_aave_weth_underlying"
        );
        pool.transact(ztxWethDeposit);
        vm.stopPrank();
        _processCommitmentTreeQueue();
    }

    function testAaveAdaptorDeploy() external view {
        assert(address(aaveAdaptor) != address(0));
    }

    /// @dev Make sure the `LidoAdaptor::receive()` is commented out for this test to work.
    function testWethLendingOnAave() public {
        console.log("Initiating staking on aave");
        uint256 poolwETHStaticTokenBalBeforeLending = IERC20(
            WETH_STATIC_A_TOKEN
        ).balanceOf(address(pool));

        ShieldedTransaction memory ztxLend = _loadShieldedTransaction(
            "lend_1_aave_weth"
        );
        pool.transact(ztxLend);

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
        uint256 adaptorwETHStaticBalAfterUnlending = IERC20(
            WETH_STATIC_A_TOKEN
        ).balanceOf(address(pool));
        uint256 adpWETHBalAfterUnLending = IWToken(WETH_AAVE_UNDERLYING).balanceOf(address(aaveAdaptor));

        assertEq(adaptorwETHStaticBalAfterUnlending, 0);
        assert(adpWETHBalAfterUnLending > 0);
    }

    /// @dev Only allowing Lido tests to run on Holesky testnet and ETH mainnet. More chains can be added.
    function shouldTestRun() internal view returns (bool) {
        if (block.chainid != 11155111) {
            console.log(
                "Skipping Aave adaptor tests on the current chain as Aave protocol may not be deployed. To run Aave tests, kindly run the tests on the ETH Sepolia testnet where Aave is deployed. Ref: https://github.com/bgd-labs/aave-address-book/blob/main/src/AaveV3Sepolia.sol"
            );
            return false;
        }
        return true;
    }
}
