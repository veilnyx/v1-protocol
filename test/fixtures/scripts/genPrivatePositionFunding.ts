import { Core } from "@veilnyx-sdk/core";
import { TransactionType } from "@veilnyx-sdk/shared-types";
import { parseEther, parseUnits } from "viem";
import { fixture, generateTestTransactions } from "./fixture";

const {
  assets: { weth, usdc },
} = fixture;

/// The funding leg of a private position: ONE shielded withdrawal carrying
/// margin AND native gas to a freshly derived burner.
///
/// This is the claim the whole design rests on (plan §7.1) — if gas cannot ride
/// along, the burner must be gas-funded from the user's own wallet, which is
/// total deanonymisation. Generating a real proof for it is the only way to know
/// the circuits actually permit a 2-asset withdrawal: the constraint is
/// pubAssets <= output notes, so this must select a >=2-output circuit.
///
/// The burner is derived from a THROWAWAY test seed, never a real spending key.
const BURNER = "0xFa214a7EBA274116D38Abcb01D8A1AA31e09F5cC";
const RELAYER = "0xd5182b47388e0ffe14781b9dBb7E9b699624cA96";

export const reqsPrivatePositionFunding = {
  // Spends deposit_pre_tx's notes (10,000 WETH + 10,000 USDC).
  // weth stands in for native gas here: the fixture pool's native wrapper is
  // WETH, exactly as HYPE's wrapper is WHYPE on 998.
  private_position_funding: {
    type: TransactionType.WITHDRAW,
    assetIds: [usdc, weth],
    values: [parseUnits("1000", 6), parseEther("2")],
    feeAssetId: usdc, // fee in the margin asset, never in gas
    to: BURNER,
    // RELAYED, not bundled: chain 998 has no bundler, so the funding tx is
    // submitted straight to pool.transact by our relayer, which the Pool
    // compensates via paymasterFees[relayer][feeAssetId]. Before the SDK gained
    // this mode the fee fields were silently zeroed and the relayer would have
    // worked for free.
    viaBundler: false,
    relayed: true,
    paymaster: RELAYER as `0x${string}`,
    relayFee: parseUnits("2", 6), // the relayer's quote, in the margin asset
    revokerId: 0,
  },
};

export const genPrivatePositionFunding = async (sdk: Core) => {
  console.log("proving a 2-asset funding withdrawal (margin + gas)...");
  await generateTestTransactions(reqsPrivatePositionFunding, sdk);
};
