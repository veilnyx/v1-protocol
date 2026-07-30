import { Hex, isHex, hexToNumber, isAddress, isAddressEqual, zeroAddress } from "viem";
import configJson from "./config.json";
import adaptorConfig from "./adaptorConfig.json";

const { env, common, ...chains } = configJson;

export type ChainParams = {
  entryPoint: Hex;
  nativeWToken: Hex;
  sanctionsList: Hex;
  poseidonT3: Hex;
  poseidonT4: Hex;
  initAssetType: number;
  initAssetAddresses: Hex[];
  initAssetsPrecision: number[];
  initNativeGasTokenToAssetChainlinkFeeds: Hex[];
  initAssetToUSDChainlinkFeeds: Hex[];
  initAssetIdsVeilnyx: number[];
  nebraVerifier: Hex;
};

export type AdaptorParams = {
  uniswap: Object;
  aave: Object;
  lido: Object;
  curve: Object;
  ethena: Object;
  beefy: Object;
  morpho: Object;
  rocketPool: Object;
  oneInch: Object;
}

export type CommonParams = {
  commitmentTreeDepth: number;
  commitmentTreeQueueSize: number;
  addressTreeDepth: number;
  withdrawFeeBps: bigint;
  protocolVersion: bigint;
  veilnyxMultiSigAddress: Hex;
  hardwareWalletOwner: Hex;
  pauserAddress: Hex;
  revokers: {
    name: string;
    description: string;
    pinataCID: string;
    revokerPublicKey: [bigint, bigint];
    encryptionPublicKey: [bigint, bigint];
  }[];
};

const chainParams: Record<number, ChainParams> = {};
const adpParams: Record<number, AdaptorParams> = {};

export const getHex = (v: any) => {
  if (!isHex(v)) {
    throw new Error(`Invalid hex: ${v}`);
  }
  return v as Hex;
};

export function loadConfigs() {
  const commonParams = {
    commitmentTreeDepth: Number(common.commitmentTreeDepth),
    commitmentTreeQueueSize: Number(common.commitmentTreeQueueSize),
    addressTreeDepth: Number(common.addressTreeDepth),
    withdrawFeeBps: BigInt(common.withdrawFeeBps),
    protocolVersion: BigInt(common.protocolVersion),
    veilnyxMultiSigAddress: getHex(common.veilnyxMultiSigAddress),
    hardwareWalletOwner: getHex(common.hardwareWalletOwner),
    pauserAddress: getHex(common.pauserAddress),
    revokers: common.revokers.map((r) => {
      const x = {
        name: r.name,
        description: r.description,
        pinataCID: r.pinataCID,
        revokerPublicKey: [
          BigInt(r.revokerPublicKey[0]),
          BigInt(r.revokerPublicKey[1]),
        ],
        encryptionPublicKey: [
          BigInt(r.encryptionPublicKey[0]),
          BigInt(r.encryptionPublicKey[1]),
        ],
      };

      return x;
    }),
  } as CommonParams;

  /// @todo The adaptor assets whose price feeds are not live yet are currently set to have their USD price feed address as 0x0. Once those price feeds are live, update the config with the correct addresses. This is required for Mainnet deployment. Testnet deployments can proceed with the USD price feed addresses set to 0x0, with the drawback of such assets TVL not contributing to the total TVL of the protocol. 

  // Soln for assets who's USD price feeds are not live yet: The approach could be to set the USD price feed addresses of such assets to a mock aggregator that we control, and update the mock aggregator with the correct price. This way we can have an accurate total TVL for the protocol. For now, we'll proceed with setting the USD price feed addresses of such assets to 0x0 for simplicity.
  for (const [chainId, params] of Object.entries(adaptorConfig)) {
    if (isNaN(Number(chainId))) {
      throw new Error(`Invalid chainId: ${chainId}`);
    }

    const {
      uniswap,
      aave,
      lido,
      curve,
      ethena,
      beefy,
      morpho,
      rocketPool,
      oneInch
    } = params;

    adpParams[Number(chainId)] = {
      uniswap: {
        uniswapSwapRouter02: getHex(uniswap.uniswapSwapRouter02),
      },
      aave: {
        aave: getHex(aave.aave),
        aaveStaticTokenFactory: getHex(aave.aaveStaticTokenFactory),
        aWETH: getHex(aave.aWETH),
        aUSDC: getHex(aave.aUSDC),
        assets: {
          staticAWeth: getHex(aave.assets.staticAWeth),
          staticAUsdc: getHex(aave.assets.staticAUsdc),
        },
        assetsPrecision: {
          staticAWeth: Number(aave.assetsPrecision.staticAWeth),
          staticAUsdc: Number(aave.assetsPrecision.staticAUsdc)
        },
        assetsUsdPriceFeeds: {
          staticAWeth: getHex(aave.assetsUsdPriceFeeds.staticAWeth), // @todo update with correct price feed address once it's live
          staticAUsdc: getHex(aave.assetsUsdPriceFeeds.staticAUsdc) // @todo update with correct price feed address once it's live
        }
      },
      lido: {
        lido: getHex(lido.lido),
        withdrawalQueueERC721: getHex(lido.withdrawalQueueERC721),
        wETH: getHex(lido.wETH),
        stETH: getHex(lido.stETH),
        wstETH: getHex(lido.wstETH),
        assets: {
          wstEth: getHex(lido.assets.wstEth)
        },
        assetsPrecision: {
          wstEth: Number(lido.assetsPrecision.wstEth)
        },
        assetsUsdPriceFeeds: {
          wstEth: getHex(lido.assetsUsdPriceFeeds.wstEth) // @todo update with correct price feed address once it's live
        }
      },
      curve: {
        assets: {
          usdt: getHex(curve.assets.usdt),
          crvUsd: getHex(curve.assets.crvUsd),
          crvUsdUsdtLPToken: getHex(curve.assets.crvUsdUsdtLPToken),
          crvUsdSusdeLPToken: getHex(curve.assets.crvUsdSusdeLPToken)
        },
        assetsPrecision: {
          usdt: Number(curve.assetsPrecision.usdt),
          crvUsd: Number(curve.assetsPrecision.crvUsd),
          crvUsdUsdtLPToken: Number(curve.assetsPrecision.crvUsdUsdtLPToken),
          crvUsdSusdeLPToken: Number(curve.assetsPrecision.crvUsdSusdeLPToken)
        },
        assetsUsdPriceFeeds: {
          usdt: getHex(curve.assetsUsdPriceFeeds.usdt),
          crvUsd: getHex(curve.assetsUsdPriceFeeds.crvUsd),
          crvUsdUsdtLPToken: getHex(curve.assetsUsdPriceFeeds.crvUsdUsdtLPToken),
          crvUsdSusdeLPToken: getHex(curve.assetsUsdPriceFeeds.crvUsdSusdeLPToken)
        }
      },
      ethena: {
        ethena: getHex(ethena.ethena),
        usde: getHex(ethena.usde),
        assets: {
          usde: getHex(ethena.assets.usde),
          sUsde: getHex(ethena.assets.sUsde)
        },
        assetsPrecision: {
          usde: Number(ethena.assetsPrecision.usde),
          sUsde: Number(ethena.assetsPrecision.sUsde)
        },
        assetsUsdPriceFeeds: {
          usde: getHex(ethena.assetsUsdPriceFeeds.usde),
          sUsde: getHex(ethena.assetsUsdPriceFeeds.sUsde)
        }
      },
      beefy: {
        assets: {
          mooCurveCrvUSDsUSDe: getHex(beefy.assets.mooCurveCrvUSDsUSDe)
        },
        assetsPrecision: {
          mooCurveCrvUSDsUSDe: Number(beefy.assetsPrecision.mooCurveCrvUSDsUSDe)
        },
        assetsUsdPriceFeeds: {
          mooCurveCrvUSDsUSDe: getHex(beefy.assetsUsdPriceFeeds.mooCurveCrvUSDsUSDe)
        }
      },
      morpho: {
        assets: {
          gauntletWETHPrimeVault: getHex(morpho.assets.gauntletWETHPrimeVault)
        },
        assetsPrecision: {
          gauntletWETHPrimeVault: Number(morpho.assetsPrecision.gauntletWETHPrimeVault)
        },
        assetsUsdPriceFeeds: {
          gauntletWETHPrimeVault: getHex(morpho.assetsUsdPriceFeeds.gauntletWETHPrimeVault)
        }
      },
      rocketPool: {
        rocketSwapRouter: getHex(rocketPool.rocketSwapRouter),
        wETH: getHex(rocketPool.wETH),
        assets: {
          rETH: getHex(rocketPool.assets.rETH)
        },
        assetsPrecision: {
          rETH: Number(rocketPool.assetsPrecision.rETH)
        },
        assetsUsdPriceFeeds: {
          rETH: getHex(rocketPool.assetsUsdPriceFeeds.rETH)
        }
      },
      oneInch: {
        oneInchRouter: getHex(oneInch.oneInchRouter)
      }
    };
  }

  for (const [chainId, params] of Object.entries(chains)) {
    if (isNaN(Number(chainId))) {
      throw new Error(`Invalid chainId: ${chainId}`);
    }

    const {
      entryPoint,
      nativeWToken,
      sanctionsList,
      initAssetType,
      initAssetAddresses,
      initAssetsPrecision,
      initNativeGasTokenToAssetChainlinkFeeds,
      initAssetToUSDChainlinkFeeds,
      initAssetIdsVeilnyx,
      nebraVerifier,
    } = params as ChainParams;

    chainParams[Number(chainId)] = {
      entryPoint: getHex(entryPoint),
      nativeWToken: getHex(nativeWToken),
      sanctionsList: getHex(sanctionsList),
      poseidonT3: getHex(params.poseidonT3),
      poseidonT4: getHex(params.poseidonT4),
      initAssetType: Number(initAssetType),
      initAssetAddresses: initAssetAddresses.map(getHex),
      initAssetsPrecision: initAssetsPrecision.map(p => Number(p)),
      initNativeGasTokenToAssetChainlinkFeeds: initNativeGasTokenToAssetChainlinkFeeds.map(getHex),
      initAssetToUSDChainlinkFeeds: initAssetToUSDChainlinkFeeds.map(getHex),
      initAssetIdsVeilnyx: initAssetIdsVeilnyx.map(assetId => Number(assetId)),
      nebraVerifier: getHex(nebraVerifier),
    };
  }

  const configParams = { common: commonParams, adpConfig: adpParams, ...chainParams };

  return configParams;
}

// Asset ids are `1 byte AssetType | 2 bytes counter` (AssetLogic.addAsset), so the first
// ERC20 asset registered on a fresh pool is always (1 << 16) | 1. Paymaster.GAS_ASSET_ID
// hardcodes this id as the chain's gas token.
export const GAS_ASSET_ID = 65537;

/** Assets absent on the target chain are configured as the zero address rather than omitted. */
export const isUnconfigured = (assetAddress: any) =>
  !assetAddress || assetAddress.toLowerCase() === zeroAddress;

/**
 * Validates one chain's base-asset config against the rules `Pool` and `Paymaster` enforce.
 * Pure — reads config only, touches no chain state. Call it before a deployment spends any gas:
 * every problem it reports would otherwise surface after the libraries, implementation and proxy
 * are already on-chain, and none of it is repairable in place — the pool is behind a proxy, but
 * the asset counter only moves forward, so a shifted id means a full redeploy.
 *
 * Deliberately not called from {@link loadConfigs}: that walks every chain in config.json, and
 * these rules only hold for chains deployed by `deployCoreWithAdp.ts` (arc-testnet, for one,
 * registers a gas token that is not its `nativeWToken`). Each deploy script opts in for the one
 * chain it is targeting.
 */
export const assertChainAssetConfig = (chainId: number, chainParams: ChainParams) => {
  const errors: string[] = [];
  const {
    initAssetType: assetType,
    initAssetIdsVeilnyx: ids,
    initAssetAddresses: addresses,
    initAssetsPrecision: precisions,
    initAssetToUSDChainlinkFeeds: usdFeeds,
    initNativeGasTokenToAssetChainlinkFeeds: gasFeeds,
    nativeWToken: wNativeToken,
  } = chainParams;

  if (addresses.length === 0) {
    // Nothing below can say anything useful without the addresses to line up against.
    throw new Error(`config for chain ${chainId}: initAssetAddresses is empty — the pool would have no assets`);
  }

  // These are consumed strictly by index — addAssetsAndRevokers zips addresses/precisions/usdFeeds
  // into AssetInitParams, and deployPaymaster walks ids alongside gasFeeds. A short array silently
  // becomes `undefined` at the tail rather than an error.
  for (const [name, arr] of Object.entries({
    initAssetIdsVeilnyx: ids,
    initAssetsPrecision: precisions,
    initAssetToUSDChainlinkFeeds: usdFeeds,
    initNativeGasTokenToAssetChainlinkFeeds: gasFeeds,
  })) {
    if (arr.length !== addresses.length) {
      errors.push(
        `${name} has ${arr.length} entries, initAssetAddresses has ${addresses.length} — these are zipped by index`
      );
    }
  }

  addresses.forEach((assetAddress, i) => {
    // Checksum-insensitive: config mixes casings, and Pool only cares about the 20 bytes.
    if (!isAddress(assetAddress, { strict: false })) {
      errors.push(`initAssetAddresses[${i}] (${assetAddress}) is not a 20-byte address`);
      return;
    }
    if (isUnconfigured(assetAddress)) {
      errors.push(`initAssetAddresses[${i}] is the zero address — Pool.addAssets reverts with ZeroAddress()`);
      return;
    }
    const duplicateOf = addresses.findIndex((other, j) => j < i && isAddressEqual(other, assetAddress));
    if (duplicateOf !== -1) {
      errors.push(
        `initAssetAddresses[${i}] (${assetAddress}) duplicates [${duplicateOf}] — Pool.addAssets reverts with DuplicateAsset()`
      );
    }
  });

  // Asset ids are not free-form config: AssetLogic.addAsset derives them as
  // `(assetType << 16) | counter`, with the counter starting at 1 on a fresh pool. So the ids the
  // SDK, Paymaster and adaptorConfig are written against are fully determined by the order of
  // initAssetAddresses — this catches a hand-edited id list drifting from that order.
  ids.forEach((id, i) => {
    const derived = (assetType << 16) | (i + 1);
    if (id !== derived) {
      errors.push(
        `initAssetIdsVeilnyx[${i}] is ${id}, but addAssets assigns ${derived} to initAssetAddresses[${i}] (${addresses[i]})`
      );
    }
  });

  // Paymaster reads GAS_ASSET_ID's `precision` as an exponent in convertFeeFromGasTokenToFeeAsset,
  // and returns `maxCostEth` verbatim when the fee asset *is* GAS_ASSET_ID. An unset nativeWToken
  // is a supported configuration (Pool.setNativeWToken documents it as disabling native deposits),
  // so that one is a warning.
  if (isUnconfigured(wNativeToken)) {
    console.warn(`⚠️  chain ${chainId}: nativeWToken is unset — native ETH deposits will be disabled on this pool`);
  } else {
    if (!isAddressEqual(addresses[0], wNativeToken)) {
      errors.push(
        `nativeWToken ${wNativeToken} must be initAssetAddresses[0] (currently ${addresses[0]}) — Paymaster.GAS_ASSET_ID hardcodes ${GAS_ASSET_ID} as the gas token`
      );
    }
    if (((assetType << 16) | 1) !== GAS_ASSET_ID) {
      errors.push(
        `initAssetType ${assetType} makes the first asset id ${(assetType << 16) | 1}, but Paymaster.GAS_ASSET_ID hardcodes ${GAS_ASSET_ID} — the gas token must be the first asset of type ${GAS_ASSET_ID >> 16}`
      );
    }
  }

  if (errors.length > 0) {
    throw new Error(
      `Base-asset config for chain ${chainId} is invalid:\n` +
      errors.map((e) => `  - ${e}`).join("\n")
    );
  }

  console.log(`Config validated for chain ${chainId}: ${addresses.length} base asset(s), ids ${ids.join(", ")}`);
}
