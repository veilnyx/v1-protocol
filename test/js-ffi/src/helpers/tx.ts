import { decodeAbiParameters, parseAbiParameter, size, Hex } from "viem";
import { TransactionRequest, TransactionType } from "@zkfi-tech/shared-types";

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
  let to: Hex;

  if (size(reqData.to) < 64) {
    to = `0x${reqData.to.slice(-40)}`;
  } else if (size(reqData.to) === 64) {
    to = reqData.to;
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
