// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {HyperCore} from "./IHyperCore.sol";
import {ClaimToken} from "./ClaimToken.sol";

/// @title PerpVault - a single fixed-strategy leveraged perp vault on HyperCore
/// @notice One contract per strategy (e.g. BTC-LONG-2x). Each instance is its own
///         HyperCore account, which is the only way to run two strategies on the
///         same asset without them netting into one position: a contract cannot
///         create sub-accounts, and cannot set isolated margin either.
/// @dev Shares are a NON-REBASING ERC20. This is load bearing, not a preference.
///      Veilnyx notes record unit counts while the Pool custodies the token; a
///      rebasing share would desynchronise the two and break redemption. The same
///      constraint is why LidoAdaptor wraps stETH into wstETH.
contract PerpVault is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @dev Scale between a Core SPOT token balance and its linked HyperEVM ERC20.
    ///      USDC carries 8 wei decimals on Core against 6 on the EVM (spotMeta
    ///      reports evm_extra_wei_decimals = -2), so bridged amounts scale by 100.
    ///
    ///      This applies to the BRIDGE ONLY. Perp USD figures use a different
    ///      convention entirely: `accountValue` from precompile 0x80f and the `ntl`
    ///      argument of CoreWriter action 7 are both 1e6, i.e. already aligned with
    ///      6-decimal USDC. Verified on chain 998: a perp account holding 10 USDC
    ///      reports accountValue = 10_000_000, and moving 10 USDC spot->perp takes
    ///      ntl = 10_000_000.
    ///
    ///      Dividing perp equity by this scale understated NAV a hundredfold.
    uint256 public constant CORE_TO_EVM_SCALE = 100;

    /// @dev Perp USD values (accountValue, usdClassTransfer ntl) carry 6 decimals.
    uint256 public constant PERP_USD_DECIMALS = 6;

    /// @dev Hyperliquid rejects perp prices with more than this many significant
    ///      figures. Rejection is silent, so this must be enforced before sending.
    uint256 public constant PX_SIG_FIGS = 5;

    /// @dev CoreWriter READS and WRITES use different scales, which is the single
    ///      easiest way to send an order that vanishes:
    ///        read  (0x800 szi, 0x806 markPx): per-asset, szDecimals and
    ///                                         6 - szDecimals respectively
    ///        write (action 1 limitPx, sz)   : a UNIFORM 1e8, per the docs —
    ///                                         "limitPx and sz should be sent as
    ///                                          10^8 * the human readable value"
    ///      Sending read-scaled values produced an order Core dropped with no
    ///      order, no fill and no error: observed sz=46 where 46_000 was required,
    ///      and limitPx=647_220 where 6_472_200_000_000 was required.
    uint256 public constant WIRE_DECIMALS = 8;

    uint256 public constant BPS = 10_000;

    /// @dev Hyperliquid drops orders below $10 notional as silently as it drops
    ///      over-precise prices — observed live: a $9.5 trim produced no order, no
    ///      fill, no error. Every order this contract sends must clear it.
    uint256 public constant MIN_ORDER_USD = 10;

    /// @dev Perp prices from precompile 0x806 carry `6 - szDecimals` decimals, and
    ///      sizes carry `szDecimals`. Converting between notional and size therefore
    ///      cancels szDecimals out and leaves a fixed 1e6 factor:
    ///        sz_raw  = notional_usd * 1e6 / markPx
    ///        notional_usd = sz_raw * markPx / 1e6
    ///      Verified against testnet: BTC szDecimals=5, markPx 644110 -> $64,411;
    ///      SOL szDecimals=2, markPx 774000 -> $77.40.
    ///      This is unrelated to CORE_TO_EVM_SCALE, which only governs the USDC
    ///      bridge. Conflating the two understated order size by 1e6.
    uint256 public constant PERP_PX_SCALE = 1e6;

    /// @dev Maintenance requirement is notional / (2 * maxLeverage), where
    ///      maxLeverage is per market and read from `perpAssetInfo`. It is NOT a
    ///      constant: BTC allows 40x while SOL allows 10x, so hardcoding 10
    ///      overstated maintenance margin fourfold on BTC — firing the de-risk band
    ///      far too early and misplacing the liquidation price.
    function maxLeverage() public view returns (uint256) {
        return HyperCore.perpAssetInfo(perpIndex).maxLeverage;
    }

    /// @notice Size decimals for this market, read from the exchange rather than
    ///         assumed. Perp prices carry `6 - szDecimals` decimals.
    function szDecimals() public view returns (uint8) {
        return HyperCore.perpAssetInfo(perpIndex).szDecimals;
    }

    IERC20 public immutable asset;
    uint8 internal immutable _assetDecimals;
    uint64 public immutable coreTokenIndex;
    uint32 public immutable perpIndex;
    bool public immutable isLong;

    /// @notice Target leverage in bps. 20_000 == 2x. Effective leverage is chosen
    ///         by position sizing; the exchange's 10x cap is a ceiling, not a mandate.
    uint256 public targetLeverageBps;

    /// @notice Multiple of TARGET leverage at which the vault de-levers rather than
    ///         holding target. 15_000 = 1.5x, so a 2x vault de-risks once effective
    ///         leverage passes 3x — roughly a third of equity gone. This is the
    ///         chosen alternative to an insurance fund, so it is load bearing.
    uint256 public deRiskBandBps = 15_000;

    /// @notice Charged on deposit to cover the rebalance this deposit forces.
    ///         Without it, an entrant's execution cost is socialised onto existing
    ///         holders. Excess accrues to the vault, i.e. to those holders.
    uint256 public entryFeeBps = 10;

    /// @notice Largest tolerated gap between the venue mark and the index oracle,
    ///         in bps, before the vault refuses to price.
    /// @dev NAV derives from accountValue, which HyperCore marks using its OWN
    ///      mark price. So a pushed mark does not merely mislead a price read, it
    ///      corrupts equity itself — deposit cheap, let the mark revert, redeem
    ///      rich. Validating the mark against the independent index price is what
    ///      makes that unprofitable, and it needs no on-chain TWAP because
    ///      HyperCore already publishes both. Observed divergence is 6-24 bps.
    uint256 public maxOracleDeviationBps = 200;

    /// @notice How far past the touch a rebalance order may be priced, in bps.
    ///         Bounds what a thin or fast-moving book can cost the vault.
    uint256 public maxSlippageBps = 50;

    /// @notice Hard ceiling on totalAssets(), in asset units.
    /// @dev The maintenance model is notional/(2*maxLeverage), which matches
    ///      HyperCore only in the LOWEST margin tier; larger positions sit in
    ///      higher marginTableId tiers with bigger requirements, so at size the
    ///      vault would understate maintenance and latch distress late. Until the
    ///      tiered table is read on-chain, the cap keeps the position inside the
    ///      tier where the model is exact. Deploys MUST set it; the constructor
    ///      default is uncapped only so test harnesses stay independent of it.
    uint256 public depositCap = type(uint256).max;

    bool public depositsFrozen;
    address public keeper;

    /// @notice Minimum seconds between rebalances.
    /// @dev CoreWriter order actions are deliberately delayed several seconds on
    ///      Core. Without a cooldown a keeper calling twice inside that window
    ///      reads the same stale position and places a SECOND order closing the
    ///      same gap, double-sizing the position. Nothing reverts; the vault simply
    ///      ends up at twice the intended exposure.
    uint256 public rebalanceCooldown = 30;
    uint256 public lastRebalanceAt;

    /// @notice Receipt handed out when a redemption cannot be paid immediately.
    ClaimToken public immutable claimToken;

    /// @notice Shares queued for exit and held in escrow by this contract,
    ///         awaiting the unwind that funds them.
    /// @dev Escrowed rather than burned. They stay in totalSupply, so they keep
    ///      tracking NAV and the exiting holder keeps their market exposure — and
    ///      their share of the unwind cost — until they are genuinely out.
    uint256 public claimSharesEscrowed;

    /// @notice Shares already converted to asset at a realised rate, claimable now.
    uint256 public claimSharesSettled;

    /// @notice Asset backing settled claims.
    /// @dev Held apart from the buffer so proceeds earmarked for exiting holders
    ///      are not recycled into the position, and so NAV does not count money
    ///      that is no longer the remaining holders'.
    uint256 public claimPot;

    /// @notice Asset sent from the Core spot balance toward HyperEVM, not yet
    ///         credited on this side.
    /// @dev The mirror of bridgeInFlight and needed for the same reason: the spot
    ///      debit on Core and the ERC20 credit on HyperEVM are not atomic, so
    ///      without this the money is invisible to BOTH coreSpot() (already fell)
    ///      and idleAssets() (not yet risen), and NAV dips for the width of the
    ///      window.
    uint256 public withdrawInFlight;

    /// @notice HyperEVM balance when the outbound bridge was last started or settled.
    uint256 public idleBeforeWithdraw;

    /// @notice Asset already sent to the Core system address but not yet credited.
    /// @dev The bridge is not atomic: the ERC20 leaves on this block, Core credits
    ///      it by a system transaction afterwards. Without tracking it, the amount
    ///      is invisible to BOTH idleAssets() (balanceOf already fell) and
    ///      coreEquity() (not credited yet), so totalAssets understates by the full
    ///      bridged amount for at least a block — usually most of the vault. NAV
    ///      collapses and recovers, which is a free round trip for anyone watching.
    uint256 public bridgeInFlight;

    /// @dev Core spot balance observed when the last bridge was initiated, so the
    ///      credited delta can be measured rather than assumed.
    uint256 public spotBeforeBridge;

    event Deposited(address indexed caller, uint256 assets, uint256 shares, uint256 navUsed);
    event Redeemed(address indexed caller, uint256 shares, uint256 assets, uint256 navUsed);
    event DepositsFrozen(bool frozen);
    event Rebalanced(int256 sizeDelta, uint256 equity, uint256 targetNotional);
    event OrderPlaced(bool isBuy, uint64 size, uint64 limitPx, uint128 cloid);
    event DeRisked(uint256 effectiveLeverageBps, uint256 triggerBps, uint256 newLeverageBps);
    event DistressDetected(uint256 equity, uint256 maintenanceMargin);
    event RebalanceSkipped(uint256 deviationBps);
    event RedemptionQueued(address indexed receiver, uint256 shares);
    event ClaimsFunded(uint256 assetSettled, uint256 sharesStillEscrowed);
    event Claimed(address indexed receiver, uint256 claimShares, uint256 paid);
    event BridgeStarted(uint256 amount, uint256 spotBefore);
    event BridgeSettled(uint256 credited, uint256 stillInFlight);
    event WithdrawStarted(uint256 amount, uint256 idleBefore);
    event WithdrawSettled(uint256 credited, uint256 stillInFlight);
    event TrimWidened(uint256 requestedNotional, uint256 sentNotional);
    event OrderBelowMinimum(uint256 requestedNotional, uint256 minimumNotional);
    event KeeperChanged(address keeper);
    event TargetLeverageChanged(uint256 bps);
    event EntryFeeChanged(uint256 bps);
    event MaxOracleDeviationChanged(uint256 bps);
    event MaxSlippageChanged(uint256 bps);
    event DeRiskBandChanged(uint256 bps);
    event RebalanceCooldownChanged(uint256 seconds_);
    event DepositCapChanged(uint256 cap);

    error ZeroAmount();
    error DepositsAreFrozen();
    error InsufficientIdleLiquidity(uint256 requested, uint256 available);
    error NotKeeper();
    error BadParameter();
    error RebalanceTooSoon(uint256 nextAllowedAt);
    error VaultDistressed();
    error ClaimNotSettled(uint256 requested, uint256 settled);
    error PriceDislocated(uint64 markPx, uint64 oraclePx, uint256 deviationBps);
    error BridgeBusy();
    error MarginFloorBreached(uint256 equityAfter, uint256 floor);
    error DepositCapExceeded(uint256 wouldBe, uint256 cap);

    modifier onlyKeeper() {
        if (msg.sender != keeper && msg.sender != owner()) revert NotKeeper();
        _;
    }

    constructor(
        IERC20 asset_,
        uint64 coreTokenIndex_,
        uint32 perpIndex_,
        bool isLong_,
        uint256 targetLeverageBps_,
        string memory name_,
        string memory symbol_,
        address owner_
    ) ERC20(name_, symbol_) Ownable(owner_) {
        // Bounded against the market cap at rebalance time, not construction:
        // perpAssetInfo is unavailable on chains without HyperCore.
        if (targetLeverageBps_ == 0) revert BadParameter();
        asset = asset_;
        _assetDecimals = IERC20Metadata(address(asset_)).decimals();
        coreTokenIndex = coreTokenIndex_;
        perpIndex = perpIndex_;
        isLong = isLong_;
        targetLeverageBps = targetLeverageBps_;
        keeper = owner_;
        // 18 decimals: the claim is denominated in shares, not asset.
        claimToken = new ClaimToken(
            string.concat(name_, " Claim"), string.concat(symbol_, "-CLAIM"), 18
        );
    }

    // ---------------------------------------------------------------- views

    /// @notice USDC sitting on the HyperEVM side, not yet posted as margin.
    /// @dev This is the redemption buffer. It is also equity, so it MUST be counted
    ///      in NAV: a deposit lives here for a step or two before reaching Core, and
    ///      a NAV that read only the Core precompile would omit money the vault
    ///      demonstrably holds.
    function idleAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    /// @notice Equity held in the vault's HyperCore account, in asset decimals.
    function coreEquity() public view returns (uint256) {
        HyperCore.MarginSummary memory m = HyperCore.marginSummary(address(this), 0);
        if (m.accountValue <= 0) return 0;
        // accountValue is 1e6; rescale only if the vault's asset is not 6dp.
        uint256 v = uint256(uint64(m.accountValue));
        if (_assetDecimals == PERP_USD_DECIMALS) return v;
        return _assetDecimals > PERP_USD_DECIMALS
            ? v * (10 ** (_assetDecimals - PERP_USD_DECIMALS))
            : v / (10 ** (PERP_USD_DECIMALS - _assetDecimals));
    }

    /// @notice Bridged asset Core has not yet credited.
    /// @dev Derived rather than stored, so it self-corrects as the credit lands
    ///      without anyone having to call settleBridge first. Storing the raw
    ///      in-flight figure and also counting coreSpot would double count for the
    ///      window between the credit arriving and settlement being invoked.
    function pendingBridge() public view returns (uint256) {
        if (bridgeInFlight == 0) return 0;
        uint256 spotNow = coreSpot();
        if (spotNow <= spotBeforeBridge) return bridgeInFlight;
        uint256 credited = spotNow - spotBeforeBridge;
        return credited >= bridgeInFlight ? 0 : bridgeInFlight - credited;
    }

    /// @notice Asset on its way back from Core that HyperEVM has not yet credited.
    /// @dev Derived, like pendingBridge, so it self-corrects in views as the credit
    ///      lands rather than depending on anyone having called settleWithdraw.
    function pendingWithdraw() public view returns (uint256) {
        if (withdrawInFlight == 0) return 0;
        uint256 idleNow = idleAssets();
        if (idleNow <= idleBeforeWithdraw) return withdrawInFlight;
        uint256 credited = idleNow - idleBeforeWithdraw;
        return credited >= withdrawInFlight ? 0 : withdrawInFlight - credited;
    }

    /// @notice Equity that is actually working in the position.
    /// @dev totalAssets() less the value of shares queued to leave. Those shares
    ///      still track NAV — that is exactly what keeps the exiter exposed — but
    ///      their backing must not be levered, or the unwind that funds them never
    ///      happens.
    function leveragedEquity() public view returns (uint256) {
        uint256 eq = totalAssets();
        uint256 owed = convertToAssets(claimSharesEscrowed);
        return eq > owed ? eq - owed : 0;
    }

    /// @notice Every place the vault's asset can be, so NAV never dips because
    ///         money is between two of them.
    /// @dev Four locations: the HyperEVM ERC20 balance, in flight across the
    ///      bridge, the Core SPOT balance, and Core PERP equity. Counting only
    ///      perp and EVM — as this did — makes NAV collapse and recover on every
    ///      bridge and every spot-to-perp move, which is a free round trip.
    function totalAssets() public view returns (uint256) {
        uint256 gross =
            coreEquity() + idleAssets() + coreSpot() + pendingBridge() + pendingWithdraw();
        // Only the pot is netted. Escrowed shares are still in totalSupply and
        // still backed by gross, which is what keeps a queued redeemer exposed to
        // NAV. Settlement burns escrowed shares and moves exactly their value into
        // the pot, so NAV is unchanged across it.
        return gross > claimPot ? gross - claimPot : 0;
    }

    /// @notice Core spot balance of the vault's asset, in asset decimals.
    function coreSpot() public view returns (uint256) {
        uint256 raw = HyperCore.spotBalance(address(this), coreTokenIndex).total;
        return raw / CORE_TO_EVM_SCALE; // spot is weiDecimals (8), asset is 6
    }

    /// @notice Current notional of the open position, in asset decimals.
    function notional() public view returns (uint256) {
        HyperCore.Position memory p = HyperCore.position(address(this), perpIndex);
        uint256 sz = p.szi < 0 ? uint256(uint64(-p.szi)) : uint256(uint64(p.szi));
        if (sz == 0) return 0;
        // notional in asset decimals = sz_raw * markPx * 10^assetDecimals / 1e6
        return (sz * HyperCore.markPx(perpIndex) * (10 ** _assetDecimals)) / PERP_PX_SCALE;
    }

    function maintenanceMargin() public view returns (uint256) {
        return notional() / (2 * maxLeverage());
    }

    /// @dev Shares are always 18 decimals regardless of the asset's, and the gap
    ///      between the two is used as a virtual-share offset. That offset is what
    ///      defeats the first-depositor inflation attack: `idleAssets()` reads
    ///      `balanceOf`, so anyone can donate USDC to the vault, and without the
    ///      offset a 1-wei first deposit followed by a large donation would round
    ///      every subsequent depositor's shares to zero.
    /// @notice Deviation between the venue mark and the index oracle, in bps.
    function markOracleDeviationBps() public view returns (uint256) {
        uint64 mark = HyperCore.markPx(perpIndex);
        uint64 oracle = HyperCore.oraclePx(perpIndex);
        if (oracle == 0 || mark == 0) return type(uint256).max;
        uint256 diff = mark > oracle ? mark - oracle : oracle - mark;
        return (diff * BPS) / oracle;
    }

    /// @dev Fails closed. A market with no oracle, or one dislocated beyond the
    ///      bound, must not be priced at all rather than priced optimistically.
    function _assertPriceSane() internal view {
        uint256 dev = markOracleDeviationBps();
        if (dev > maxOracleDeviationBps) {
            revert PriceDislocated(
                HyperCore.markPx(perpIndex), HyperCore.oraclePx(perpIndex), dev
            );
        }
    }

    /// @notice True when the open position is at or past its maintenance
    ///         requirement, i.e. liquidatable or already being liquidated.
    function isDistressed() public view returns (bool) {
        uint256 n = notional();
        if (n == 0) return false;
        return coreEquity() <= maintenanceMargin();
    }

    /// @notice Latch deposits shut if the vault is distressed.
    /// @dev Permissionless by design. The damaging failure is a liquidated vault
    ///      quietly accepting new money, and that must not wait on an operator
    ///      noticing. Clearing the latch stays owner-only, per halt-then-resume.
    function flagDistress() public returns (bool flagged) {
        if (!depositsFrozen && isDistressed()) {
            depositsFrozen = true;
            flagged = true;
            emit DistressDetected(coreEquity(), maintenanceMargin());
            emit DepositsFrozen(true);
        }
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function _decimalsOffset() internal view returns (uint256) {
        return 10 ** (18 - _assetDecimals);
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        return (assets * (totalSupply() + _decimalsOffset())) / (totalAssets() + 1);
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        return (shares * (totalAssets() + 1)) / (totalSupply() + _decimalsOffset());
    }

    /// @notice Assets backing one whole (1e18) share, in asset decimals.
    /// @dev "NAV 1.0" means this equals 10 ** assetDecimals. Quoted this way rather
    ///      than as a bare ratio so it stays readable when NAV is far from 1, which
    ///      after a liquidation it will be.
    function pricePerShare() public view returns (uint256) {
        return convertToAssets(1e18);
    }

    // ----------------------------------------------------------- mutations

    /// @notice Deposit `assets` and receive shares priced at PRE-deposit NAV.
    /// @dev The pull happens AFTER NAV is read. Reversing that order would let a
    ///      depositor buy their own money, which is the classic ERC-4626 mistake.
    function deposit(uint256 assets, address receiver) external nonReentrant returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();
        // Blocked on the LIVE condition, not the latch. Setting the latch here and
        // then reverting would roll the latch back with the rest of the call, so a
        // distressed vault would keep accepting deposits until someone happened to
        // call flagDistress() in its own transaction. Checking isDistressed()
        // directly means the very first deposit into a distressed vault is refused
        // whether or not anyone has flagged it yet.
        if (depositsFrozen) revert DepositsAreFrozen();
        if (isDistressed()) revert VaultDistressed();
        // Only meaningful while a position exists; with none, equity is cash and
        // no mark is involved in valuing it.
        if (notional() > 0) _assertPriceSane();
        _settleWithdraw();

        uint256 navUsed = pricePerShare();

        // Checked on POST-deposit totals so the cap cannot be overshot by one
        // large entry, and after settlement so a landed withdrawal is not
        // double-counted against it.
        uint256 wouldBe = totalAssets() + assets;
        if (wouldBe > depositCap) revert DepositCapExceeded(wouldBe, depositCap);

        uint256 fee = (assets * entryFeeBps) / BPS;
        uint256 credited = assets - fee;

        // Priced on PRE-deposit state: the pull below happens afterwards.
        shares = convertToShares(credited);

        asset.safeTransferFrom(msg.sender, address(this), assets);
        _rebaseWithdrawBaseline();
        _mint(receiver, shares);

        emit Deposited(msg.sender, assets, shares, navUsed);
    }

    /// @notice Redeem `shares`, paying what the buffer covers and queueing the rest.
    /// @dev What the buffer cannot cover is escrowed in SHARES and priced later by
    ///      fundClaims(), from the unwind that actually funds it — so the exiter
    ///      carries NAV and their own exit cost until they are genuinely out,
    ///      rather than fixing an asset amount today at the stayers' expense.
    function redeem(uint256 shares, address receiver)
        external
        nonReentrant
        returns (uint256 assets)
    {
        if (shares == 0) revert ZeroAmount();

        // A dislocated mark blocks anything PRICED — the immediate payment leg and
        // settlement — but must not block exit INTENT: escrowing shares needs no
        // price at all (the exit is priced later, at settlement, by design).
        // Reverting here would lock holders in during exactly the volatility that
        // makes them want out.
        bool priceOk = notional() == 0 || markOracleDeviationBps() <= maxOracleDeviationBps;
        if (priceOk) {
            // C-2 fix: earmark landed liquidity to the escrow queue BEFORE reading
            // the buffer. Without this, the unwind executed for queued exiters sits
            // as plain idle until the keeper's fundClaims tick, and a fresh
            // redeemer in that window takes all of it — the PoC showed a fully
            // queued holder starved while a later redeemer was paid in full from
            // her unwind. The keeper's "exits before redeployment" ordering is now
            // enforced here, not merely intended. fundClaims settles the withdraw
            // leg internally.
            fundClaims();
        } else {
            _settleWithdraw();
        }

        uint256 navUsed = pricePerShare();
        assets = convertToAssets(shares);

        // Split by SHARES, not by a fixed asset amount. Whatever the buffer covers
        // exits now at today's NAV; the rest stays in shares and is priced later,
        // from the unwind that actually funds it. Under a dislocated mark nothing
        // is paid now — everything queues.
        uint256 free =
            priceOk && idleAssets() > claimPot ? idleAssets() - claimPot : 0;
        uint256 sharesNow = convertToShares(free);
        if (sharesNow > shares) sharesNow = shares;
        uint256 sharesQueued = shares - sharesNow;

        assets = convertToAssets(sharesNow);
        if (sharesNow > 0) {
            _burn(msg.sender, sharesNow);
            asset.safeTransfer(receiver, assets);
        }
        if (sharesQueued > 0) {
            // Escrowed, not burned: the claim is on shares, so the holder stays
            // exposed until settlement rather than locking in today's price.
            _transfer(msg.sender, address(this), sharesQueued);
            claimSharesEscrowed += sharesQueued;
            claimToken.mint(receiver, sharesQueued);
            emit RedemptionQueued(receiver, sharesQueued);
        }

        _rebaseWithdrawBaseline();
        emit Redeemed(msg.sender, shares, assets, navUsed);
    }

    /// @notice Round a perp price to Hyperliquid's 5-significant-figure limit.
    /// @dev Prices carrying more than 5 significant figures are REJECTED, and a
    ///      rejected CoreWriter order does not revert — it is dropped silently,
    ///      leaving no order, no fill and no error. Observed on chain 998: a buy at
    ///      647169 ($64,716.9, six figures) produced no order at all.
    /// @param roundUp true for buys, so rounding keeps the order marketable rather
    ///        than pulling the limit back below the ask.
    function _roundPxSigFigs(uint256 p, bool roundUp) internal pure returns (uint64) {
        if (p == 0) return 0;
        uint256 digits;
        uint256 t = p;
        while (t > 0) {
            digits++;
            t /= 10;
        }
        if (digits <= PX_SIG_FIGS) return uint64(p);
        uint256 factor = 10 ** (digits - PX_SIG_FIGS);
        uint256 down = (p / factor) * factor;
        if (!roundUp || down == p) return uint64(down);
        return uint64(down + factor);
    }

    /// @notice Convert escrowed shares to asset at the CURRENT rate, up to whatever
    ///         the unwind has actually made liquid.
    /// @dev This is where the exit price is struck — after the unwind, not at
    ///      request. Burning escrowed shares and moving exactly their value into
    ///      the pot leaves NAV unchanged for everyone else, while the queued
    ///      holder has carried NAV, and their share of the unwind cost, until now.
    ///      Permissionless: leaving exiters unsettled while asset sits idle is
    ///      worse than letting anyone advance it.
    function fundClaims() public returns (uint256 funded) {
        _settleWithdraw();
        if (claimSharesEscrowed == 0) return 0;
        uint256 free = idleAssets() > claimPot ? idleAssets() - claimPot : 0;
        if (free == 0) return 0;

        uint256 settleable = convertToShares(free);
        if (settleable > claimSharesEscrowed) settleable = claimSharesEscrowed;
        if (settleable == 0) return 0;

        funded = convertToAssets(settleable);
        _burn(address(this), settleable);
        claimSharesEscrowed -= settleable;
        claimSharesSettled += settleable;
        claimPot += funded;
        emit ClaimsFunded(funded, claimSharesEscrowed);
    }

    /// @notice How much of `holder`'s claim can be settled right now.
    /// @dev Funding is partial whenever the unwind has not returned the full
    ///      amount, so a "claim all" button must pass this rather than the raw
    ///      CLAIM balance — otherwise it reverts on the dust left by rounding.
    function claimableShares(address holder) external view returns (uint256) {
        uint256 bal = claimToken.balanceOf(holder);
        return bal < claimSharesSettled ? bal : claimSharesSettled;
    }

    /// @notice Redeem a claim receipt for asset at the settled rate.
    /// @dev Pays pro rata against the pot, so tranches settled at different rates
    ///      BLEND rather than paying whoever claims first at the best one. The
    ///      blend is a deliberate decision, not an oversight: paying each tranche
    ///      at its own strike would require tying a CLAIM token to its settlement
    ///      epoch, and CLAIM is a fungible bearer asset registered once in the
    ///      Pool — per-epoch rates would need per-epoch asset ids, the exact cost
    ///      this design rejected for deposits. The exposure is bounded by how much
    ///      NAV moves between settlements, so the keeper settling every tick keeps
    ///      tranches small; a holder claiming promptly receives ~their strike.
    function claim(uint256 amount, address receiver) external nonReentrant returns (uint256 paid) {
        if (amount == 0) revert ZeroAmount();
        fundClaims();
        if (amount > claimSharesSettled) revert ClaimNotSettled(amount, claimSharesSettled);

        paid = (amount * claimPot) / claimSharesSettled;
        claimToken.burn(msg.sender, amount);
        claimSharesSettled -= amount;
        claimPot -= paid;
        if (paid > 0) asset.safeTransfer(receiver, paid);
        _rebaseWithdrawBaseline();
        emit Claimed(receiver, amount, paid);
    }

    // --------------------------------------------------------------- keeper

    /// @notice Bring notional back to target, or de-lever if inside the de-risk band.
    /// @dev Emits the intended delta. The order itself is delayed a few seconds on
    ///      Core and fills at a price not knowable here, so nothing downstream may
    ///      assume this has executed.
    function rebalance() external onlyKeeper returns (int256 sizeDelta) {
        if (block.timestamp < lastRebalanceAt + rebalanceCooldown) {
            revert RebalanceTooSoon(lastRebalanceAt + rebalanceCooldown);
        }
        lastRebalanceAt = block.timestamp;

        flagDistress();

        uint256 equity = totalAssets();
        if (equity == 0) return 0;

        uint256 leverage = targetLeverageBps;

        // De-risk band: when the position has drifted above target leverage
        // because equity fell, cut leverage instead of holding target.
        //
        // Measured against TARGET leverage, not maintenance margin. Maintenance is
        // notional/(2*maxLeverage) while notional is itself target*equity, so a
        // band expressed as a multiple of maintenance is scale-invariant and never
        // fires at target. Worked through, a 2x BTC vault (maxLeverage 40) would
        // only have de-risked after a ~96% equity loss, with liquidation at ~97.5%
        // — firing moments before the event it exists to avoid.
        uint256 current_ = notional();
        if (current_ > 0) {
            uint256 effLeverageBps = (current_ * BPS) / equity;
            uint256 trigger = (targetLeverageBps * deRiskBandBps) / BPS;
            if (effLeverageBps > trigger) {
                leverage = leverage / 2;
                emit DeRisked(effLeverageBps, trigger, leverage);
            }
        }

        // Size against equity that is actually staying. Escrowed claim value is on
        // its way out, so levering it would buy exposure the vault must immediately
        // sell again — and, worse, would leave the exit unfunded indefinitely:
        // escrowed shares move neither totalSupply nor totalAssets, so they create
        // no drift for this function to see and nothing would ever unwind.
        //
        // Trimming proportionally is liquidation-neutral. Closing notional and
        // releasing margin in the same ratio leaves leverage unchanged, so holders
        // who stay do not see their liquidation price move (C3 corollary).
        uint256 targetNotional = (leveragedEquity() * leverage) / BPS;
        sizeDelta = int256(targetNotional) - int256(current_);

        uint64 px = HyperCore.markPx(perpIndex);
        if (px == 0) revert BadParameter();

        uint256 deltaAbs = sizeDelta >= 0 ? uint256(sizeDelta) : uint256(-sizeDelta);

        // The exchange's $10 minimum. A sub-minimum order is dropped silently, so
        // sending one is worse than sending none: the caller believes it traded.
        // Two cases:
        //  - a sub-minimum TRIM while exits are queued would stall settlement
        //    forever (the residue shrinks geometrically and the trim with it), so
        //    it is WIDENED to the minimum — over-trimming de-levers slightly,
        //    which is the safe direction, and the excess returns as buffer;
        //  - any other sub-minimum delta is ordinary drift: skip it, say so, and
        //    let a later rebalance absorb it.
        uint256 minNotional = MIN_ORDER_USD * (10 ** _assetDecimals);
        bool widenedTrim;
        if (deltaAbs > 0 && deltaAbs < minNotional) {
            bool trimming = current_ > targetNotional;
            if (trimming && claimSharesEscrowed > 0) {
                // 5% over the minimum: the exchange checks notional at EXECUTION
                // price, which can sit below the mark this sizing reads.
                uint256 widened = (minNotional * 10_500) / BPS;
                if (widened > current_) widened = current_;
                emit TrimWidened(deltaAbs, widened);
                deltaAbs = widened;
                widenedTrim = true;
            } else {
                emit OrderBelowMinimum(deltaAbs, minNotional);
                deltaAbs = 0;
            }
        }

        // sz_raw = notional * 1e6 / (markPx * 10^assetDecimals). Floored normally;
        // CEILED for a widened trim, because flooring can round the notional back
        // under the minimum it was just widened past — observed live: $10.00
        // widened, sz floored to 0.00013 BTC, $9.39 sent, dropped silently.
        uint256 szDen = uint256(px) * (10 ** _assetDecimals);
        uint64 sz = widenedTrim
            ? uint64((deltaAbs * PERP_PX_SCALE + szDen - 1) / szDen)
            : uint64((deltaAbs * PERP_PX_SCALE) / szDen);
        if (sz > 0) {
            bool buy = isLong ? sizeDelta > 0 : sizeDelta < 0;

            // Price off the far side of the book, not the mark. An IOC at the mark
            // frequently does not fill because the mark can sit inside or outside
            // the spread — a buy has to cross the ask. A non-filling order is
            // silent: it reverts nothing and simply leaves the vault off target.
            // Do not trade into a dislocated book. Unlike deposit/redeem this
            // returns rather than reverting, so the state updates above (cooldown,
            // distress latch) still stand and the keeper can retry.
            if (markOracleDeviationBps() > maxOracleDeviationBps) {
                emit RebalanceSkipped(markOracleDeviationBps());
                return sizeDelta;
            }

            HyperCore.Bbo memory book = HyperCore.bbo(perpIndex);
            uint64 ref = buy ? book.ask : book.bid;
            if (ref == 0) ref = px; // empty book: fall back rather than send a zero price

            uint256 bounded = buy
                ? (uint256(ref) * (BPS + maxSlippageBps)) / BPS
                : (uint256(ref) * (BPS - maxSlippageBps)) / BPS;
            // Round for the 5-sig-fig rule while still in precompile units;
            // scaling by a power of ten does not change significant figures.
            uint64 limitPxRead = _roundPxSigFigs(bounded, buy);

            // Convert both legs from read scale to CoreWriter's uniform 1e8.
            uint256 szDec = szDecimals();
            uint64 szWire = uint64(uint256(sz) * (10 ** (WIRE_DECIMALS - szDec)));
            uint64 pxWire = uint64(uint256(limitPxRead) * (10 ** (WIRE_DECIMALS - (6 - szDec))));

            // cloid ties the fill back to the rebalance that caused it; without one
            // fills cannot be correlated to intent at all.
            uint128 cloid = uint128(uint256(keccak256(abi.encode(address(this), block.number, sz, buy))));

            HyperCore.limitOrder(perpIndex, buy, pxWire, szWire, false, HyperCore.TIF_IOC, cloid);
            emit OrderPlaced(buy, szWire, pxWire, cloid);
        }

        emit Rebalanced(sizeDelta, equity, targetNotional);
    }

    /// @notice Move idle USDC across to Core and post it as perp margin.
    /// @dev Two steps with different latencies: the ERC20 transfer is credited by a
    ///      system transaction after this block, while the class transfer is not
    ///      delayed at all.
    /// @notice Begin bridging idle asset to the Core spot balance.
    /// @dev Does NOT move spot into perp margin: the credit has not landed yet, so
    ///      a class transfer here would act on a stale balance. Call settleBridge()
    ///      once Core has credited it.
    function postMargin(uint256 amount) external onlyKeeper {
        // One bridge direction at a time. An outbound withdrawal debits the same
        // spot balance this function's delta is measured on (and moves idle, whose
        // baseline the withdrawal is measured on), so concurrent legs corrupt each
        // other's measurements. Settle first so a completed leg does not block.
        _settleWithdraw();
        if (withdrawInFlight > 0) revert BridgeBusy();
        if (amount == 0 || amount > idleAssets()) revert ZeroAmount();
        spotBeforeBridge = coreSpot();
        bridgeInFlight += amount;
        asset.safeTransfer(HyperCore.systemAddress(coreTokenIndex), amount);
        _rebaseWithdrawBaseline();
        emit BridgeStarted(amount, spotBeforeBridge);
    }

    /// @notice Recognise however much of the bridge has actually landed, and move
    ///         it into perp margin.
    /// @dev Measures the delta rather than assuming the transfer arrived whole:
    ///      Core may credit in parts. Permissionless, because leaving capital
    ///      stranded in flight is worse than letting anyone advance it.
    function settleBridge() public returns (uint256 credited) {
        if (bridgeInFlight == 0) return 0;
        uint256 spotNow = coreSpot();
        if (spotNow <= spotBeforeBridge) return 0;

        credited = spotNow - spotBeforeBridge;
        if (credited > bridgeInFlight) credited = bridgeInFlight;

        bridgeInFlight -= credited;
        spotBeforeBridge = spotNow - credited;

        // ntl is 1e6; the asset may not be.
        uint256 ntl = _assetDecimals == PERP_USD_DECIMALS
            ? credited
            : (_assetDecimals > PERP_USD_DECIMALS
                ? credited / (10 ** (_assetDecimals - PERP_USD_DECIMALS))
                : credited * (10 ** (PERP_USD_DECIMALS - _assetDecimals)));
        if (ntl > 0) HyperCore.usdClassTransfer(uint64(ntl), true);
        emit BridgeSettled(credited, bridgeInFlight);
    }

    /// @notice Send asset from the Core spot balance back to HyperEVM.
    /// @dev The return leg the claim queue depends on: freed margin lands as Core
    ///      spot, but claim() pays an ERC20 on HyperEVM. Sending spot to the
    ///      token's system address is the reverse of postMargin's transfer in.
    ///      Split from the perp-to-spot class transfer (moveUsdClass) because the
    ///      two have different latencies — the class transfer is immediate, this
    ///      credit arrives by a later system transaction.
    function withdrawFromCore(uint256 amount) external onlyKeeper {
        // Mirror of the guard in postMargin: the inbound leg measures a delta on
        // the spot balance this spotSend is about to debit on a delay.
        settleBridge();
        if (bridgeInFlight > 0) revert BridgeBusy();
        if (amount == 0) revert ZeroAmount();
        if (amount > coreSpot()) revert BadParameter();
        _settleWithdraw();
        idleBeforeWithdraw = idleAssets();
        withdrawInFlight += amount;
        // spotSend takes weiDecimals (8); asset is 6.
        HyperCore.spotSend(
            HyperCore.systemAddress(coreTokenIndex),
            coreTokenIndex,
            uint64(amount * CORE_TO_EVM_SCALE)
        );
        emit WithdrawStarted(amount, idleBeforeWithdraw);
    }

    /// @notice Recognise however much of the outbound bridge has reached HyperEVM.
    /// @dev Permissionless, as settleBridge is, and for the same reason.
    function settleWithdraw() public returns (uint256 credited) {
        return _settleWithdraw();
    }

    function _settleWithdraw() internal returns (uint256 credited) {
        if (withdrawInFlight == 0) return 0;
        uint256 idleNow = idleAssets();
        if (idleNow <= idleBeforeWithdraw) return 0;
        credited = idleNow - idleBeforeWithdraw;
        if (credited > withdrawInFlight) credited = withdrawInFlight;
        withdrawInFlight -= credited;
        // Any excess over the credit is new deposits, not the bridge. Rebasing to
        // the live balance stops that excess being read as a credit next time,
        // which is why this is called before anything else that moves idle.
        idleBeforeWithdraw = idleNow;
        emit WithdrawSettled(credited, withdrawInFlight);
    }

    /// @dev C-1 fix. The in-flight withdrawal is measured as "idle rose above the
    ///      baseline", so the baseline must move with every idle movement this
    ///      contract makes — otherwise an outflow mid-flight drops idle below it
    ///      and the eventual credit double-counts (46% NAV overstatement in the
    ///      PoC), while an inflow is swallowed as a fake credit. Called at the END
    ///      of every function that moves the idle balance, after _settleWithdraw
    ///      has recognised anything that landed before the move.
    function _rebaseWithdrawBaseline() internal {
        if (withdrawInFlight > 0) idleBeforeWithdraw = idleAssets();
    }

    /// @notice Move USDC between the Core spot and perp balances.
    /// @dev `postMargin` bridges from the HyperEVM side, which needs a working
    ///      linked ERC20. Where the Core balance was funded directly instead — as
    ///      it must be on testnet, whose USDC has no functioning EVM link — this is
    ///      the only way to get spot into perp margin.
    /// @param ntl Raw amount in CoreWriter's units for action 7.
    function moveUsdClass(uint64 ntl, bool toPerp) external onlyKeeper {
        // A class transfer moves the spot balance immediately; doing so while an
        // inbound bridge is measuring a spot delta either masks the credit
        // (toPerp: bridgeInFlight sticks and pendingBridge turns phantom) or gets
        // itself misread as the credit (fromPerp). Settle first, then require the
        // measurement window to be closed.
        settleBridge();
        if (bridgeInFlight > 0) revert BridgeBusy();

        // Pulling margin from under the position must not walk it toward
        // liquidation: a compromised or buggy keeper could otherwise strip margin
        // and let the market do the stealing. Equity after the pull must clear
        // 1.5x maintenance. (toPerp adds margin and needs no floor.)
        if (!toPerp && notional() > 0) {
            uint256 pull = _assetDecimals == PERP_USD_DECIMALS
                ? uint256(ntl)
                : (_assetDecimals > PERP_USD_DECIMALS
                    ? uint256(ntl) * (10 ** (_assetDecimals - PERP_USD_DECIMALS))
                    : uint256(ntl) / (10 ** (PERP_USD_DECIMALS - _assetDecimals)));
            uint256 floor_ = (maintenanceMargin() * 15_000) / BPS;
            uint256 eq = coreEquity();
            if (eq < pull + floor_) {
                revert MarginFloorBreached(eq > pull ? eq - pull : 0, floor_);
            }
        }
        HyperCore.usdClassTransfer(ntl, toPerp);
    }

    // ---------------------------------------------------------------- admin

    /// @dev Deposits freeze on liquidation and only an explicit operator action
    ///      resumes them. Redemptions deliberately stay open throughout.
    function setDepositsFrozen(bool frozen) external onlyOwner {
        depositsFrozen = frozen;
        emit DepositsFrozen(frozen);
    }

    function setRebalanceCooldown(uint256 seconds_) external onlyOwner {
        if (seconds_ > 1 days) revert BadParameter();
        rebalanceCooldown = seconds_;
        emit RebalanceCooldownChanged(seconds_);
    }

    function setKeeper(address keeper_) external onlyOwner {
        if (keeper_ == address(0)) revert BadParameter();
        keeper = keeper_;
        emit KeeperChanged(keeper_);
    }

    /// @dev Takes effect on the next rebalance, including for the sizing of trims
    ///      that fund queued exits — lowering leverage mid-queue slows settlement.
    function setTargetLeverageBps(uint256 bps) external onlyOwner {
        if (bps == 0 || bps > maxLeverage() * BPS) revert BadParameter();
        targetLeverageBps = bps;
        emit TargetLeverageChanged(bps);
    }

    function setEntryFeeBps(uint256 bps) external onlyOwner {
        if (bps > 500) revert BadParameter();
        entryFeeBps = bps;
        emit EntryFeeChanged(bps);
    }

    function setMaxOracleDeviationBps(uint256 bps) external onlyOwner {
        if (bps == 0 || bps > 2_000) revert BadParameter();
        maxOracleDeviationBps = bps;
        emit MaxOracleDeviationChanged(bps);
    }

    function setMaxSlippageBps(uint256 bps) external onlyOwner {
        if (bps > 1_000) revert BadParameter();
        maxSlippageBps = bps;
        emit MaxSlippageChanged(bps);
    }

    function setDeRiskBandBps(uint256 bps) external onlyOwner {
        if (bps < BPS) revert BadParameter();
        deRiskBandBps = bps;
        emit DeRiskBandChanged(bps);
    }

    /// @dev See depositCap. Lowering below current totalAssets() is allowed and
    ///      simply stops NEW deposits; nothing is forced out.
    function setDepositCap(uint256 cap) external onlyOwner {
        if (cap == 0) revert BadParameter();
        depositCap = cap;
        emit DepositCapChanged(cap);
    }
}
