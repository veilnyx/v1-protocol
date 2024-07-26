// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma abicoder v2;

import {BaseScript} from "script/BaseScript.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {Pool} from "src/core/Pool.sol";
import {ZTransaction} from "src/libraries/ZTransaction.sol";
import {LidoAdaptor} from "src/adaptors/lido/lidoAdaptor.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {console} from "forge-std/console.sol";

contract UniswapV3AdaptorTest is PoolTest, BaseScript {
    error CheckChainConfig();

    LidoAdaptor lidoAdaptor;
    address lido;
    address public stETH;
    address public wstETH;
    address public WETH;
    IWToken public iWETH;
    uint256 public constant INITIAL_SUPPLY = 1 ether;
    uint256 public constant SWAP_AMT = 1 ether;
    address public user = 0x689EcF264657302052c3dfBD631e4c20d3ED0baB;

    function setUp() external {
        require(shouldTestRun(), "LidoAdaptorTest: Chain not supported");
        _initFixture();

        WETH = _config.wToken();
        if (WETH == address(0)) {
            revert CheckChainConfig();
        }
        iWETH = IWToken(WETH);
        
        stETH = _config.initAssetAddresses()[1];
        wstETH = _config.initAssetAddresses()[2];
        lido = _config.lido();
        if (lido == address(0)) {
            revert CheckChainConfig();
        }

        // deploying Uniswap adaptor
        lidoAdaptor = new LidoAdaptor(lido, WETH, stETH, wstETH, address(pool));
        /// @dev update convert req fixture with this adaptor addr as `to`
        console.log("Lido adaptor deployed:", address(lidoAdaptor));

        // Asset & Adaptor support on Labyrinth Protocol
        address poolOwner = pool.owner();
        vm.startPrank(poolOwner);
        pool.addAdaptorSupport(address(lidoAdaptor), true);

        AssetType assetType = AssetType.ERC20;
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = WETH;
        assetAddresses[1] = wstETH;
        pool.addAssets(assetType, assetAddresses);
        vm.stopPrank();

        vm.deal(user, INITIAL_SUPPLY);
        vm.startPrank(user);
        iWETH.deposit{value: INITIAL_SUPPLY}(); // wrapping eth to weth
        iWETH.approve(address(pool), INITIAL_SUPPLY); // depositing weth to pool
        ZTransaction memory ztxWethDeposit = _loadZTx(
            "deposit_1_original_weth"
        );
        pool.transact(ztxWethDeposit);
        vm.stopPrank();
    }

    function testLidoAdaptorDeploy() external view {
        assert(address(lidoAdaptor) != address(0));
    }

     function testWethStakingOnLido() public {
        console.log("Initiating staking on Lido");
        uint256 poolwstETHBalBeforeStaking = IERC20(wstETH).balanceOf(
            address(pool)
        );

        ZTransaction memory ztxStake = _loadZTx(
            "stake_1_orig_weth_on_lido"
        );
        pool.transact(ztxStake);

        // Asserts
        uint256 poolwstETHBalPostStake = IERC20(wstETH).balanceOf(address(pool));
        console.log("Pool wstEth bal before swap:", poolwstETHBalBeforeStaking);
        console.log("Pool wstEth bal after swap:", poolwstETHBalPostStake);
        assert(poolwstETHBalPostStake > poolwstETHBalBeforeStaking);
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
