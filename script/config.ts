import { Hex, isHex } from "viem";
import config from "./config.json";

const { env, common, ...chains } = config;

type ChainParams = {
  entryPoint: Hex;
  wToken: Hex;
  sanctionsList: Hex;
  poseidonT3: Hex;
  poseidonT4: Hex;
  initAssetType: Number;
  initAssetsAddresses: Hex[];
};

const getHex = (v: any) => {
  if (!isHex(v)) {
    throw new Error(`Invalid hex: ${v}`);
  }
  return v as Hex;
};

const commonParams = {
  commitmentTreeDepth: Number(common.commitmentTreeDepth),
  commitmentTreeQueueSize: Number(common.commitmentTreeQueueSize),
  addressTreeDepth: Number(common.addressTreeDepth),
  withdrawFeeBps: BigInt(common.withdrawFeeBps),
  revokerPublicKeys: [],
  encryptionPublicKeys: [],
};

const chainParams: Record<number, ChainParams> = {};

for (const [chainId, params] of Object.entries(chains)) {
  if (!isNaN(Number(chainId))) {
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
    initAssetsAddresses: initAssetAddresses.map(getHex),
  };
}

const configParams = { common: commonParams, ...chainParams };

export default configParams;
