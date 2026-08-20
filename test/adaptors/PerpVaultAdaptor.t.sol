// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from
    "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {PerpVault} from "src/adaptors/hyperliquid/PerpVault.sol";
import {PerpVaultAdaptor} from "src/adaptors/hyperliquid/PerpVaultAdaptor.sol";
import {HyperCore} from "src/adaptors/hyperliquid/IHyperCore.sol";
import {AdaptorHandler} from "src/core/AdaptorHandler.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {PubAsset} from "src/libraries/ShieldedTransactionLogic.sol";
import {Asset, AssetType} from "src/libraries/AssetLogic.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockCoreWriter} from "test/mocks/MockHyperCorePrecompiles.sol";

/// @notice Minimal Pool stand-in: an asset registry plus the ability to invoke the
///         handler the way ShieldedTransactionLogic does.
/// @dev The real Pool reaches the adaptor only via a CALL_ADAPTOR shielded
///      transaction, which needs fixture ZK proofs against regenerated circuits.
///      That path is worth testing separately; it is not what breaks first. What
///      breaks first is the delegatecall boundary, asset-id resolution, approvals
///      and the handler's post-call balance check — none of which involve proofs.
contract PoolStub {
    mapping(uint24 => Asset) internal _byId;
    mapping(address => Asset) internal _byAddr;

    function register(uint24 id, address token, uint8 precision) external {
        Asset memory a = Asset({
            id: id,
            assetType: AssetType.ERC20,
            assetAddress: token,
            isActive: true,
            precision: precision,
            usdPriceFeed: AggregatorV3Interface(address(0)),
            feedDecimals: 0
        });
        _byId[id] = a;
        _byAddr[token] = a;
    }

    function getAsset(uint24 id) external view returns (Asset memory) {
        return _byId[id];
    }

    function getAsset(address token) external view returns (Asset memory) {
        return _byAddr[token];
    }

    /// @dev Mirrors _handleAdaptorCall: move the input asset to the handler, invoke
    ///      it, then pull whatever comes back.
    function callAdaptor(
        AdaptorHandler handler,
        address adaptor,
        PubAsset[] memory pubAssets,
        bytes memory payload
    ) external returns (PubAsset[] memory out) {
        for (uint256 i = 0; i < pubAssets.length; i++) {
            IERC20(_byId[pubAssets[i].id].assetAddress).transfer(
                address(handler), pubAssets[i].value
            );
        }
        out = handler.handleAdaptor(adaptor, pubAssets, payload);
        for (uint256 i = 0; i < out.length; i++) {
            IERC20(_byId[out[i].id].assetAddress).transferFrom(
                address(handler), address(this), out[i].value
            );
        }
    }
}

contract PerpVaultAdaptorTest is Test {
    uint24 constant USDC_ID = 0x010001;
    uint24 constant SHARE_ID = 0x010002;
    uint24 constant CLAIM_ID = 0x010003;
    uint32 constant PERP = 3;
    uint64 constant TOKEN_INDEX = 0;

    PoolStub pool;
    AdaptorHandler handler;
    PerpVault vault;
    PerpVaultAdaptor adaptor;
    MockERC20 usdc;

    uint256 internal coreEquity6;
    uint64 internal px = 1_000_000;

    function setUp() public {
        usdc = new MockERC20(address(this), 6);
        pool = new PoolStub();

        handler = new AdaptorHandler();
        handler.setVeilnyxPool(IPool(address(pool)));

        vault = new PerpVault(
            IERC20(address(usdc)), TOKEN_INDEX, PERP, true, 20_000, "BTC Long 2x", "vBTC2L",
            address(this)
        );
        vault.setEntryFeeBps(0);
        adaptor = new PerpVaultAdaptor(IPool(address(pool)));

        pool.register(USDC_ID, address(usdc), 6);
        pool.register(SHARE_ID, address(vault), 18);
        // CLAIM is share-denominated, so 18 decimals like the share token.
        pool.register(CLAIM_ID, address(vault.claimToken()), 18);

        MockCoreWriter cw = new MockCoreWriter();
        vm.etch(HyperCore.CORE_WRITER, address(cw).code);
        _sync();

        usdc.mint(address(pool), 1_000_000e6);
        vm.warp(block.timestamp + 1 days);
    }

    function _sync() internal {
        vm.mockCall(
            HyperCore.MARGIN_SUMMARY,
            abi.encode(uint32(0), address(vault)),
            abi.encode(HyperCore.MarginSummary(int64(uint64(coreEquity6)), 0, 0, int64(0)))
        );
        vm.mockCall(
            HyperCore.POSITION,
            abi.encode(address(vault), PERP),
            abi.encode(HyperCore.Position(int64(0), 0, 0, 10, false))
        );
        vm.mockCall(HyperCore.MARK_PX, abi.encode(PERP), abi.encode(px));
        vm.mockCall(HyperCore.ORACLE_PX, abi.encode(PERP), abi.encode(px));
        vm.mockCall(
            HyperCore.SPOT_BALANCE,
            abi.encode(address(vault), TOKEN_INDEX),
            abi.encode(HyperCore.SpotBalance(uint64(0), 0, 0))
        );
        vm.mockCall(
            HyperCore.PERP_ASSET_INFO,
            abi.encode(PERP),
            abi.encode(HyperCore.PerpAssetInfo("BTC", uint32(54), uint8(5), uint8(40), false))
        );
        vm.mockCall(
            HyperCore.BBO, abi.encode(PERP), abi.encode(HyperCore.Bbo({bid: px - 50, ask: px + 50}))
        );
    }

    function _deposit(uint256 amount) internal returns (PubAsset[] memory out) {
        PubAsset[] memory inAssets = new PubAsset[](1);
        inAssets[0] = PubAsset(USDC_ID, uint224(amount));
        out = pool.callAdaptor(
            handler,
            address(adaptor),
            inAssets,
            abi.encode(PerpVaultAdaptor.Action.DEPOSIT, address(vault))
        );
    }

    // ---------------------------------------------------------------- tests

    /// @dev The whole point of the adaptor: USDC in, share units out, so the Pool
    ///      has something to commit as a note. Never exercised before this.
    function test_depositThroughHandlerReturnsShares() public {
        PubAsset[] memory out = _deposit(10_000e6);

        assertEq(out.length, 1, "exactly one output asset");
        assertEq(out[0].id, SHARE_ID, "output must be the share asset id");
        assertEq(uint256(out[0].value), 10_000e18, "10,000 at NAV 1.0");

        assertEq(vault.balanceOf(address(pool)), 10_000e18, "Pool custodies the shares");
        assertEq(vault.totalAssets(), 10_000e6);
    }

    /// @dev Shares must price off the vault's NAV, not the deposit size, so a
    ///      later depositor through the adaptor buys none of an earlier gain.
    function test_secondDepositPricesAtCurrentNav() public {
        _deposit(10_000e6);

        // Move the deposit to Core and add 20%.
        vm.prank(address(vault));
        usdc.transfer(address(0xdead), 10_000e6);
        coreEquity6 = 12_000e6;
        _sync();
        // Virtual-offset conversion rounds down, in the vault's favour.
        assertApproxEqAbs(vault.pricePerShare(), 1.2e6, 1);

        PubAsset[] memory out = _deposit(12_000e6);
        assertApproxEqRel(uint256(out[0].value), 10_000e18, 1e12, "12,000 at NAV 1.2");
    }

    /// @dev Redeeming spends the share note and must return the underlying asset id.
    function test_redeemThroughHandlerReturnsUnderlying() public {
        _deposit(10_000e6);

        PubAsset[] memory inAssets = new PubAsset[](1);
        inAssets[0] = PubAsset(SHARE_ID, uint224(4_000e18));
        PubAsset[] memory out = pool.callAdaptor(
            handler,
            address(adaptor),
            inAssets,
            abi.encode(PerpVaultAdaptor.Action.REDEEM, address(vault))
        );

        assertEq(out[0].id, USDC_ID, "redeem returns the underlying");
        assertApproxEqAbs(uint256(out[0].value), 4_000e6, 1, "4,000 shares at NAV 1.0");
    }

    /// @dev A redemption the buffer cannot cover must hand back BOTH legs. Before
    ///      this, only the paid leg was returned and the CLAIM was minted to the
    ///      shared handler, never committed as a note — the holder silently lost
    ///      the queued portion and it sat where the next caller could take it.
    function test_partiallyQueuedRedeemReturnsBothLegs() public {
        _deposit(10_000e6);
        vm.prank(vault.keeper());
        vault.postMargin(9_000e6); // only 1,000 left liquid

        PubAsset[] memory inAssets = new PubAsset[](1);
        inAssets[0] = PubAsset(SHARE_ID, uint224(4_000e18));
        PubAsset[] memory out = pool.callAdaptor(
            handler,
            address(adaptor),
            inAssets,
            abi.encode(PerpVaultAdaptor.Action.REDEEM, address(vault))
        );

        assertEq(out.length, 2, "paid leg and queued leg");
        assertEq(out[0].id, USDC_ID);
        assertApproxEqAbs(uint256(out[0].value), 1_000e6, 1, "what the buffer covered");
        assertEq(out[1].id, CLAIM_ID, "the rest comes back as a CLAIM note");
        assertApproxEqRel(uint256(out[1].value), 3_000e18, 1e12, "denominated in SHARES");
        assertEq(
            vault.claimToken().balanceOf(address(handler)), 0, "nothing stranded at the handler"
        );
    }

    /// @dev A CLAIM note converts to asset once the unwind funds it.
    function test_claimNoteConvertsToUnderlying() public {
        _deposit(10_000e6);
        vm.prank(vault.keeper());
        vault.postMargin(9_000e6);

        PubAsset[] memory inAssets = new PubAsset[](1);
        inAssets[0] = PubAsset(SHARE_ID, uint224(4_000e18));
        PubAsset[] memory out = pool.callAdaptor(
            handler, address(adaptor), inAssets, abi.encode(PerpVaultAdaptor.Action.REDEEM, address(vault))
        );
        uint256 claimNote = uint256(out[1].value);

        // The unwind lands, comfortably covering the queue.
        usdc.mint(address(vault), 10_000e6);
        vault.fundClaims();
        assertEq(vault.claimSharesEscrowed(), 0, "queue fully settled");

        PubAsset[] memory claimIn = new PubAsset[](1);
        claimIn[0] = PubAsset(CLAIM_ID, uint224(claimNote));
        PubAsset[] memory paid = pool.callAdaptor(
            handler, address(adaptor), claimIn, abi.encode(PerpVaultAdaptor.Action.CLAIM, address(vault))
        );

        assertEq(paid.length, 1, "fully settled, so one leg");
        assertEq(paid[0].id, USDC_ID);
        assertGt(uint256(paid[0].value), 0, "paid at the settled rate");
        assertEq(vault.claimSharesSettled(), 0, "claim consumed");
        assertEq(vault.claimToken().balanceOf(address(handler)), 0, "nothing stranded");
    }

    /// @dev Partial settlement must not trap the holder: claim what is funded and
    ///      hand back a fresh CLAIM note for the rest.
    function test_partiallySettledClaimReturnsRemainderNote() public {
        _deposit(10_000e6);
        vm.prank(vault.keeper());
        vault.postMargin(9_000e6);

        PubAsset[] memory inAssets = new PubAsset[](1);
        inAssets[0] = PubAsset(SHARE_ID, uint224(4_000e18));
        PubAsset[] memory out = pool.callAdaptor(
            handler, address(adaptor), inAssets, abi.encode(PerpVaultAdaptor.Action.REDEEM, address(vault))
        );
        uint256 claimNote = uint256(out[1].value);

        // Only part of the unwind comes back.
        usdc.mint(address(vault), 500e6);
        vault.fundClaims();
        uint256 settled = vault.claimSharesSettled();
        assertGt(settled, 0, "some of it settled");
        assertLt(settled, claimNote, "but not all of it");

        PubAsset[] memory claimIn = new PubAsset[](1);
        claimIn[0] = PubAsset(CLAIM_ID, uint224(claimNote));
        PubAsset[] memory paid = pool.callAdaptor(
            handler, address(adaptor), claimIn, abi.encode(PerpVaultAdaptor.Action.CLAIM, address(vault))
        );

        assertEq(paid.length, 2, "paid leg and a remainder note");
        assertEq(paid[0].id, USDC_ID);
        assertGt(uint256(paid[0].value), 0, "paid for the settled part");
        assertEq(paid[1].id, CLAIM_ID, "remainder stays claimable");
        // Not wei-exact: _claim advances fundClaims() once more before reading, so
        // it may settle marginally more than the test just did.
        assertApproxEqRel(
            uint256(paid[1].value), claimNote - settled, 1e12, "remainder is the unsettled part"
        );
        assertEq(vault.claimToken().balanceOf(address(handler)), 0, "nothing stranded");
    }

    /// @dev AdaptorHandler reverts unless the tokens it reports are really there,
    ///      which is what stops an adaptor inventing output value.
    function test_handlerRejectsOutputItDoesNotHold() public {
        PubAsset[] memory inAssets = new PubAsset[](1);
        inAssets[0] = PubAsset(USDC_ID, uint224(1_000e6));

        // A vault the adaptor will call but which is not the registered share
        // asset: the handler ends up holding units of an asset it cannot match.
        PerpVault other = new PerpVault(
            IERC20(address(usdc)), TOKEN_INDEX, PERP, true, 20_000, "Other", "OTH", address(this)
        );
        vm.expectRevert();
        pool.callAdaptor(
            handler,
            address(adaptor),
            inAssets,
            abi.encode(PerpVaultAdaptor.Action.DEPOSIT, address(other))
        );
    }

    /// @dev Only the Pool may drive the handler.
    function test_handlerRejectsNonPoolCaller() public {
        PubAsset[] memory inAssets = new PubAsset[](1);
        inAssets[0] = PubAsset(USDC_ID, uint224(1_000e6));
        vm.prank(address(0xBEEF));
        vm.expectRevert();
        handler.handleAdaptor(
            address(adaptor),
            inAssets,
            abi.encode(PerpVaultAdaptor.Action.DEPOSIT, address(vault))
        );
    }
}
