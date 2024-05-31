// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma abicoder v2;

import {BaseAdapterTest} from "test/adapters/BaseAdapterTest.sol";
import {Pool} from "src/core/Pool.sol";
import {ZTransaction} from "src/libraries/ZTransaction.sol";
import {ISwapRouter02} from "src/adaptors/uniswap-v3/ISwapRouter02.sol";
import {UniswapV3Adapter} from "src/adaptors/uniswap-v3/UniswapV3Adapter.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Asset} from "src/libraries/Asset.sol";
import {console} from "forge-std/console.sol";

contract UniswapV3AdaptorTest is BaseAdapterTest {
    address public constant WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    address public constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    IWToken public constant iWETH = IWToken(WETH);
    uint256 public constant INITIAL_SUPPLY = 1 ether;
    uint256 public constant SWAP_AMT = 0.01 ether;
    address public user = makeAddr("user");
    UniswapV3Adapter uniswapV3Adapter;

    function setUp() external {
        _runBaseTest();
        uniswapV3Adapter = new UniswapV3Adapter(
            uniswapSwapRouter02,
            address(pool)
        );

        console.log("Uni adaptor:", address(uniswapV3Adapter));

        // TODO: Use a cheat code for Uni adp. address for consistency
        address poolOwner = pool.owner();
        vm.prank(poolOwner);
        pool.setConvertProxy(address(uniswapV3Adapter), true);

        vm.deal(user, INITIAL_SUPPLY * 2);
        vm.startPrank(user);
        iWETH.deposit{value: INITIAL_SUPPLY}();
        iWETH.approve(address(pool), INITIAL_SUPPLY);
        
        ZTransaction memory ztxDeposit = _loadZTx("deposit_1_weth");
        pool.transact(ztxDeposit);
        vm.stopPrank();
    }

    function testUniswapZkFiAdaptorDeploy() external view {
        assert(address(uniswapV3Adapter) != address(0));
    }

    function testSwapToPool() external /* zkFiSetup */ {
        console.log("Initiating swap to USDC using Uniswap test");
        uint256 poolUSDCBalBeforeConvert = IERC20(USDC).balanceOf(
            address(pool)
        );

        ZTransaction memory ztxDeposit = _loadZTx("swap_1e16_weth_to_usdc");
        pool.transact(ztxDeposit);

        // Asserts
        uint256 poolUSDCBalPostConvert = IERC20(USDC).balanceOf(address(pool));
        console.log("Pool USDC bal before swap:", poolUSDCBalBeforeConvert);
        console.log("Pool USDC bal after swap:", poolUSDCBalPostConvert);
        assert(poolUSDCBalPostConvert > poolUSDCBalBeforeConvert);
    }

    // function testSwapToNonPoolAddr() external /* zkFiSetup */ {
    //     console.log("Initiating swap to USDC using Uniswap test");
    //     uint256 userUSDCBalBeforeConvert = IERC20(USDC).balanceOf(user);

    //     ZTransaction memory ztxDeposit = _loadZTx(
    //         "swap_1e16_weth_to_usdc"
    //     );
    //     pool.transact(ztxDeposit);

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
