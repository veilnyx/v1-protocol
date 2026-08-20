// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {Pool} from "src/core/Pool.sol";
import {AssetType, AssetInitParams, Asset} from "src/libraries/AssetLogic.sol";
import {PerpVault} from "src/adaptors/hyperliquid/PerpVault.sol";
import {PerpVaultAdaptor} from "src/adaptors/hyperliquid/PerpVaultAdaptor.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {HyperCore} from "src/adaptors/hyperliquid/IHyperCore.sol";

/// @title DeployPerpVault - one vault, correctly configured or not at all
/// @notice The first testnet vault shipped with asset = USD-T0 against
///         coreTokenIndex 0 (USDC), a pairing that strands every bridge and was
///         caught only by later inspection. Everything that inspection would have
///         checked is asserted here instead, against the chain, before broadcast.
///
/// Environment:
///   PRIVATE_KEY          deployer/owner key (0x-prefixed)
///   VAULT_ASSET          ERC20 the vault accepts (must be the token's evm link)
///   CORE_TOKEN_INDEX     Core spot token index for the asset
///   PERP_INDEX           Core perp market index
///   IS_LONG              true/false
///   TARGET_LEVERAGE_BPS  e.g. 20000 for 2x
///   DEPOSIT_CAP          launch cap in asset units (REQUIRED; caps the position
///                        inside the margin tier where maintenance is exact)
///   KEEPER               keeper address (defaults to deployer)
///   POOL                 Veilnyx Pool proxy; when set, SHARE and CLAIM are
///                        registered as Pool assets and the adaptor is deployed
///   PRICE_FEED           feed for Pool registration (required with POOL)
///   ALLOW_BROKEN_LINK    "true" skips the evm-link assertion. TESTNET ONLY:
///                        testnet USDC's linked contract is a dead proxy, so
///                        drills use an unlinked mock and fund Core directly.
contract DeployPerpVault is Script {
    struct Cfg {
        uint256 pk;
        address me;
        IERC20 asset;
        uint64 coreToken;
        uint32 perpIndex;
        bool isLong;
        uint256 targetLev;
        uint256 depositCap;
        address keeper;
        address pool;
    }

    function run() external {
        Cfg memory c;
        c.pk = vm.envUint("PRIVATE_KEY");
        c.me = vm.addr(c.pk);
        c.asset = IERC20(vm.envAddress("VAULT_ASSET"));
        c.coreToken = uint64(vm.envUint("CORE_TOKEN_INDEX"));
        c.perpIndex = uint32(vm.envUint("PERP_INDEX"));
        c.isLong = vm.envBool("IS_LONG");
        c.targetLev = vm.envUint("TARGET_LEVERAGE_BPS");
        c.depositCap = vm.envUint("DEPOSIT_CAP");
        c.keeper = vm.envOr("KEEPER", c.me);
        c.pool = vm.envOr("POOL", address(0));

        HyperCore.PerpAssetInfo memory p = _preflight(c);
        _deployAndVerify(c, p);
    }

    function _preflight(Cfg memory c) internal returns (HyperCore.PerpAssetInfo memory p) {
        IERC20 asset = c.asset;
        uint64 coreToken = c.coreToken;
        uint32 perpIndex = c.perpIndex;
        uint256 targetLev = c.targetLev;
        uint256 depositCap = c.depositCap;
        address pool = c.pool;

        // ---- pre-flight, against the chain, before anything is spent ----
        // HyperCore precompiles have no bytecode, so forge's local fork simulation
        // cannot execute them; vm.rpc sends a raw eth_call to the REAL node.

        // The pairing that was live-misconfigured once already.
        HyperCore.TokenInfo memory t = abi.decode(
            _ethCall(HyperCore.TOKEN_INFO, abi.encode(uint32(coreToken))),
            (HyperCore.TokenInfo)
        );
        if (vm.envOr("ALLOW_BROKEN_LINK", false)) {
            console2.log("!!! ALLOW_BROKEN_LINK: skipping evm-link assertion");
            console2.log("!!! bridge legs will NOT work; drills must fund Core directly");
        } else {
            require(
                t.evmContract == address(asset),
                "VAULT_ASSET is not the evm link of CORE_TOKEN_INDEX"
            );
        }

        // The vault hardcodes the spot bridge scale; the chain states it.
        require(t.evmExtraWeiDecimals < 0, "expected evm decimals below core wei decimals");
        require(
            uint256(10) ** uint8(-t.evmExtraWeiDecimals) == 100,
            "token bridge scale is not the vault's CORE_TO_EVM_SCALE"
        );

        // Perp USD is 1e6 everywhere in the vault's Core interactions; a non-6dp
        // asset exercises rescale paths no drill has ever run. Launch is USDC.
        require(IERC20Metadata(address(asset)).decimals() == 6, "launch assets are 6dp only");

        p = abi.decode(
            _ethCall(HyperCore.PERP_ASSET_INFO, abi.encode(perpIndex)),
            (HyperCore.PerpAssetInfo)
        );
        require(bytes(p.coin).length != 0, "perp index does not exist");
        require(uint256(p.maxLeverage) * 10_000 >= targetLev, "target exceeds market max leverage");
        require(!p.onlyIsolated, "vault requires cross margin");

        require(depositCap > 0 && depositCap != type(uint256).max, "set a real DEPOSIT_CAP");
        require(pool == address(0) || vm.envAddress("PRICE_FEED") != address(0), "POOL needs PRICE_FEED");

        console2.log("perp market     :", p.coin);
        console2.log("  szDecimals    :", p.szDecimals);
        console2.log("  maxLeverage   :", p.maxLeverage);
    }

    function _deployAndVerify(Cfg memory c, HyperCore.PerpAssetInfo memory p) internal {
        // ---- deploy ----
        vm.startBroadcast(c.pk);

        PerpVault vault = new PerpVault(
            c.asset,
            c.coreToken,
            c.perpIndex,
            c.isLong,
            c.targetLev,
            string.concat(p.coin, c.isLong ? " Long " : " Short ", _lev(c.targetLev)),
            string.concat("v", p.coin, c.isLong ? "L" : "S"),
            c.me
        );
        vault.setDepositCap(c.depositCap);
        if (c.keeper != c.me) vault.setKeeper(c.keeper);

        address pool = c.pool;
        address adaptor;
        if (pool != address(0)) {
            AssetInitParams[] memory reg = new AssetInitParams[](2);
            reg[0] = AssetInitParams({
                assetAddress: address(vault),
                precision: 18,
                usdPriceFeed: AggregatorV3Interface(vm.envAddress("PRICE_FEED"))
            });
            reg[1] = AssetInitParams({
                assetAddress: address(vault.claimToken()),
                precision: 18, // CLAIM is denominated in SHARES
                usdPriceFeed: AggregatorV3Interface(vm.envAddress("PRICE_FEED"))
            });
            Pool(payable(pool)).addAssets(AssetType.ERC20, reg);
            adaptor = address(new PerpVaultAdaptor(IPool(pool)));
        }

        vm.stopBroadcast();

        // ---- post-deploy verification, revert-on-fail ----
        require(vault.owner() == c.me, "owner mismatch");
        require(vault.keeper() == c.keeper, "keeper mismatch");
        require(vault.depositCap() == c.depositCap, "cap not set");
        require(address(vault.asset()) == address(c.asset), "asset mismatch");
        if (pool != address(0)) {
            // Registration is only real if the Pool can resolve both addresses.
            Asset memory shareAsset = Pool(payable(pool)).getAsset(address(vault));
            Asset memory claimAsset = Pool(payable(pool)).getAsset(address(vault.claimToken()));
            require(shareAsset.assetAddress == address(vault), "share not registered");
            require(claimAsset.assetAddress == address(vault.claimToken()), "claim not registered");
            console2.log("share asset id  :", shareAsset.id);
            console2.log("claim asset id  :", claimAsset.id);
            console2.log("adaptor         :", adaptor);
        } else {
            console2.log("!!! no POOL given: share/CLAIM NOT registered, no adaptor.");
            console2.log("!!! shielded deposits and redemptions will not work.");
        }

        console2.log("vault           :", address(vault));
        console2.log("claim token     :", address(vault.claimToken()));
        console2.log("owner/keeper    :", c.me, vault.keeper());
        console2.log("deposit cap     :", c.depositCap);
    }

    function _ethCall(address to, bytes memory data) internal returns (bytes memory) {
        string memory params = string.concat(
            '[{"to":"', vm.toString(to), '","data":"', vm.toString(data), '"},"latest"]'
        );
        return vm.rpc("eth_call", params);
    }

    function _lev(uint256 bps) internal pure returns (string memory) {
        // 20000 -> "2x"; sub-1x steps are not produced by this deployer.
        return string.concat(vm.toString(bps / 10_000), "x");
    }
}
