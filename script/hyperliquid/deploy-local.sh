#!/usr/bin/env bash
# Deploy a PerpVault against a mocked HyperCore on a local anvil node.
#
# HyperCore does not exist off HyperEVM, so the read precompiles and CoreWriter are
# replaced with mocks placed at their real addresses via anvil_setCode. That means
# share accounting, NAV, deposits, redemptions and the de-risk band are all real and
# testable here. Bridging, order execution and fills are NOT: those need testnet.
set -euo pipefail

RPC=${RPC:-http://127.0.0.1:8545}
# anvil's default account 0
PK=${PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}
ME=$(cast wallet address --private-key "$PK")

POSITION=0x0000000000000000000000000000000000000800
MARGIN=0x000000000000000000000000000000000000080f
MARKPX=0x0000000000000000000000000000000000000806
COREWRITER=0x3333333333333333333333333333333333333333

deploy() { # <path:Name> [constructor args...]
  local what="$1"; shift
  local out
  if [ "$#" -gt 0 ]; then
    out=$(forge create "$what" --rpc-url "$RPC" --private-key "$PK" --broadcast --json --constructor-args "$@")
  else
    out=$(forge create "$what" --rpc-url "$RPC" --private-key "$PK" --broadcast --json)
  fi
  printf '%s' "$out" | python3 -c 'import json,sys;print(json.load(sys.stdin)["deployedTo"])'
}

echo "deployer: $ME"
echo
echo "1/4  deploying mock HyperCore..."
MP=$(deploy test/mocks/MockHyperCorePrecompiles.sol:MockPositionPrecompile)
MM=$(deploy test/mocks/MockHyperCorePrecompiles.sol:MockMarginSummaryPrecompile)
MX=$(deploy test/mocks/MockHyperCorePrecompiles.sol:MockPxPrecompile)
MC=$(deploy test/mocks/MockHyperCorePrecompiles.sol:MockCoreWriter)

echo "2/4  installing them at the real precompile addresses..."
for pair in "$POSITION:$MP" "$MARGIN:$MM" "$MARKPX:$MX" "$COREWRITER:$MC"; do
  target=${pair%%:*}; src=${pair##*:}
  cast rpc anvil_setCode "$target" "$(cast code "$src" --rpc-url "$RPC")" --rpc-url "$RPC" >/dev/null
done

echo "3/4  deploying USDC + vault..."
USDC=$(deploy test/mocks/MockERC20.sol:MockERC20 "$ME" 6)
VAULT=$(deploy src/adaptors/hyperliquid/PerpVault.sol:PerpVault \
  "$USDC" 0 3 true 20000 "BTC Long 2x" vBTC2L "$ME")

echo "4/4  seeding state..."
cast send "$MARKPX" "set(uint64)" 100000000000 --rpc-url "$RPC" --private-key "$PK" >/dev/null
cast send "$MARGIN" "set(int64)" 0             --rpc-url "$RPC" --private-key "$PK" >/dev/null
cast send "$POSITION" "set(int64,int64,uint32)" 0 0 10 --rpc-url "$RPC" --private-key "$PK" >/dev/null
cast send "$USDC" "mint(address,uint256)" "$ME" 1000000000000 --rpc-url "$RPC" --private-key "$PK" >/dev/null
# Zero the entry fee so the first walkthrough reads cleanly. With the default
# 10bps the sole depositor pays a fee to themselves, which is harmless (they own
# the whole vault) but makes pricePerShare start at 1001001 rather than 1000000.
cast send "$VAULT" "setEntryFeeBps(uint256)" 0 --rpc-url "$RPC" --private-key "$PK" >/dev/null
cast send "$USDC" "approve(address,uint256)" "$VAULT" \
  115792089237316195423570985008687907853269984665640564039457584007913129639935 \
  --rpc-url "$RPC" --private-key "$PK" >/dev/null

cat <<EOF

  deployed
  --------
  USDC (6dp)      $USDC
  PerpVault       $VAULT
  markPx  ($MARKPX)
  margin  ($MARGIN)
  position($POSITION)
  CoreWriter ($COREWRITER)

  try it
  ------
  # deposit 10,000 USDC -> shares at NAV 1.0
  cast send $VAULT "deposit(uint256,address)" 10000000000 $ME --rpc-url $RPC --private-key \$PK

  cast call $VAULT "pricePerShare()(uint256)" --rpc-url $RPC   # 1000000 == NAV 1.0
  cast call $VAULT "totalAssets()(uint256)"   --rpc-url $RPC
  cast call $VAULT "balanceOf(address)(uint256)" $ME --rpc-url $RPC

  # simulate the money reaching Core and the position gaining 20%
  # (Core USD carries 8 decimals, so 12,000 USDC == 1200000000000)
  cast rpc anvil_impersonateAccount $VAULT --rpc-url $RPC
  cast rpc anvil_setBalance $VAULT 0xde0b6b3a7640000 --rpc-url $RPC
  cast send $USDC "transfer(address,uint256)" 0x000000000000000000000000000000000000dEaD 10000000000 --rpc-url $RPC --from $VAULT --unlocked
  cast send $MARGIN "set(int64)" 1200000000000 --rpc-url $RPC --private-key \$PK
  cast call $VAULT "pricePerShare()(uint256)" --rpc-url $RPC   # now 1200000 == NAV 1.2

  # rebalance emits the intended order; inspect what would have gone to Core
  cast send $VAULT "rebalance()" --rpc-url $RPC --private-key \$PK
  cast call $COREWRITER "actionCount()(uint256)" --rpc-url $RPC
  cast call $COREWRITER "actions(uint256)(bytes)" 0 --rpc-url $RPC
  # -> 0x01 000001 <abi payload>  =  version 1, action id 1 (limit order)

  # turn the entry fee back on to see it accrue to existing holders
  cast send $VAULT "setEntryFeeBps(uint256)" 10 --rpc-url $RPC --private-key \$PK
EOF
