// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma abicoder v2;

import {BaseScript} from "script/BaseScript.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {Pool} from "src/core/Pool.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransaction.sol";
import {OneInchAdaptor} from "src/adaptors/oneInch-v6/OneInchAdaptor.sol";
import {SwapDescription} from "src/adaptors/oneInch-v6/IOneInch.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {console} from "forge-std/Test.sol";

contract OneInchAdaptorTest is PoolTest {
    error CheckChainConfig();

    OneInchAdaptor oneInchAdaptor;
    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    IWToken public iWETH;
    uint256 public constant INITIAL_SUPPLY = 2 ether;
    uint256 public constant SWAP_AMT = 1 ether;
    address public user = 0x689EcF264657302052c3dfBD631e4c20d3ED0baB;

    function setUp() external {
        require(shouldTestRun(), "UniswapV3AdaptorTest: Chain not supported");
        _setUp();

        iWETH = IWToken(WETH);

        // deploying Uniswap adaptor
        oneInchAdaptor = new OneInchAdaptor(address(pool));

        /// @dev update convert req fixture with this adaptor addr as `to`
        console.log("OneInch adaptor deployed:", address(oneInchAdaptor));

        address poolOwner = pool.owner();
        vm.prank(poolOwner);
        pool.addAdaptorSupport(address(oneInchAdaptor), true);
        deal(WETH, user, INITIAL_SUPPLY * 2);
        vm.startPrank(user);
        // iWETH.approve(address(pool), INITIAL_SUPPLY); // depositing weth to pool
        // ShieldedTransaction memory stxWethDeposit = _loadShieldedTransaction(
        //     "deposit_2_testnet_weth"
        // );
        // pool.transact(stxWethDeposit);
        // vm.stopPrank();

        // _processCommitmentTreeQueue();
    }

    function test1InchAdaptorDeploy() external view {
        assert(address(oneInchAdaptor) != address(0));
    }

    function test1InchAdpDirectlyWithReturnAmt() public {
        // swap amount is 1 ether
        bytes
            memory oneInchCalldata = hex"83800a8e000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000000000000000000000000000000de0b6b3a7640000000000000000000000000000000000000000000000000000000000004d47696e08000000000000003b6d0340b4e16d0168e52d35cacd2c6185b44281ec28c9dc06d4e6c5";

        bytes memory payload = abi.encode(USDC, oneInchCalldata);

        uint24[] memory inAssetIds = new uint24[](1);
        inAssetIds[0] = pool.getAsset(WETH).id;
        uint256[] memory inValues = new uint256[](1);
        inValues[0] = SWAP_AMT;

        vm.startPrank(user);
        // sending weth in excess. INITIAL_SUPPLY > SWAP_AMT (inValues[0]). Expecting a return amount (INITIAL_SUPPLY - SWAP_AMT).
        iWETH.transfer(address(oneInchAdaptor), INITIAL_SUPPLY);

        (
            uint24[] memory outAssetIds,
            uint256[] memory outAssetValues
        ) = oneInchAdaptor.handleAssets(inAssetIds, inValues, payload);
        vm.stopPrank();

        // Asserts
        assert(outAssetIds.length == 2);
        assert(outAssetValues.length == 2);
        assert(outAssetValues[0] == (INITIAL_SUPPLY - SWAP_AMT));
        assert(outAssetValues[1] > 0);
        assert(IERC20(USDC).balanceOf(address(oneInchAdaptor)) > 0);
        assert(
            IERC20(WETH).balanceOf(address(oneInchAdaptor)) ==
                (INITIAL_SUPPLY - SWAP_AMT)
        );
    }

    function test1InchAdpDirectlyWithoutReturnAmt() public {
        // swap amount is 1 ether
        bytes
            memory oneInchCalldata = hex"83800a8e000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000000000000000000000000000000de0b6b3a7640000000000000000000000000000000000000000000000000000000000004d47696e08000000000000003b6d0340b4e16d0168e52d35cacd2c6185b44281ec28c9dc06d4e6c5";

        bytes memory payload = abi.encode(USDC, oneInchCalldata);

        uint24[] memory inAssetIds = new uint24[](1);
        inAssetIds[0] = pool.getAsset(WETH).id;
        uint256[] memory inValues = new uint256[](1);
        inValues[0] = SWAP_AMT;

        vm.startPrank(user);
        // no excess input token being deposited. Hence no return amount expected.
        iWETH.transfer(address(oneInchAdaptor), SWAP_AMT);
        (
            uint24[] memory outAssetIds,
            uint256[] memory outAssetValues
        ) = oneInchAdaptor.handleAssets(inAssetIds, inValues, payload);
        vm.stopPrank();

        // Asserts
        assert(outAssetIds.length == 1);
        assert(outAssetValues.length == 1);
        assert(outAssetValues[0] > 0);
        assert(IERC20(USDC).balanceOf(address(oneInchAdaptor)) > 0);
        assert(IERC20(WETH).balanceOf(address(oneInchAdaptor)) == 0);
    }

    /// @dev Only allowing uniswap tests to run on Seplia testnet and ETH mainnet. More chains can be added.
    function shouldTestRun() internal view returns (bool) {
        if (block.chainid != 7800 && block.chainid != 1) {
            console.log(
                "Skipping 1Inch adaptor tests on the current chain as 1Inch protocol may not be deployed. To run 1Inch tests, kindly run the tests on one of the chain forks where 1Inch is deployed."
            );
            return false;
        }
        return true;
    }
}
