import { parseEther, parseUnits } from "viem";
import { TransactionType } from "@veilnyx-sdk/shared-types";
import {
    fixture,
    generatePackedUserOpsWithFeeQuote,
    mockNotes,
    PAYMASTER_ADDR_FIXTURE,
} from "./fixture";
import { getSDKInstance } from "./sdk";

const FIXTURE_NAME = "transfer_20_weth_with_weth_fee_effective_gas_price";

const main = async () => {
    const { sdk, nebraClient } = await getSDKInstance();
    const {
        assets: { weth },
        receiver: { account: receiverAccount },
    } = fixture;

    await mockNotes("deposit_weth_tx", sdk);
    await generatePackedUserOpsWithFeeQuote(
        FIXTURE_NAME,
        {
            type: TransactionType.TRANSFER,
            assetIds: [weth],
            values: [parseEther("20")],
            to: receiverAccount.shieldedAddress.pack(),
            viaBundler: true,
            paymaster: PAYMASTER_ADDR_FIXTURE as `0x${string}`,
            feeAssetId: weth,
            revokerId: 0,
        },
        sdk,
        false,
        nebraClient,
        {
            maxFeePerGas: parseUnits("100", 9),
            maxPriorityFeePerGas: parseUnits("2", 9),
            baseFeePerGas: parseUnits("20", 9),
            headroomBps: 0,
        },
    );
};

main()
    .then(() => {
        console.log(`Successfully generated ${FIXTURE_NAME} fixtures!`);
        process.exit(0);
    })
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });