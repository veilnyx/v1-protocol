import { Hex, isHex, hexToNumber } from "viem";
import configJson from "./config.json";
import adaptorConfig from "./adaptorConfig.json";

const { env, common, ...chains } = configJson;


export type ChainParams = {
  entryPoint: Hex;
  wToken: Hex;
  sanctionsList: Hex;
  poseidonT3: Hex;
  poseidonT4: Hex;
  initAssetType: number;
  initAssetAddresses: Hex[];
  initAssetsPrecision: number[];
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
}

export type CommonParams = {
  commitmentTreeDepth: number;
  commitmentTreeQueueSize: number;
  addressTreeDepth: number;
  withdrawFeeBps: bigint;
  revokers: {
    name: string;
    description: string;
    revokerPublicKey: [bigint, bigint];
    encryptionPublicKey: [bigint, bigint];
  }[];
};

const chainParams: Record<number, ChainParams> = {};
const adpParams: Record<number, AdaptorParams> = {};

const getHex = (v: any) => {
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
    revokers: common.revokers.map((r) => {
      const x = {
        name: r.name,
        description: r.description,
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
  };

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
      rocketPool
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
        }
      },
      beefy: {
        assets: {
          mooCurveCrvUSDsUSDe: getHex(beefy.assets.mooCurveCrvUSDsUSDe)
        },
        assetsPrecision: {
          mooCurveCrvUSDsUSDe: Number(beefy.assetsPrecision.mooCurveCrvUSDsUSDe)
        }
      },
      morpho: {
        assets: {
          gauntletWETHPrimeVault: getHex(morpho.assets.gauntletWETHPrimeVault)
        },
        assetsPrecision: {
          gauntletWETHPrimeVault: Number(morpho.assetsPrecision.gauntletWETHPrimeVault)
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
        }
      }
    };
  }

  for (const [chainId, params] of Object.entries(chains)) {
    if (isNaN(Number(chainId))) {
      throw new Error(`Invalid chainId: ${chainId}`);
    }

    const {
      entryPoint,
      wToken,
      sanctionsList,
      initAssetType,
      initAssetAddresses,
      initAssetsPrecision
    } = params;

    chainParams[Number(chainId)] = {
      entryPoint: getHex(entryPoint),
      wToken: getHex(wToken),
      sanctionsList: getHex(sanctionsList),
      poseidonT3: getHex(params.poseidonT3),
      poseidonT4: getHex(params.poseidonT4),
      initAssetType: Number(initAssetType),
      initAssetAddresses: initAssetAddresses.map(getHex),
      initAssetsPrecision: initAssetsPrecision.map(p => Number(p))
    };
  }

  const configParams = { common: commonParams, adpConfig: adpParams, ...chainParams };

  return configParams;
}
