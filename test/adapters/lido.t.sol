// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma abicoder v2;

import {PoolTest} from "test/fixtures/PoolTest.sol";
import {Pool} from "src/core/Pool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransaction.sol";
import {LidoAdaptor} from "src/adaptors/lido/LidoAdaptor.sol";
import {ILido} from "src/adaptors/lido/ILido.sol";
import {IAdaptor} from "src/interfaces/IAdaptor.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {console} from "forge-std/console.sol";

enum Action {
    STAKE,
    UNSTAKE
}

contract LidoAdaptorTest is PoolTest {
    error CheckChainConfig();

    LidoAdaptor lidoAdaptor;
    address lido = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address withdrawalQueueERC721 = 0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1;
    address public stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IWToken public iWETH;
    uint256 public constant INITIAL_SUPPLY = 2 ether;
    address public user = 0x689EcF264657302052c3dfBD631e4c20d3ED0baB;

    function setUp() external {
        require(shouldTestRun(), "LidoAdaptorTest: Chain not supported");
        _setUp();

        iWETH = IWToken(WETH);

        // deploying Uniswap adaptor
        lidoAdaptor = new LidoAdaptor(
            lido,
            WETH,
            stETH,
            wstETH,
            withdrawalQueueERC721,
            address(pool)
        );
        /// @dev update convert req fixture with this adaptor addr as `to`
        console.log("Lido adaptor deployed:", address(lidoAdaptor));

        // Asset & Adaptor support on Veilnyx Protocol
        address poolOwner = pool.owner();
        vm.prank(poolOwner);
        pool.addAdaptorSupport(address(lidoAdaptor), true);

        AssetType assetType = AssetType.ERC20;
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = wstETH;

        uint8[] memory assetsPrecision = new uint8[](1);
        assetsPrecision[0] = 18;
        pool.addAssets(assetType, assetAddresses, assetsPrecision);

        deal(WETH, user, INITIAL_SUPPLY);

        // vm.startPrank(user);
        // iWETH.approve(address(pool), INITIAL_SUPPLY); // depositing weth to pool
        // ShieldedTransaction memory stxWethDeposit = _loadShieldedTransaction(
        //     "deposit_2_testnet_weth"
        // );
        // pool.transact(stxWethDeposit);
        // vm.stopPrank();

        // _processCommitmentTreeQueue();
    }

    function testLidoAdaptorDeploy() external view {
        assert(address(lidoAdaptor) != address(0));
    }

    /// @dev Make sure the `LidoAdaptor::receive()` is commented out for this test to work.
    function testWethStakingOnLido() public {
        console.log("Initiating staking on Lido");
        uint256 poolwstETHBalBeforeStaking = IERC20(wstETH).balanceOf(
            address(pool)
        );

        ShieldedTransaction memory stxStake = _loadShieldedTransaction(
            "stake_1_testnet_weth"
        );
        pool.transact(stxStake, false);

        // Asserts
        uint256 poolwstETHBalPostStake = IERC20(wstETH).balanceOf(
            address(pool)
        );
        console.log("Pool wstEth bal before swap:", poolwstETHBalBeforeStaking);
        console.log("Pool wstEth bal after swap:", poolwstETHBalPostStake);
        assert(poolwstETHBalPostStake > poolwstETHBalBeforeStaking);
    }

    /// @dev This test bypasses the Veilnyx protocol and directly tests the Lido integration from the LidoAdaptor.
    /// @dev Pls uncomment the `receive()` on the LidoAdaptor to enable this test.
    /// @dev Will only run on Holesky testnet.
    function testWstEthUnStakingOnLidoBypassingVeilnyx() public {
        deal(address(lidoAdaptor), INITIAL_SUPPLY);
        vm.prank(address(lidoAdaptor));
        IWToken(WETH).deposit{value: INITIAL_SUPPLY}();

        uint24[] memory inAssetIds = new uint24[](1);
        uint256[] memory inValues = new uint256[](1);
        bytes memory payload = abi.encode(Action.STAKE, address(0));

        inAssetIds[0] = pool.getAsset(WETH).id;
        inValues[0] = INITIAL_SUPPLY;

        IAdaptor(address(lidoAdaptor)).handleAssets(
            inAssetIds,
            inValues,
            payload
        ); // staking directly through LidoAdaptor

        uint256 adpWstETHBalBeforeUnStaking = IERC20(wstETH).balanceOf(
            address(lidoAdaptor)
        );
        console.log("Adp wstEth bal after swap:", adpWstETHBalBeforeUnStaking);
        assert(adpWstETHBalBeforeUnStaking > 0);

        console.log("Initiating Unstaking on Lido");

        inAssetIds[0] = pool.getAsset(wstETH).id;
        inValues[0] = adpWstETHBalBeforeUnStaking;
        payload = abi.encode(Action.UNSTAKE, user);

        IAdaptor(address(lidoAdaptor)).handleAssets(
            inAssetIds,
            inValues,
            payload
        ); // unstaking directly through LidoAdp

        // Asserts
        uint256 adpWstETHBalPostUnStake = IERC20(wstETH).balanceOf(
            address(pool)
        );
        console.log(
            "Adp wstEth bal before unstaking:",
            adpWstETHBalBeforeUnStaking
        );
        console.log("Adp wstEth bal after unstaking:", adpWstETHBalPostUnStake);

        assert(adpWstETHBalPostUnStake < adpWstETHBalBeforeUnStaking);
        assert(IERC721(withdrawalQueueERC721).balanceOf(user) > 0); // NFT received check
    }

    function testRevertOnSepoliaWhenWithdrawing() external {
        uint24[] memory inAssetIds = new uint24[](1);
        uint256[] memory inValues = new uint256[](1);

        inAssetIds[0] = pool.getAsset(wstETH).id;
        inValues[0] = INITIAL_SUPPLY;
        bytes memory payload = abi.encode(Action.UNSTAKE, user);
        deal(wstETH, address(lidoAdaptor), INITIAL_SUPPLY);

        if (block.chainid == 11155111) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    ILido.LidoWithdrawNotSupportedOnChain.selector,
                    11155111
                )
            );
        }
        // Unstaking call
        IAdaptor(address(lidoAdaptor)).handleAssets(
            inAssetIds,
            inValues,
            payload
        );
    }

    /// @dev Only allowing Lido tests to run on Holesky testnet and ETH mainnet. More chains can be added.
    function shouldTestRun() internal view returns (bool) {
        if (
            block.chainid != 17000 &&
            block.chainid != 11155111 &&
            block.chainid != 1
        ) {
            console.log(
                "Skipping Lido adaptor tests on the current chain as Lido protocol may not be deployed. To run Lido tests, kindly run the tests on the Holesky testnet where Lido is deployed. Ref: https://docs.lido.fi/deployed-contracts/holesky"
            );
            return false;
        }
        return true;
    }
}
