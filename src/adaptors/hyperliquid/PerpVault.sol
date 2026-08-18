// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {HyperCore} from "./IHyperCore.sol";

/// @title PerpVault - a single fixed-strategy leveraged perp vault on HyperCore
/// @notice One contract per strategy (e.g. BTC-LONG-2x). Each instance is its own
///         HyperCore account, which is the only way to run two strategies on the
///         same asset without them netting into one position: a contract cannot
///         create sub-accounts, and cannot set isolated margin either.
/// @dev Shares are a NON-REBASING ERC20. This is load bearing, not a preference.
///      Veilnyx notes record unit counts while the Pool custodies the token; a
///      rebasing share would desynchronise the two and break redemption. The same
///      constraint is why LidoAdaptor wraps stETH into wstETH.
contract PerpVault is ERC20, Ownable {
    using SafeERC20 for IERC20;

    /// @dev Core USD values carry 8 decimals; the linked USDC ERC20 on HyperEVM
    ///      carries 6 (spotMeta reports evm_extra_wei_decimals = -2). Every value
    ///      crossing the bridge must be scaled by this factor. Getting the
    ///      direction wrong is a silent 100x error.
    uint256 public constant CORE_TO_EVM_SCALE = 100;

    uint256 public constant BPS = 10_000;

    /// @dev Exchange maintenance requirement is notional / (2 * maxLeverage).
    uint256 public constant MAX_LEVERAGE = 10;

    IERC20 public immutable asset;
    uint8 internal immutable _assetDecimals;
    uint64 public immutable coreTokenIndex;
    uint32 public immutable perpIndex;
    bool public immutable isLong;

    /// @notice Target leverage in bps. 20_000 == 2x. Effective leverage is chosen
    ///         by position sizing; the exchange's 10x cap is a ceiling, not a mandate.
    uint256 public targetLeverageBps;

    /// @notice Below this multiple of maintenance margin the vault de-levers rather
    ///         than holding target. This is the chosen alternative to an insurance
    ///         fund, so it is load bearing.
    uint256 public deRiskBandBps = 15_000; // 1.5x maintenance

    /// @notice Charged on deposit to cover the rebalance this deposit forces.
    ///         Without it, an entrant's execution cost is socialised onto existing
    ///         holders. Excess accrues to the vault, i.e. to those holders.
    uint256 public entryFeeBps = 10;

    bool public depositsFrozen;
    address public keeper;

    event Deposited(address indexed caller, uint256 assets, uint256 shares, uint256 navUsed);
    event Redeemed(address indexed caller, uint256 shares, uint256 assets, uint256 navUsed);
    event DepositsFrozen(bool frozen);
    event Rebalanced(int256 sizeDelta, uint256 equity, uint256 targetNotional);

    error ZeroAmount();
    error DepositsAreFrozen();
    error InsufficientIdleLiquidity(uint256 requested, uint256 available);
    error NotKeeper();
    error BadParameter();

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
        if (targetLeverageBps_ == 0 || targetLeverageBps_ > MAX_LEVERAGE * BPS) revert BadParameter();
        asset = asset_;
        _assetDecimals = IERC20Metadata(address(asset_)).decimals();
        coreTokenIndex = coreTokenIndex_;
        perpIndex = perpIndex_;
        isLong = isLong_;
        targetLeverageBps = targetLeverageBps_;
        keeper = owner_;
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
        return uint256(uint64(m.accountValue)) / CORE_TO_EVM_SCALE;
    }

    function totalAssets() public view returns (uint256) {
        return coreEquity() + idleAssets();
    }

    /// @notice Current notional of the open position, in asset decimals.
    function notional() public view returns (uint256) {
        HyperCore.Position memory p = HyperCore.position(address(this), perpIndex);
        uint256 sz = p.szi < 0 ? uint256(uint64(-p.szi)) : uint256(uint64(p.szi));
        if (sz == 0) return 0;
        return (sz * HyperCore.markPx(perpIndex)) / CORE_TO_EVM_SCALE;
    }

    function maintenanceMargin() public view returns (uint256) {
        return notional() / (2 * MAX_LEVERAGE);
    }

    /// @dev Shares are always 18 decimals regardless of the asset's, and the gap
    ///      between the two is used as a virtual-share offset. That offset is what
    ///      defeats the first-depositor inflation attack: `idleAssets()` reads
    ///      `balanceOf`, so anyone can donate USDC to the vault, and without the
    ///      offset a 1-wei first deposit followed by a large donation would round
    ///      every subsequent depositor's shares to zero.
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
    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();
        if (depositsFrozen) revert DepositsAreFrozen();

        uint256 navUsed = pricePerShare();

        uint256 fee = (assets * entryFeeBps) / BPS;
        uint256 credited = assets - fee;

        // Priced on PRE-deposit state: the pull below happens afterwards.
        shares = convertToShares(credited);

        asset.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);

        emit Deposited(msg.sender, assets, shares, navUsed);
    }

    /// @notice Burn `shares` and pay out USDC from the idle buffer.
    /// @dev Stage 1 is buffer-only: if the buffer cannot cover the payout this
    ///      reverts rather than silently queueing. The CLAIM-token queue that
    ///      handles the overflow case is deliberately not implemented yet.
    function redeem(uint256 shares, address receiver) external returns (uint256 assets) {
        if (shares == 0) revert ZeroAmount();

        uint256 navUsed = pricePerShare();
        assets = convertToAssets(shares);

        uint256 available = idleAssets();
        if (assets > available) revert InsufficientIdleLiquidity(assets, available);

        _burn(msg.sender, shares);
        asset.safeTransfer(receiver, assets);

        emit Redeemed(msg.sender, shares, assets, navUsed);
    }

    // --------------------------------------------------------------- keeper

    /// @notice Bring notional back to target, or de-lever if inside the de-risk band.
    /// @dev Emits the intended delta. The order itself is delayed a few seconds on
    ///      Core and fills at a price not knowable here, so nothing downstream may
    ///      assume this has executed.
    function rebalance() external onlyKeeper returns (int256 sizeDelta) {
        uint256 equity = totalAssets();
        if (equity == 0) return 0;

        uint256 leverage = targetLeverageBps;

        // De-risk band: below a multiple of maintenance margin, cut leverage rather
        // than hold target. Chosen over an insurance fund because a fee-funded pot
        // cannot cover a ~63% liquidation loss at any plausible size.
        uint256 mm = maintenanceMargin();
        if (mm > 0 && coreEquity() * BPS < mm * deRiskBandBps) {
            leverage = leverage / 2;
        }

        uint256 targetNotional = (equity * leverage) / BPS;
        uint256 current = notional();

        sizeDelta = int256(targetNotional) - int256(current);

        uint64 px = HyperCore.markPx(perpIndex);
        if (px == 0) revert BadParameter();

        uint256 deltaAbs = sizeDelta >= 0 ? uint256(sizeDelta) : uint256(-sizeDelta);
        uint64 sz = uint64((deltaAbs * CORE_TO_EVM_SCALE) / px);
        if (sz > 0) {
            bool buy = isLong ? sizeDelta > 0 : sizeDelta < 0;
            HyperCore.limitOrder(perpIndex, buy, px, sz, false, HyperCore.TIF_IOC, 0);
        }

        emit Rebalanced(sizeDelta, equity, targetNotional);
    }

    /// @notice Move idle USDC across to Core and post it as perp margin.
    /// @dev Two steps with different latencies: the ERC20 transfer is credited by a
    ///      system transaction after this block, while the class transfer is not
    ///      delayed at all.
    function postMargin(uint256 amount) external onlyKeeper {
        if (amount == 0 || amount > idleAssets()) revert ZeroAmount();
        asset.safeTransfer(HyperCore.systemAddress(coreTokenIndex), amount);
        HyperCore.usdClassTransfer(uint64(amount * CORE_TO_EVM_SCALE), true);
    }

    // ---------------------------------------------------------------- admin

    /// @dev Deposits freeze on liquidation and only an explicit operator action
    ///      resumes them. Redemptions deliberately stay open throughout.
    function setDepositsFrozen(bool frozen) external onlyOwner {
        depositsFrozen = frozen;
        emit DepositsFrozen(frozen);
    }

    function setKeeper(address keeper_) external onlyOwner {
        keeper = keeper_;
    }

    function setTargetLeverageBps(uint256 bps) external onlyOwner {
        if (bps == 0 || bps > MAX_LEVERAGE * BPS) revert BadParameter();
        targetLeverageBps = bps;
    }

    function setEntryFeeBps(uint256 bps) external onlyOwner {
        if (bps > 500) revert BadParameter();
        entryFeeBps = bps;
    }

    function setDeRiskBandBps(uint256 bps) external onlyOwner {
        if (bps < BPS) revert BadParameter();
        deRiskBandBps = bps;
    }
}
