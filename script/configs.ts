import { Hex, isHex } from "viem";
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
};

export type AdaptorParams = {
  uniswap: Object;
  aave: Object;
  lido: Object;
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
        staticAWETH: getHex(aave.staticAWETH),
        staticAUSDC: getHex(aave.staticAUSDC),
      },
      lido: {
        lido: getHex(lido.lido),
        withdrawalQueueERC721: getHex(lido.withdrawalQueueERC721),
        stETH: getHex(lido.stETH),
        wstETH: getHex(lido.wstETH),
      },
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
    } = params;

    chainParams[Number(chainId)] = {
      entryPoint: getHex(entryPoint),
      wToken: getHex(wToken),
      sanctionsList: getHex(sanctionsList),
      poseidonT3: getHex(params.poseidonT3),
      poseidonT4: getHex(params.poseidonT4),
      initAssetType: Number(initAssetType),
      initAssetAddresses: initAssetAddresses.map(getHex),
    };
  }

  const configParams = { common: commonParams, adpConfig: adpParams, ...chainParams };

  return configParams;
}
