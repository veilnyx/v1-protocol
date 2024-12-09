import { parseEther, parseUnits, zeroAddress, encodeAbiParameters } from "viem";
import { Core } from "@zkfi-tech/core";
import { TransactionType } from "@zkfi-tech/shared-types";
import { fixture, generateTestTransactions, mockNotes } from "./fixture";

const {
    assets: { weth, testnetWeth },
    sender: { account: senderAccount, pubAddress: senderPubAddress },
    receiver: { account: receiverAccount },
} = fixture;


export const reqs = {
    use_2_weth: {
        type: TransactionType.NON_ATOMIC,
        assetIds: [weth],
        values: [parseEther("2")],
        feeAssetId: 0,
        // adaptor to which the ZkFi AdaptorHandler will call to execute swap
        to: "0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8",
        // payload:: refund: pool address (address(0)), outToken: testnetUsdc
        payload: '0x' as `0x${string}`,
        revokerId: 0,
        viaBundler: false,
        paymaster: zeroAddress
    }
};

export const genTestNonAtomicTxs = async (sdk: Core) => {
    await mockNotes("deposit_2_weth", sdk);
    await generateTestTransactions(reqs, sdk);
};