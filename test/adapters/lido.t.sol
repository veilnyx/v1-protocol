// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma abicoder v2;

import {BaseScript} from "script/BaseScript.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {Pool} from "src/core/Pool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransaction.sol";
import {LidoAdaptor} from "src/adaptors/lido/lidoAdaptor.sol";
import {IAdaptor} from "src/interfaces/IAdaptor.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {console} from "forge-std/console.sol";

contract LidoAdaptorTest is PoolTest {
    error CheckChainConfig();

    LidoAdaptor lidoAdaptor;
    address lido;
    address withdrawalQueueERC721;
    address public stETH;
    address public wstETH;
    address public WETH;
    IWToken public iWETH;
    uint256 public constant INITIAL_SUPPLY = 2 ether;
    uint256 public constant SWAP_AMT = 1 ether;
    address public user = 0x689EcF264657302052c3dfBD631e4c20d3ED0baB;

    function setUp() external {
        require(shouldTestRun(), "LidoAdaptorTest: Chain not supported");
        _setUp();

        WETH = _config.wToken();
        if (WETH == address(0)) {
            revert CheckChainConfig();
        }
        iWETH = IWToken(WETH);

        stETH = _config.initAssetAddresses()[1];
        wstETH = _config.initAssetAddresses()[2];
        lido = _config.lido();
        withdrawalQueueERC721 = _config.withdrawalQueueERC721();
        if (lido == address(0)) {
            revert CheckChainConfig();
        }

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

        // Asset & Adaptor support on Labyrinth Protocol
        address poolOwner = pool.owner();
        vm.prank(poolOwner);
        pool.addAdaptorSupport(address(lidoAdaptor), true);

        // AssetType assetType = AssetType.ERC20;
        // address[] memory assetAddresses = new address[](2);
        // assetAddresses[0] = WETH;
        // assetAddresses[1] = wstETH;
        // pool.addAssets(assetType, assetAddresses);
        // vm.stopPrank();

        vm.deal(user, INITIAL_SUPPLY * 2);
        vm.startPrank(user);
        iWETH.deposit{value: INITIAL_SUPPLY}(); // wrapping eth to weth
        iWETH.approve(address(pool), INITIAL_SUPPLY); // depositing weth to pool
        ShieldedTransaction memory stxWethDeposit = _loadShieldedTransaction(
            "deposit_2_testnet_weth"
        );
        pool.transact(stxWethDeposit);
        vm.stopPrank();

        _processCommitmentTreeQueue();
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
            "stake_1_testnet_weth_on_lido"
        );
        pool.transact(stxStake);

        // Asserts
        uint256 poolwstETHBalPostStake = IERC20(wstETH).balanceOf(
            address(pool)
        );
        console.log("Pool wstEth bal before swap:", poolwstETHBalBeforeStaking);
        console.log("Pool wstEth bal after swap:", poolwstETHBalPostStake);
        assert(poolwstETHBalPostStake > poolwstETHBalBeforeStaking);
    }

    /// @dev This test bypasses the Labyrinth protocol and directly tests the Lido integration from the LidoAdaptor.
    /// @dev Pls uncomment the `receive()` on the LidoAdaptor to enable this test.
    function testWstEthUnStakingOnLidoBypassingLabyrinth() public {
        uint256 initialDeposit = 10 ether;
        vm.deal(address(lidoAdaptor), initialDeposit);
        vm.prank(address(lidoAdaptor));
        IWToken(WETH).deposit{value: initialDeposit}();

        uint24[] memory inAssetIds = new uint24[](1);
        uint256[] memory inValues = new uint256[](1);
        bytes memory payload = bytes("");

        inAssetIds[0] = pool.getAsset(WETH).id;
        inValues[0] = initialDeposit;

        IAdaptor(address(lidoAdaptor)).handleAssets(
            inAssetIds,
            inValues,
            payload
        ); // staking directly through LidoAdaptor

        console.log("Initiating Unstaking on Lido");
        uint256 adpWstETHBalBeforeUnStaking = IERC20(wstETH).balanceOf(
            address(lidoAdaptor)
        );

        inAssetIds[0] = pool.getAsset(wstETH).id;
        inValues[0] = adpWstETHBalBeforeUnStaking;
        payload = abi.encode(user);

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

    /// @dev Only allowing Lido tests to run on Holesky testnet and ETH mainnet. More chains can be added.
    function shouldTestRun() internal view returns (bool) {
        if (block.chainid != 17000) {
            console.log(
                "Skipping Lido adaptor tests on the current chain as Lido protocol may not be deployed. To run Lido tests, kindly run the tests on the Holesky testnet where Lido is deployed. Ref: https://docs.lido.fi/deployed-contracts/holesky"
            );
            return false;
        }
        return true;
    }
}
