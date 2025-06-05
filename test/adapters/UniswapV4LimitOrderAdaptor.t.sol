// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {PoolTest} from "test/fixtures/PoolTest.sol";
import {LabyrinthLimitOrderAdaptor} from "src/adaptors/uniswap-v4/LabyrinthLimitOrderAdaptor.sol";
import {MockLabyrinthLimitOrderHook} from "../mocks/MockLabyrinthLimitOrderHook.sol";
import {ERC1155ReceiverMock} from "../mocks/ERC1155ReceiverMock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {console} from "forge-std/console.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {MockPoolManager} from "../mocks/MockPoolManager.sol";

import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

contract UniswapV4LimitOrderAdaptorTest is PoolTest, IERC1155Receiver {
    LabyrinthLimitOrderAdaptor public adaptor;
    MockLabyrinthLimitOrderHook public hook;
    MockPoolManager public mockManager;
    address public user;
    ERC1155ReceiverMock public erc1155ReceiverMock;
    uint256 public constant INITIAL_SUPPLY = 10000 ether;
    uint256 public constant ORDER_AMOUNT = 1 ether;


    function setUp() external {
        console.log("erc1155ReceiverMock", address(erc1155ReceiverMock));
        console.log("user", user);

        PoolTest._setUp();
        erc1155ReceiverMock = new ERC1155ReceiverMock();
        user = address(erc1155ReceiverMock);
        mockManager = new MockPoolManager();
        hook = new MockLabyrinthLimitOrderHook(mockManager, "");
        adaptor = new LabyrinthLimitOrderAdaptor(address(pool), address(hook));

        address poolOwner = pool.owner();
        vm.startPrank(poolOwner);
        pool.addAdaptorSupport(address(adaptor), true);
        vm.stopPrank();

        _mintAsset(asset1, user, INITIAL_SUPPLY);
        _mintAsset(asset2, user, INITIAL_SUPPLY);
        _approveAsset(asset1, address(pool), INITIAL_SUPPLY);
        _approveAsset(asset2, address(pool), INITIAL_SUPPLY);
    }

    function testPlaceAndRedeemLimitOrder() public {
        console.log("[test] user", user);
    
        PoolKey memory key = _makePoolKey();
        uint256 limitPrice = 2e18;
        bool zeroForOne = true;
        _placeOrder(key, limitPrice, zeroForOne);
        int24 tick = _calculateTick(limitPrice);
        uint256 orderId = hook.getOrderId(key, tick, zeroForOne);
        _simulateFill(orderId);
        _redeemOrder(key, limitPrice, zeroForOne);
    }

    function _makePoolKey() internal view returns (PoolKey memory) {
        return PoolKey({
            currency0: Currency.wrap(asset1.assetAddress),
            currency1: Currency.wrap(asset2.assetAddress),
            fee: 3000,
            tickSpacing: 60,
            hooks: hook
        });
    }

    function _calculateTick(uint256 limitPrice) internal view returns (int24) {
        uint8 inputDecimals = IERC20Metadata(asset1.assetAddress).decimals();
        uint8 outputDecimals = IERC20Metadata(asset2.assetAddress).decimals();
        uint256 normPrice = limitPrice * (10**outputDecimals) / (10**inputDecimals);
        uint160 sqrtPriceX96 = uint160(FixedPointMathLib.sqrt(normPrice) * (2**96));
        return TickMath.getTickAtSqrtPrice(sqrtPriceX96);
    }

    function _placeOrder(PoolKey memory key, uint256 limitPrice, bool zeroForOne) internal {
        console.log("[_placeOrder] user", user);
        require(user == address(erc1155ReceiverMock), "user must be ERC1155ReceiverMock");
        bytes memory payload = abi.encode(
            LabyrinthLimitOrderAdaptor.Action.PlaceOrder,
            asset1.assetAddress,
            asset2.assetAddress,
            limitPrice,
            ORDER_AMOUNT,
            zeroForOne,
            key,
            user
        );
        uint24[] memory inAssetIds = new uint24[](1);
        uint256[] memory inValues = new uint256[](1);
        inAssetIds[0] = asset1.id;
        inValues[0] = ORDER_AMOUNT;
        // Mint (deal) ORDER_AMOUNT of asset1 to this contract so we can fund the adaptor
        deal(asset1.assetAddress, address(this), ORDER_AMOUNT);
        IERC20(asset1.assetAddress).transfer(address(adaptor), ORDER_AMOUNT);
        vm.startPrank(user);
        adaptor.handleAssets(inAssetIds, inValues, payload);
        vm.stopPrank();
    }

    function _simulateFill(uint256 orderId) internal {
        _mintAsset(asset2, address(hook), ORDER_AMOUNT * 2);
        hook.claimableOutputTokens(orderId);
        assembly { sstore(add(orderId, hook.slot), mul(ORDER_AMOUNT, 2)) }
    }

    function _redeemOrder(PoolKey memory key, uint256 limitPrice, bool zeroForOne) internal {
        console.log("[_redeemOrder] user", user);
        int24 tick = _calculateTick(limitPrice);
        vm.startPrank(user);
        hook.redeem(key, tick, zeroForOne, ORDER_AMOUNT);
        vm.stopPrank();
    }

    function testRedeemRevertsForEOA() public {
        address eoa = address(0xdeadbeef);
        PoolKey memory key = _makePoolKey();
        uint256 limitPrice = 2e18;
        bool zeroForOne = true;
        _placeOrder(key, limitPrice, zeroForOne);
        int24 tick = _calculateTick(limitPrice);
        uint256 orderId = hook.getOrderId(key, tick, zeroForOne);
        _simulateFill(orderId);
        vm.startPrank(eoa);
        bytes memory payload = abi.encode(
            LabyrinthLimitOrderAdaptor.Action.Redeem,
            asset1.assetAddress,
            asset2.assetAddress,
            limitPrice,
            ORDER_AMOUNT,
            zeroForOne,
            key
        );
        uint24[] memory inAssetIds = new uint24[](1);
        uint256[] memory inValues = new uint256[](1);
        inAssetIds[0] = asset1.id;
        inValues[0] = ORDER_AMOUNT;
        vm.expectRevert();
        adaptor.handleAssets(inAssetIds, inValues, payload);
        vm.stopPrank();
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }
}
