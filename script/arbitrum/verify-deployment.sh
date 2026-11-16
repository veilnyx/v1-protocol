#!/usr/bin/env bash
# Verify an Arbitrum One deployment record against this build and against the live Ethereum pool.
#
#   script/arbitrum/verify-deployment.sh <record.json> <arbitrum-rpc> [deployer-address]
#
# Checks:
#   1. Bytecode: every deployed contract equals this Hardhat build (script/arbitrum/compare-bytecode.py:
#      only library links, immutables and a library's own address are masked; metadata must match).
#   2. Wiring: proxy -> implementation, verifier router -> the 9 ceremony verifiers, hasher output,
#      AdaptorHandler -> pool.
#   3. Admin: owner/verifierManager = hardware wallet, pauser, paused, and the deployer holds no role.
#   4. Parity with Ethereum mainnet: revoker 0, assets, screener, limits, fee and tx-hash version.
set -uo pipefail
REC=$1; R=$2; DEPLOYER=${3:-}
ETH=https://ethereum-rpc.publicnode.com
ETH_POOL=0x4cecb7f987d220fe2e8608149fa76ed6d021ad11
OWNER=0xa285717BfD608468566bfBda742b56b1177494f7
PAUSER=0x50887b9a36E734cF861FE236fA6b4bE68D205113
SCREENER=0x40C57923924B5c5c5455c48D93317139ADDaC8fb
WETH=0x82aF49447D8a07e3bd95BD0d56f35241523fBab1
USDC=0xaf88d065e77c8cC2239327C5EDb3A432268e5831
fail=0
a() { python3 -c "import json;print(json.load(open('$REC'))['addresses']['$1'])"; }
# Lower-case, and drop cast's human-readable annotations such as "65537 [6.553e4]".
lc() { sed -E 's/ \[[^]]*\]//g' <<<"$1" | tr 'A-F' 'a-f'; }
check() { # label expected actual
  if [ "$(lc "$2")" = "$(lc "$3")" ]; then echo "PASS $1"; else echo "FAIL $1: expected $2, got $3"; fail=1; fi
}
call() { cast call "$@" --rpc-url "$R" 2>&1 | tail -1 | awk '{print $1}'; }

POOL=$(a poolProxy); IMPL=$(a poolImpl); V=$(a verifier); AH=$(a adaptorHandler); H=$(a hasher)

echo "== 1. bytecode vs this build"
python3 "$(dirname "$0")/compare-bytecode.py" "$R" \
  Pool=$IMPL AssetLogic=$(a assetLogic) BabyJubJubLogic=$(a babyJubJubLogic) MerkleTreeLogic=$(a merkleTreeLogic) \
  QueuedMerkleTreeLogic=$(a queuedMerkleTreeLogic) ShieldedAddressLogic=$(a shieldedAddressLogic) \
  ShieldedTransactionLogic=$(a shieldedTransactionLogic) AdaptorHandler=$AH Verifier=$V Hasher=$H PoolProxy=$POOL \
  VerifierRegister=$(a verifierRegister) VerifierTreeUpdate=$(a verifierTreeUpdate) \
  VerifierTransact21=$(a verifierTransact21) VerifierTransact22=$(a verifierTransact22) VerifierTransact23=$(a verifierTransact23) \
  VerifierTransact42=$(a verifierTransact42) VerifierTransact44=$(a verifierTransact44) VerifierTransact82=$(a verifierTransact82) \
  VerifierTransact84=$(a verifierTransact84) || fail=1

echo "== 2. wiring"
SLOT=0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
check "proxy implementation" "$IMPL" "0x$(cast storage $POOL $SLOT --rpc-url $R | tail -c 41)"
check "pool.verifier" "$V" "$(call $POOL 'verifier()(address)')"
check "pool.hasher" "$H" "$(call $POOL 'hasher()(address)')"
check "pool.adaptorHandler" "$AH" "$(call $POOL 'adaptorHandler()(address)')"
check "adaptorHandler.veilnyxPool" "$POOL" "$(call $AH 'veilnyxPool()(address)')"
check "router register verifier" "$(a verifierRegister)" "0x$(cast storage $V 2 --rpc-url $R | tail -c 41)"
check "router treeUpdate verifier" "$(a verifierTreeUpdate)" "0x$(cast storage $V 3 --rpc-url $R | tail -c 41)"
for id in 21 22 23 42 44 82 84; do
  got=$(cast call $V "getTransactionVerifier(uint16)((uint16,bytes4,address))" $id --rpc-url $R | grep -oE "0x[0-9a-fA-F]{40}")
  check "router transact$id verifier" "$(a verifierTransact$id)" "$got"
done
for inp in "[1,2]" "[1,2,3]"; do
  sig="hash(uint256[$( [ "$inp" = "[1,2]" ] && echo 2 || echo 3 )])(uint256)"
  check "hasher $inp == Ethereum hasher" "$(cast call $(cast call $ETH_POOL 'hasher()(address)' --rpc-url $ETH) "$sig" "$inp" --rpc-url $ETH | awk '{print $1}')" "$(call $H "$sig" "$inp")"
done

echo "== 3. admin"
check "pool.owner" $OWNER "$(call $POOL 'owner()(address)')"
check "verifier.owner" $OWNER "$(call $V 'owner()(address)')"
check "verifier.verifierManager" $OWNER "$(call $V 'verifierManager()(address)')"
check "adaptorHandler.owner" $OWNER "$(call $AH 'owner()(address)')"
check "gateway.owner" $OWNER "$(call $(a gateway) 'owner()(address)')"
check "paymaster.owner" $OWNER "$(call $(a paymaster) 'owner()(address)')"
check "pool.pauser" $PAUSER "$(call $POOL 'pauser()(address)')"
check "pool.paused" true "$(call $POOL 'paused()(bool)')"
if [ -n "$DEPLOYER" ]; then
  for c in $POOL $V $AH $(a gateway) $(a paymaster); do
    o=$(call $c 'owner()(address)'); [ "$(lc $o)" = "$(lc $DEPLOYER)" ] && { echo "FAIL deployer still owns $c"; fail=1; }
  done
  [ "$(lc $(call $POOL 'pauser()(address)'))" = "$(lc $DEPLOYER)" ] && { echo "FAIL deployer is pauser"; fail=1; }
  [ "$(lc $(call $V 'verifierManager()(address)'))" = "$(lc $DEPLOYER)" ] && { echo "FAIL deployer is verifierManager"; fail=1; }
  echo "PASS deployer $DEPLOYER holds no owner/pauser/verifierManager role"
fi

echo "== 4. parity with Ethereum mainnet pool"
REV='getRevokerData(uint256)((uint16,bool,uint256[2],uint256[2]))'
check "revoker 0 == Ethereum revoker 0" "$(cast call $ETH_POOL "$REV" 0 --rpc-url $ETH)" "$(cast call $POOL "$REV" 0 --rpc-url $R)"
check "screener (Chainalysis on Arbitrum)" $SCREENER "$(call $POOL 'screener()(address)')"
check "nativeWToken" $WETH "$(call $POOL 'nativeWToken()(address)')"
ASSET='getAsset(uint24)((uint24,uint8,address,bool,uint8,address,uint8))'
check "asset 65537 (WETH, 18, active, ETH/USD feed)" "(65537, 1, $WETH, true, 18, 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612, 8)" "$(cast call $POOL "$ASSET" 65537 --rpc-url $R)"
check "asset 65538 (USDC, 6, active, USDC/USD feed)" "(65538, 1, $USDC, true, 6, 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3, 8)" "$(cast call $POOL "$ASSET" 65538 --rpc-url $R)"
for fn in 'withdrawFeeBps()(uint256)' 'minDepositUsd()(uint256)' 'maxDepositUsd()(uint256)' 'tvlLimitUsd()(uint256)' 'txHashVersion()(uint8)' 'priceFeedStalenessThreshold()(uint256)'; do
  check "$fn == Ethereum" "$(cast call $ETH_POOL "$fn" --rpc-url $ETH | awk '{print $1}')" "$(call $POOL "$fn")"
done
echo "     commitment tree: $(cast call $POOL 'getCommitmentTreeState()' --rpc-url $R | cut -c1-20)…  version: $(call $POOL 'version()(uint256)')"

echo; [ $fail = 0 ] && echo "DEPLOYMENT OK" || { echo "DEPLOYMENT HAS FAILURES"; exit 1; }
