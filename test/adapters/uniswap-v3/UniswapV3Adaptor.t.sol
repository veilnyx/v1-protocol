// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;
pragma abicoder v2;

import {BaseTest} from "test/fixtures/BaseTest.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {Pool} from "src/core/Pool.sol";
import {DeployUniswapZkFiAdaptor} from "script/deploy/adaptors/DeployUniswapZkFiAdaptor.s.sol";
import {ZTransaction} from "src/libraries/ZTransaction.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {UniswapZkFiAdaptor} from "src/adaptors/UniswapZkFiAdaptor.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Asset} from "src/libraries/Asset.sol";
import {console} from "forge-std/console.sol";

contract UniswapZkFiAdaptorTest is BaseTest {
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IWToken public constant iWETH = IWToken(WETH);
    IWToken public constant iUSDC = IWToken(USDC);
    uint256 public constant INITIAL_SUPPLY = 1000 ether;
    uint256 public constant SWAP_AMT = 100 ether;
    address public user = vm.envAddress("ANVIL_PUBLIC_KEY");
    UniswapZkFiAdaptor uniswapZkFiAdaptor;
    uint24[] inAssetIds;
    uint256[] inValues;
    address public poolAddr;
    address public convertorAddr;
    address public deployerAddr;
    Pool pool;

    function setUp() external {
        DeployUniswapZkFiAdaptor deployer = new DeployUniswapZkFiAdaptor();
        (uniswapZkFiAdaptor, poolAddr, convertorAddr, , deployerAddr) = deployer
            .run();

        console.log("Uni adaptor:", address(uniswapZkFiAdaptor));
        console.log("ZKFI Convertor:", convertorAddr);

        pool = Pool(poolAddr);

        // TODO: Use a cheat code for Uni adp. address for consistency
        vm.prank(deployerAddr);
        pool.setConvertProxy(address(uniswapZkFiAdaptor), true);

        vm.startPrank(user);
        iWETH.deposit{value: INITIAL_SUPPLY}();
        iWETH.approve(poolAddr, INITIAL_SUPPLY);

        ZTransaction memory ztxDeposit = _loadZTx("deposit_1000_weth");
        pool.transact(ztxDeposit);
        vm.stopPrank();
    }

    function testUniswapZkFiAdaptorDeploy() external view {
        assert(address(uniswapZkFiAdaptor) != address(0));
    }

    function testSwapToPool() external /* zkFiSetup */ {
        console.log("Initiating swap to USDC using Uniswap test");
        uint256 poolUSDCBalBeforeConvert = IERC20(USDC).balanceOf(poolAddr);

        ZTransaction memory ztxDeposit = _loadZTx(
            "swap_100_weth_to_usdc_for_pool"
        );
        pool.transact(ztxDeposit);

        // Asserts
        uint256 poolUSDCBalPostConvert = IERC20(USDC).balanceOf(poolAddr);
        console.log("Pool USDC bal before swap:", poolUSDCBalBeforeConvert);
        console.log("Pool USDC bal after swap:", poolUSDCBalPostConvert);
        assert(poolUSDCBalPostConvert > poolUSDCBalBeforeConvert);
    }

    function testSwapToNonPoolAddr() external /* zkFiSetup */ {
        console.log("Initiating swap to USDC using Uniswap test");
        uint256 userUSDCBalBeforeConvert = IERC20(USDC).balanceOf(user);

        ZTransaction memory ztxDeposit = _loadZTx(
            "swap_100_weth_to_usdc_for_user"
        );
        pool.transact(ztxDeposit);

        // Asserts
        uint256 userUSDCBalPostConvert = IERC20(USDC).balanceOf(user);
        console.log("User USDC bal before swap:", userUSDCBalBeforeConvert);
        console.log("User USDC bal after swap:", userUSDCBalPostConvert);
        assert(userUSDCBalPostConvert > userUSDCBalBeforeConvert);
    }
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
//             "setConvertProxy(address, bool)",
//             address(uniswapZkFiAdaptor),
//             true
//         )
//     );
//     require(success, "SetProxy failed");
// }

// function getAssetId(address assetAddress) public view returns (uint24) {
//     return pool.getAsset(assetAddress).id;
// }

// function setConvertProxy(address adaptor) external {
//     pool.setConvertProxy(adaptor, true);
// }

// function loadZTx(
//     string memory name
// ) external view returns (ZTransaction memory) {
//     return _loadZTx(name);
// }
