#!/usr/bin/env bash
# Post-deploy probe checklist for a PerpVault. Every check that caught a real
# misconfiguration or bug during development runs here against the live chain.
# Usage: RPC=... VAULT=0x... [POOL=0x...] ./verify-vault.sh
set -euo pipefail

RPC=${RPC:-https://rpc.hyperliquid-testnet.xyz/evm}
VAULT=${VAULT:?set VAULT}
POOL=${POOL:-}
TOKEN_INFO=0x000000000000000000000000000000000000080C

pass=0; fail=0
ck() { # ck "label" "condition-result(1/0)" "detail"
  if [ "$2" = "1" ]; then pass=$((pass+1)); printf "  ok   %-42s %s\n" "$1" "${3:-}";
  else fail=$((fail+1)); printf "  FAIL %-42s %s\n" "$1" "${3:-}"; fi
}
q() { cast call "$VAULT" "$1" --rpc-url "$RPC" | awk '{print $1}'; }

echo "vault $VAULT"

ASSET=$(q 'asset()(address)')
CTI=$(q 'coreTokenIndex()(uint64)')
CAP=$(q 'depositCap()(uint256)')
KEEPER=$(q 'keeper()(address)')
OWNER=$(q 'owner()(address)')
CLAIM=$(q 'claimToken()(address)')

# 1. The pairing that shipped wrong once: asset must be the Core token's link.
LINKRAW=$(cast call $TOKEN_INFO "$(cast abi-encode 'f(uint32)' "$CTI")" --rpc-url "$RPC")
# evmContract is the 6th word (index 5) of the tuple; address = last 40 hex chars.
LINK_ADDR=0x${LINKRAW:$((2 + 64*5 + 24)):40}
if [ "$(echo "$LINK_ADDR" | tr 'A-F' 'a-f')" = "$(echo "$ASSET" | tr 'A-F' 'a-f')" ]; then
  ck "asset == evm link of coreTokenIndex" 1 "$ASSET"
else
  ck "asset == evm link of coreTokenIndex" 0 "asset=$ASSET link=$LINK_ADDR (drills use ALLOW_BROKEN_LINK)"
fi

# 2. Launch cap is set — the maintenance model is tier-1-exact only.
MAX=115792089237316195423570985008687907853269984665640564039457584007913129639935
[ "$CAP" != "$MAX" ] && [ "$CAP" != "0" ] && ck "deposit cap set" 1 "$CAP" || ck "deposit cap set" 0 "$CAP"

# 3. Roles.
[ "$KEEPER" != "0x0000000000000000000000000000000000000000" ] && ck "keeper set" 1 "$KEEPER" || ck "keeper set" 0
[ "$OWNER"  != "0x0000000000000000000000000000000000000000" ] && ck "owner set" 1 "$OWNER" || ck "owner set" 0

# 4. Market: target leverage inside the exchange cap.
TL=$(q 'targetLeverageBps()(uint256)')
ML=$(q 'maxLeverage()(uint256)')
[ "$((TL))" -le "$((ML * 10000))" ] && ck "target leverage <= market max" 1 "${TL}bps vs ${ML}x" || ck "target leverage <= market max" 0 "${TL}bps vs ${ML}x"

# 5. NAV identity: totalAssets == sum of the five locations minus the pot.
TA=$(q 'totalAssets()(uint256)')
SUM=$(python3 -c "print($(q 'coreEquity()(uint256)') + $(q 'idleAssets()(uint256)') + $(q 'coreSpot()(uint256)') + $(q 'pendingBridge()(uint256)') + $(q 'pendingWithdraw()(uint256)') - $(q 'claimPot()(uint256)'))")
[ "$TA" = "$SUM" ] && ck "totalAssets == sum of locations - pot" 1 "$TA" || ck "totalAssets == sum of locations - pot" 0 "reported=$TA sum=$SUM"

# 6. CLAIM decimals match shares (18): the redenomination that fixed the exit bug.
CD=$(cast call "$CLAIM" 'decimals()(uint8)' --rpc-url "$RPC")
[ "$CD" = "18" ] && ck "CLAIM is 18dp (share-denominated)" 1 || ck "CLAIM is 18dp (share-denominated)" 0 "$CD"

# 7. Pool registration, when a Pool is in play.
if [ -n "$POOL" ]; then
  SH_REG=$(cast call "$POOL" 'getAsset(address)((uint24,uint8,address,uint8,address,bool))' "$VAULT" --rpc-url "$RPC" 2>/dev/null || echo MISSING)
  CL_REG=$(cast call "$POOL" 'getAsset(address)((uint24,uint8,address,uint8,address,bool))' "$CLAIM" --rpc-url "$RPC" 2>/dev/null || echo MISSING)
  [ "$SH_REG" != "MISSING" ] && ck "share token registered in Pool" 1 || ck "share token registered in Pool" 0
  [ "$CL_REG" != "MISSING" ] && ck "CLAIM token registered in Pool" 1 || ck "CLAIM token registered in Pool" 0
else
  echo "  (no POOL given: registration checks skipped)"
fi

echo
echo "$pass passed, $fail failed"
[ "$fail" = "0" ]
