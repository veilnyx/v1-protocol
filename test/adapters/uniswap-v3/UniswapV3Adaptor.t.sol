// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma abicoder v2;

import {BaseScript} from "script/BaseScript.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {Pool} from "src/core/Pool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransaction.sol";
import {UniswapV3Adapter} from "src/adaptors/uniswap-v3/UniswapV3Adapter.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {console} from "forge-std/console.sol";

contract UniswapV3AdaptorTest is PoolTest {
    error CheckChainConfig();

    UniswapV3Adapter uniswapV3Adapter;
    address uniswapSwapRouter02;
    address public WETH;
    address public USDC;
    IWToken public iWETH;
    uint256 public constant INITIAL_SUPPLY = 1 ether;
    uint256 public constant SWAP_AMT = 1 ether;
    address public user = 0x689EcF264657302052c3dfBD631e4c20d3ED0baB;

    function setUp() external {
        require(shouldTestRun(), "UniswapV3AdaptorTest: Chain not supported");
        _setUp();

        WETH = _config.initAssetAddresses()[0];
        if (WETH == address(0)) {
            revert CheckChainConfig();
        }
        USDC = _config.initAssetAddresses()[1];
        if (USDC == address(0)) {
            revert CheckChainConfig();
        }

        uniswapSwapRouter02 = _config.uniswapSwapRouter02();
        if (uniswapSwapRouter02 == address(0)) {
            revert CheckChainConfig();
        }

        iWETH = IWToken(WETH);

        // deploying Uniswap adaptor
        uniswapV3Adapter = new UniswapV3Adapter(
            uniswapSwapRouter02,
            address(pool)
        );
        /// @dev update convert req fixture with this adaptor addr as `to`
        console.log("Uniswap adaptor:", address(uniswapV3Adapter));

        // TODO: Use a cheat code for Uni adp. address for consistency
        address poolOwner = pool.owner();
        vm.prank(poolOwner);
        pool.addAdaptorSupport(address(uniswapV3Adapter), true);

        vm.deal(user, INITIAL_SUPPLY * 2);
        vm.startPrank(user);
        iWETH.deposit{value: INITIAL_SUPPLY}(); // wrapping eth to weth
        iWETH.approve(address(pool), INITIAL_SUPPLY); // depositing weth to pool
        ShieldedTransaction memory stxWethDeposit = _loadShieldedTransaction(
            "deposit_1_testnet_weth"
        );
        pool.transact(stxWethDeposit);
        vm.stopPrank();

        _processCommitmentTreeQueue();
    }

    function testUniswapZkFiAdaptorDeploy() external view {
        assert(address(uniswapV3Adapter) != address(0));
    }

    function testWethToUSDCSwapToPool() public /* zkFiSetup */ {
        console.log("Initiating WETH<>USDC swap");
        uint256 poolUSDCBalBeforeConvert = IERC20(USDC).balanceOf(
            address(pool)
        );

        ShieldedTransaction memory stxSwap = _loadShieldedTransaction(
            "swap_1_testnet_weth_to_usdc"
        );
        pool.transact(stxSwap);

        // Asserts
        uint256 poolUSDCBalPostConvert = IERC20(USDC).balanceOf(address(pool));
        console.log("Pool USDC bal before swap:", poolUSDCBalBeforeConvert);
        console.log("Pool USDC bal after swap:", poolUSDCBalPostConvert);
        assert(poolUSDCBalPostConvert > poolUSDCBalBeforeConvert);
    }

    function testSwapViaBundler() public {
        console.log("Initiating WETH<>USDC swap");
        uint256 poolUSDCBalBeforeConvert = IERC20(USDC).balanceOf(
            address(pool)
        );

        ShieldedTransaction memory stxDeposit = _loadShieldedTransaction(
            "swap_1e16_orig_weth_to_usdc_via_bundler"
        );
        pool.transact(stxDeposit);

        // Asserts
        uint256 poolUSDCBalPostConvert = IERC20(USDC).balanceOf(address(pool));
        console.log("Pool USDC bal before swap:", poolUSDCBalBeforeConvert);
        console.log("Pool USDC bal after swap:", poolUSDCBalPostConvert);
        assert(poolUSDCBalPostConvert > poolUSDCBalBeforeConvert);
    }

    /// @dev Only allowing uniswap tests to run on Seplia testnet and ETH mainnet. More chains can be added.
    function shouldTestRun() internal view returns (bool) {
        if (block.chainid != 11155111 && block.chainid != 1) {
            console.log(
                "Skipping Uniswap adaptor tests on the current chain as UniswapV3 protocol may not be deployed. To run Uniswap tests, kindly run the tests on one of the chain forks where UniswapV3 is deployed. Ref: https://docs.uniswap.org/contracts/v3/reference/deployments/"
            );
            return false;
        }
        return true;
    }

    // function testWethToUSDCToWETHSwapToPool() external /* zkFiSetup */ {
    //     testWethToUSDCSwapToPool();
    //     console.log("Initiating USDC<>WETH");
    //     uint256 poolWETHBalBeforeConvert = IERC20(WETH).balanceOf(
    //         address(pool)
    //     );

    //     ShieldedTransaction memory stxDeposit =  _loadShieldedTransaction("swap_5_usdc_to_weth");
    //     pool.transact(stxDeposit);

    //     // Asserts
    //     uint256 poolWETHBalPostConvert = IERC20(WETH).balanceOf(address(pool));
    //     console.log("Pool WETH bal before swap:", poolWETHBalBeforeConvert);
    //     console.log("Pool WETH bal after swap:", poolWETHBalPostConvert);
    //     assert(poolWETHBalPostConvert > poolWETHBalBeforeConvert);
    // }

    // function testSwapToNonPoolAddr() external /* zkFiSetup */ {
    //     console.log("Initiating swap to USDC using Uniswap test");
    //     uint256 userUSDCBalBeforeConvert = IERC20(USDC).balanceOf(user);

    //     ShieldedTransaction memory stxDeposit =  _loadShieldedTransaction(
    //         "swap_1e16_orig_weth_to_usdc"
    //     );
    //     pool.transact(stxDeposit);

    //     // Asserts
    //     uint256 userUSDCBalPostConvert = IERC20(USDC).balanceOf(user);
    //     console.log("User USDC bal before swap:", userUSDCBalBeforeConvert);
    //     console.log("User USDC bal after swap:", userUSDCBalPostConvert);
    //     assert(userUSDCBalPostConvert > userUSDCBalBeforeConvert);
    // }
}

// function testSlippageProtection() external {
//     uint256 minOutExpectedByUser = 6000e18; // only 5791e18 USDC will be received in return of SWAP_AMT wETH. Hence keeping minOutExpectedByUser > 5791e18

//     vm.startPrank(user);
//     IWToken.approve(address(uniswapZkFiAdaptor), SWAP_AMT);
//     vm.expectRevert("Too little received");
//     uniswapZkFiAdaptor.swapExactInputSingle({
//         tokenIn: WETH9,
//         tokenInAmt: SWAP_AMT,
//         tokenOut: USDC,
//         minOut: minOutExpectedByUser,
//         receipient: user,
//         deadlineFromNow: 30
//     });
//     vm.stopPrank();
// }

// function getAssetId(address assetAddress) internal returns (uint24) {
//     (bool success, bytes memory res) = zkFiPoolProxy.call(
//         abi.encodeWithSignature("getAsset(address)", assetAddress)
//     );

//     require(success, "PoolFixture:: Error getting asset Id");
//     Asset memory returnedAsset = abi.decode(res, (Asset));
//     return returnedAsset.id;
// }

// function testSetProxy() external {
//     vm.prank(user); // corresponds to `deployerKey`/owner of proxy
//     (, bytes memory res) = zkFiPoolProxy.call(
//         abi.encodeWithSignature("owner()")
//     );
//     address proxyOwner = abi.decode(res, (address));
//     console.log("Pool owner:", proxyOwner);

//     assertEq(proxyOwner, user);

//     vm.prank(proxyOwner);
//     (bool success, ) = zkFiPoolProxy.call(
//         abi.encodeWithSignature(
//             "addAdaptorSupport(address, bool)",
//             address(uniswapZkFiAdaptor),
//             true
//         )
//     );
//     require(success, "SetProxy failed");
// }

// function getAssetId(address assetAddress) public view returns (uint24) {
//     return pool.getAsset(assetAddress).id;
// }

// function addAdaptorSupport(address adaptor) external {
//     pool.addAdaptorSupport(adaptor, true);
// }

// function loadStx(
//     string memory name
// ) external view returns (ShieldedTransaction memory) {
//     return  _loadShieldedTransaction(name);
// }
