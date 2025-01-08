import { parseEther, parseUnits, zeroAddress, encodeAbiParameters } from "viem";
import { Core } from "@zkfi-tech/core";
import { TransactionType } from "@zkfi-tech/shared-types";
import { fixture, generateTestTransactions, mockNotes } from "./fixture";

const {
    assets: { testnetWeth, testnetUsdc, morphoVaultToken },
    sender: { account: senderAccount, pubAddress: senderPubAddress },
    receiver: { account: receiverAccount },
} = fixture;

enum Action {
    SUPPLY = 0,
    WITHDRAW = 1
}

export const reqs = {
    swap_10_testnet_usdc_to_weth_via_bundler: {
        type: TransactionType.CALL_ADAPTER,
        assetIds: [testnetUsdc],
        values: [parseUnits("10", 6)],
        to: "0x61D0Fa01EF56247cE0B15e86C21CBb9F7D4A29D0", // adaptor to which the ZkFi Convertor will call to execute swap
        revokerId: 0,
        feeAssetId: testnetUsdc,
        viaBundler: true,
        paymaster:
            `0x${"4c98c128da7a1fc79f387c5c3c6017a0a2d28268"}` as `0x${string}`,
        payload: encodeAbiParameters(
            [{
                type: "uint24",
                name: "outAssetId"
            }, {
                type: "address",
                name: "beneficiary"
            }, {
                type: "uint256",
                name: "minOut"
            }],
            [testnetWeth, zeroAddress, parseEther("0.0002")]
        ),
    },
    /**
   swap_1_testnet_weth_to_usdc: {
       type: TransactionType.CALL_ADAPTER,
       assetIds: [testnetWeth],
       values: [parseEther("1")],
       feeAssetId: 0,
       // adaptor to which the ZkFi AdaptorHandler will call to execute swap
       to: "0x61D0Fa01EF56247cE0B15e86C21CBb9F7D4A29D0",
       // payload:: refund: pool address (address(0)), outToken: testnetUsdc
       payload: encodeAbiParameters(
           [{
               type: "uint24",
               name: "outAssetId"
           }, {
               type: "address",
               name: "beneficiary"
           }, {
               type: "uint256",
               name: "minOut"
           }],
           [testnetUsdc, zeroAddress, BigInt(4000)]
       ),
       revokerId: 0,
       viaBundler: false,
       paymaster: zeroAddress
   },
   withdraw_2_morphoLoanToken: {
       type: TransactionType.CALL_ADAPTER,
       assetIds: [morphoVaultToken],
       values: [parseEther("2")],
       feeAssetId: 0,
       // adaptor to which the ZkFi AdaptorHandler will call to execute swap
       to: "0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8",
       // payload:: refund: pool address (address(0)), outToken: testnetUsdc
       payload: encodeAbiParameters(
           [{
               type: "uint8",
               name: "action"
           }, {
               type: "address",
               name: "morphoVault"
           }],
           [Action.WITHDRAW, '0x2371e134e3455e0593363cBF89d3b6cf53740618']
       ),
       revokerId: 0,
       viaBundler: false,
       paymaster: zeroAddress
   },
   stake_1_testnet_weth: {
       type: TransactionType.CALL_ADAPTER,
       assetIds: [testnetWeth],
       values: [parseEther("1")],
       feeAssetId: 0,
       // adaptor to which the ZkFi AdaptorHandler will call to execute swap
       to: "0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8",
       // payload:: refund: pool address (address(0)), outToken: testnetUsdc
       payload: "0x" as `0x${string}`,
       revokerId: 0,
       viaBundler: false,
       paymaster: zeroAddress
   },
   stake_1_testnet_weth_via_bundler: {
       type: TransactionType.CALL_ADAPTER,
       assetIds: [testnetWeth],
       values: [parseEther("1")],
       feeAssetId: testnetWeth,
       // adaptor to which the ZkFi AdaptorHandler will call to execute swap
       to: "0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8",
       // payload:: refund: pool address (address(0)), outToken: testnetUsdc
       payload: "0x" as `0x${string}`,
       revokerId: 0,
       viaBundler: true,
       paymaster: "0x03E98aE18908eBc2Fe82e646E4DFB628963383c1" as `0x${string}`,
   },
   lend_1_aave_weth: {
       type: TransactionType.CALL_ADAPTER,
       assetIds: [aaveWethUnderlying],
       values: [parseEther("1")],
       feeAssetId: 0,
       // adaptor to which the ZkFi AdaptorHandler will call to execute swap
       to: "0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8",
       // payload:: action: 0 (supply)
       payload: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
       revokerId: 0,
       viaBundler: false,
       paymaster: zeroAddress,
   },
   supply_5_usdt_crvUsd_on_curve: {
       type: TransactionType.CALL_ADAPTER,
       assetIds: [testnetUsdt, testnetCrvUsd],
       values: [parseUnits("5", 6), parseUnits("5", 18)],
       feeAssetId: 0,
       // adaptor to which the ZkFi AdaptorHandler will call to execute swap
       to: "0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8",
       // payload:: address pool: 0x390f3595bCa2Df7d23783dFd126427CCeb997BF4, action: 0 (supply)
       payload: "0x000000000000000000000000390f3595bca2df7d23783dfd126427cceb997bf40000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
       revokerId: 0,
       viaBundler: false,
       paymaster: zeroAddress,
   },
   stake_2_orig_usde_on_ethena: {
       type: TransactionType.CALL_ADAPTER,
       assetIds: [testnetUsde],
       values: [parseEther("2")],
       to: "0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8", // adaptor addr. which the ZkFi adaptor handler will call to execute this convert req
       revokerId: 0,
       feeAssetId: 0,
       viaBundler: false,
       paymaster: zeroAddress,
       payload: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`
   },
   supply_2_mooLPToken: {
       type: TransactionType.CALL_ADAPTER,
       assetIds: [beefyMooToken],
       values: [parseEther("2")],
       feeAssetId: 0,
       // adaptor to which the ZkFi AdaptorHandler will call to execute swap
       to: "0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8",
       // payload:: action: 0 (supply)
       payload: "0x000000000000000000000000000000000000000000000000000000000000000100000000000000000000000092a14518434a46e88cb4c3918ad33b3344099e02" as `0x${string}`,
       revokerId: 0,
       viaBundler: false,
       paymaster: zeroAddress,
   }
*/
};

export const genTestCallAdaptors = async (sdk: Core) => {
    await mockNotes("deposit_200_testnet_usdc", sdk);
    await generateTestTransactions(reqs, sdk);
};
