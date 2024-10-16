import axios from 'axios';
import { genAddressRegistrations } from "./genTestAddressRegistration";
import { genTestDeposits } from "./genTestDeposits";
import { genTestWithdrawals } from "./genTestWithdrawals";
import { genTestTransfers } from "./genTestTransfers";
import { genTestCallAdaptors } from './genTestCallAdaptor';
import { getSDKInstance } from "./sdk";
import { Point, poseidonHash } from "@zkfi-tech/babyjubjub";
import { randomBigInt } from "@zkfi-tech/utils";
import {
  genTreeUpdateData,
  genTreeUpdateDataWithPartialQueue,
} from "./genTreeUpdateData";

const main = async () => {
  // const sdk = getSDKInstance();
  // await genAddressRegistrations(sdk);
  // await genTestDeposits(sdk);
  // await genTestWithdrawals(sdk);
  // await genTestTransfers(sdk);
  // await genTestCallAdaptors(sdk);
  // await genTreeUpdateData(sdk);
  // await genTreeUpdateDataWithPartialQueue(sdk);

  const url = "https://api.1inch.dev/swap/v6.0/11155111/swap";

  const config = {
    headers: {
      "Authorization": "Bearer KrXQn26FtekRkCVzyqO0Aopzqe0hLTfl"
    },
    params: {
      "src": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
      "dst": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      "amount": "500000000000000000",
      "from": "0x9f3dde1bcea1c3a7ea0b714e63319a6815f77a35",
      "origin": "0x689EcF264657302052c3dfBD631e4c20d3ED0baB",
      "slippage": "50",
      "receiver": "0x9f3dde1bcea1c3a7ea0b714e63319a6815f77a35"
    },
    paramsSerializer: {
      indexes: null
    }
  };


  try {
    const response = await axios.get(url, config);
    console.log(response.data);
  } catch (error) {
    console.error(error);
  }
};

main()
  .then(() => {
    console.log("Successfully generated test fixtures!");
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
