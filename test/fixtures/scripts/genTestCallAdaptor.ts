import { parseEther, parseUnits, zeroAddress } from "viem";
import { Core } from "@zkfi-tech/core";
import { TransactionType } from "@zkfi-tech/shared-types";
import { fixture, generateTestTransactions, mockNotes } from "./fixture";

const {
    assets: { testnetWeth, testnetUsdc },
    sender: { account: senderAccount, pubAddress: senderPubAddress },
    receiver: { account: receiverAccount },
} = fixture;

export const reqs = {
    swap_1_testnet_weth_to_usdc: {
        type: TransactionType.CALL_ADAPTER,
        assetIds: [testnetWeth],
        values: [parseEther("1")],
        feeAssetId: 0,
        // adaptor to which the ZkFi AdaptorHandler will call to execute swap
        to: "0x03E98aE18908eBc2Fe82e646E4DFB628963383c1", 
        // payload:: refund: pool address (address(0)), outToken: testnetUsdc
        payload: "0x000000000000000000000000000000000000000000000000000000000001000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
        revokerId: 0,
        viaBundler: false,
        paymaster: zeroAddress
    },
    /**
    swap_1e16_orig_weth_to_usdc_via_bundler: {
        type: TransactionType.CALL_ADAPTER,
        assetIds: [testnetWeth],
        values: [parseEther("0.01")],
        to: "0x03E98aE18908eBc2Fe82e646E4DFB628963383c1", // adaptor to which the ZkFi Convertor will call to execute swap
        revokerId: 0,
        feeAssetId: testnetWeth,
        viaBundler: true,
        paymaster: paymasterAddress,
        payload:
            "0x000000000000000000000000000000000000000000000000000000000001000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", // refund: pool address (address(0))
    }, stake_2_orig_usde_on_ethena: {
        type: TransactionType.CALL_ADAPTER,
        assetIds: [testnetUsdc],
        values: [parseUnits("2", 6)],
        to: "0x03E98aE18908eBc2Fe82e646E4DFB628963383c1", // adaptor addr. which the ZkFi adaptor handler will call to execute this convert req
        revokerId: 0,
        feeAssetId: 0,
        viaBundler: false,
        paymaster: zeroAddress,
        payload:
            "0x000000000000000000000000000000000000000000000000000000000001000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" as `0x{string}`, // refund: pool address (address(0)), outToken: USDe
    }
    */ 
};

export const genTestCallAdaptors = async (sdk: Core) => {
    await mockNotes("deposit_1_testnet_weth", sdk);
    await generateTestTransactions(reqs, sdk);
};
