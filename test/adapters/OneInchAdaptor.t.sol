// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
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

        // deploying 1Inch adaptor
        oneInchAdaptor = new OneInchAdaptor(address(pool));

        /// @dev update convert req fixture with this adaptor addr as `to`
        console.log("OneInch adaptor deployed:", address(oneInchAdaptor));

        address poolOwner = pool.owner();
        vm.prank(poolOwner);
        pool.addAdaptorSupport(address(oneInchAdaptor), true);
        deal(WETH, user, INITIAL_SUPPLY);

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

    function test1InchAdpDirectly() public {
        // swap amount is 1 ether
        // function sign (first 4 bytes of calldata) is 0x7b8e4e42 is trimmed.
        bytes
            memory oneInchCalldata = hex"000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd09000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000397ff1542f962076d0bfe58ea045ffa2d347aca0000000000000000000000000bf71c5ae43827387daaf7358acab5c81642b74b80000000000000000000000000000000000000000000000000de0b6b3a7640000000000000000000000000000000000000000000000000000000000007b4070cc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000009f00000000000000000000000000000000000000000000000000008100001a0020d6bdbf78c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200206ae4071138002dc6c0397ff1542f962076d0bfe58ea045ffa2d347aca0111111125421ca6dc452d289314280a0f8842a650000000000000000000000000000000000000000000000000000000000000001c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20006d4e6c5";

        uint24[] memory inAssetIds = new uint24[](1);
        inAssetIds[0] = pool.getAsset(WETH).id;
        uint256[] memory inValues = new uint256[](1);
        inValues[0] = SWAP_AMT;

        vm.startPrank(user);
        iWETH.transfer(address(oneInchAdaptor), SWAP_AMT);

        (
            uint24[] memory outAssetIds,
            uint256[] memory outAssetValues
        ) = oneInchAdaptor.handleAssets(inAssetIds, inValues, oneInchCalldata);
        vm.stopPrank();

        // Asserts
        assert(outAssetValues[0] > 0);
        assert(IERC20(USDC).balanceOf(address(oneInchAdaptor)) > 0);
        assertEq(IERC20(WETH).balanceOf(address(oneInchAdaptor)), 0);
    }

    /// @dev Only allowing 1Inch tests to run on Seplia testnet and ETH mainnet. More chains can be added.
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
