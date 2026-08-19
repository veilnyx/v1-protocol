#!/usr/bin/env bash
# Drive a locally deployed PerpVault through a full lifecycle against a mocked
# HyperCore: two depositors entering at different NAVs, a rebalance that emits a
# real CoreWriter order, redemption from the buffer, redemption failing once the
# buffer is drained, a liquidation, and a restart afterwards.
#
# HyperCore is mocked, so nothing here proves bridging or order execution. What it
# does prove is the share accounting, which is the part the plan's numbers rest on.
set -euo pipefail

RPC=${RPC:-http://127.0.0.1:8545}
PK=${PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}
# anvil account 1, used as the second depositor
PK2=${PK2:-0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d}
VAULT=${VAULT:?set VAULT}
USDC=${USDC:?set USDC}
MARGIN=0x000000000000000000000000000000000000080f
POSITION=0x0000000000000000000000000000000000000800
MARKPX=0x0000000000000000000000000000000000000806
CW=0x3333333333333333333333333333333333333333

ALICE=$(cast wallet address --private-key "$PK")
BOB=$(cast wallet address --private-key "$PK2")

q()  { cast call "$@" --rpc-url "$RPC" 2>/dev/null | awk '{print $1}'; }
send(){ cast send "$@" --rpc-url "$RPC" >/dev/null 2>&1; }
# Values arrive via argv: nesting the same quote inside an f-string is a syntax
# error on Python 3.9, which is what ships here.
usd() { python3 -c 'import sys; print(f"{int(sys.argv[1])/1e6:,.2f}")' "$1"; }
sh6() { python3 -c 'import sys; print(f"{int(sys.argv[1])/1e18:,.2f}")' "$1"; }
# Display only. The mock market mirrors BTC: szDecimals=5, so perp px carries
# 6-szDecimals = 1 decimal and size carries 5.
SZ_DECIMALS=5
px6() { python3 -c 'import sys; d=int(sys.argv[2]); print(f"{int(sys.argv[1])/10**(6-d):,.0f}")' "$1" "$SZ_DECIMALS"; }

state() {
  printf "  %-26s px=%-9s equity=%-12s shares=%-12s NAV=%-9s\n" \
    "$1" \
    "$(px6 "$(q $MARKPX 'px()(uint64)')")" \
    "$(usd "$(q $VAULT 'totalAssets()(uint256)')")" \
    "$(sh6 "$(q $VAULT 'totalSupply()(uint256)')")" \
    "$(usd "$(q $VAULT 'pricePerShare()(uint256)')")"
}

# Core equity is 8dp; the ERC20 is 6dp. Everything crossing the bridge scales by 100.
set_core() { send $MARGIN "set(int64)" "$1" --private-key "$PK"; }
set_px()   { send $MARKPX "set(uint64)" "$1" --private-key "$PK"; }
# Stand-in for the bridge: funds leave the EVM side, Core equity is set separately.
to_core()  { cast rpc anvil_impersonateAccount $VAULT --rpc-url "$RPC" >/dev/null
             cast rpc anvil_setBalance $VAULT 0xde0b6b3a7640000 --rpc-url "$RPC" >/dev/null
             send $USDC "transfer(address,uint256)" 0x000000000000000000000000000000000000dEaD "$1" --from $VAULT --unlocked; }

echo "=============================================================="
echo " 1. Alice deposits 10,000"
echo "=============================================================="
send $USDC "mint(address,uint256)" $ALICE 100000000000 --private-key "$PK"
send $USDC "approve(address,uint256)" $VAULT 115792089237316195423570985008687907853269984665640564039457584007913129639935 --private-key "$PK"
send $VAULT "deposit(uint256,address)" 10000000000 $ALICE --private-key "$PK"
state "after Alice deposit"
echo "  Alice shares: $(sh6 "$(q $VAULT 'balanceOf(address)(uint256)' $ALICE)")"

echo
echo "=============================================================="
echo " 2. Funds reach Core; position gains 20%"
echo "=============================================================="
to_core 10000000000
set_core 1200000000000
state "after +20%"

echo
echo "=============================================================="
echo " 3. Bob deposits 12,000 at the higher NAV"
echo "=============================================================="
send $USDC "mint(address,uint256)" $BOB 100000000000 --private-key "$PK"
cast rpc anvil_setBalance $BOB 0xde0b6b3a7640000 --rpc-url "$RPC" >/dev/null
send $USDC "approve(address,uint256)" $VAULT 115792089237316195423570985008687907853269984665640564039457584007913129639935 --private-key "$PK2"
send $VAULT "deposit(uint256,address)" 12000000000 $BOB --private-key "$PK2"
state "after Bob deposit"
echo "  Bob shares  : $(sh6 "$(q $VAULT 'balanceOf(address)(uint256)' $BOB)")"
echo "  Alice value : $(usd "$(q $VAULT 'convertToAssets(uint256)(uint256)' "$(q $VAULT 'balanceOf(address)(uint256)' $ALICE)")")"
echo "  Bob value   : $(usd "$(q $VAULT 'convertToAssets(uint256)(uint256)' "$(q $VAULT 'balanceOf(address)(uint256)' $BOB)")")"

echo
echo "=============================================================="
echo " 4. Keeper rebalances -> CoreWriter order"
echo "=============================================================="
before=$(q $CW 'actionCount()(uint256)')
send $VAULT "rebalance()" --private-key "$PK"
after=$(q $CW 'actionCount()(uint256)')
echo "  CoreWriter actions: $before -> $after"
raw=$(q $CW 'actions(uint256)(bytes)' $((after-1)))
echo "  version byte : 0x${raw:2:2}   action id: 0x${raw:4:6}  (1 = limit order)"
python3 - "$raw" <<'PY'
import sys
raw=sys.argv[1][2:]
payload=bytes.fromhex(raw[8:])
w=[payload[i:i+32] for i in range(0,len(payload),32)]
g=lambda i:int.from_bytes(w[i],'big')
SZD=5
print(f"    perp={g(0)} isBuy={bool(g(1))} limitPx=${g(2)/10**(6-SZD):,.0f} sz={g(3)/10**SZD:.5f} BTC (raw {g(3):,}) reduceOnly={bool(g(4))} tif={g(5)}")
print(f"    check: {g(3)/10**SZD:.5f} BTC x ${g(2)/10**(6-SZD):,.0f} = ${g(3)/10**SZD*g(2)/10**(6-SZD):,.0f} notional")
PY

echo
echo "=============================================================="
echo " 5. Alice redeems half from the idle buffer"
echo "=============================================================="
half=$(python3 -c 'import sys; print(int(sys.argv[1])//2)' "$(q $VAULT 'balanceOf(address)(uint256)' $ALICE)")
echo "  idle buffer before: $(usd "$(q $VAULT 'idleAssets()(uint256)')")"
send $VAULT "redeem(uint256,address)" "$half" $ALICE --private-key "$PK"
echo "  redeemed, Alice shares now: $(sh6 "$(q $VAULT 'balanceOf(address)(uint256)' $ALICE)")"
state "after redeem"

echo
echo "=============================================================="
echo " 6. Buffer drained -> redemption must fail loudly"
echo "=============================================================="
idle=$(q $VAULT 'idleAssets()(uint256)')
to_core "$idle"
set_core 2360000000000
rest=$(q $VAULT 'balanceOf(address)(uint256)' $ALICE)
if cast send $VAULT "redeem(uint256,address)" "$rest" $ALICE --rpc-url "$RPC" --private-key "$PK" >/dev/null 2>&1; then
  echo "  UNEXPECTED: redeem succeeded with an empty buffer"
else
  echo "  reverted as designed (InsufficientIdleLiquidity) - the CLAIM queue is not built yet"
fi

echo
echo "=============================================================="
echo " 7. Sharp drop -> liquidation, then restart"
echo "=============================================================="
set_px 947000
set_core 369000000000
state "post-liquidation"
echo "  Alice value : $(usd "$(q $VAULT 'convertToAssets(uint256)(uint256)' "$(q $VAULT 'balanceOf(address)(uint256)' $ALICE)")")"
send $USDC "mint(address,uint256)" $BOB 100000000000 --private-key "$PK"
send $VAULT "deposit(uint256,address)" 5000000000 $BOB --private-key "$PK2"
state "after post-liq deposit"
echo
echo "done."
