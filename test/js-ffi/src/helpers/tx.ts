import {
  encodeAbiParameters,
  decodeAbiParameters,
  parseAbiParameter,
  size,
} from "viem";
import { ShieldedAddress } from "@zkfi-tech/account";
import {
  HexString,
  TransactionRequest,
  TransactionType,
} from "@zkfi-tech/shared-types";

const reqTypes = [
  "uint8 txType",
  "uint24[] assetIds",
  "uint256[] values",
  "bytes to",
  "bytes payload",
];
const reqAbiParam = parseAbiParameter([
  "TransactionRequest req",
  `struct TransactionRequest {${reqTypes.join(";")}}`,
]);

export function parseTransactionRequest() {
  const data = process.argv[2] as string;

  const reqData = decodeAbiParameters([reqAbiParam], data as any)[0] as any;
  let to: HexString | ShieldedAddress;

  if (size(reqData.to) < 64) {
    to = `0x${reqData.to.slice(-40)}`; // trim(reqData.to) as HexString;
  } else if (size(reqData.to) === 64) {
    to = ShieldedAddress.unpack(reqData.to);
  } else {
    throw new Error(
      `Invalid address  ${reqData.to} of size ${size(
        reqData.to
      )} bytes detected`
    );
  }

  const req: TransactionRequest = {
    type: reqData.txType as TransactionType,
    assetIds: reqData.assetIds,
    values: reqData.values,
    feeAssetId: 0,
    to,
    payload: reqData.payload,
  };

  return req;
}

const ztxTypes = [
  { name: "txType", type: "uint8" },
  { name: "proof", type: "bytes" },
  { name: "merkleRoot", type: "uint256" },
  { name: "pubAssetIds", type: "uint24[]" },
  { name: "pubValues", type: "uint256[]" },
  { name: "nullifiers", type: "uint256[]" },
  { name: "commitments", type: "uint256[]" },
  { name: "memos", type: "bytes[]" },
  { name: "feeData", type: "uint256" },
  { name: "beneficiary", type: "uint256" },
  { name: "beneficiaryMemo", type: "bytes" },
  { name: "target", type: "address" },
  { name: "targetPayload", type: "bytes" },
  { name: "ephPubKey", type: "uint256[2]" },
  { name: "encAssets", type: "uint256[]" },
];

export function encodeZTransaction(ztx: any) {
  const values = [
    Number(ztx.txType),
    ztx.proof,
    ztx.merkleRoot,
    ztx.pubAssetIds,
    ztx.pubValues,
    ztx.nullifiers,
    ztx.commitments,
    ztx.memos,
    ztx.feeData,
    ztx.beneficiary,
    ztx.beneficiaryMemo,
    ztx.target,
    ztx.targetPayload,
    ztx.ephPubKey,
    ztx.encAssets,
  ];
  const vals = {};
  ztxTypes.forEach((t, i) => {
    vals[t.name] = values[i];
  });

  const types = ztxTypes.map((t) => `${t.type} ${t.name}`);
  const abiParam = parseAbiParameter([
    "ZTransaction ztx",
    `struct ZTransaction {${types.join(";")}}`,
  ]);
  //@ts-ignore
  return encodeAbiParameters([abiParam], [vals]);
}

export function decodeZTransaction(data: HexString) {
  const types = ztxTypes.map((t) => `${t.type} ${t.name}`);
  const abiParam = parseAbiParameter([
    "ZTransaction ztx",
    `struct ZTransaction {${types.join(";")}}`,
  ]);

  return decodeAbiParameters([abiParam], data)[0];
}
