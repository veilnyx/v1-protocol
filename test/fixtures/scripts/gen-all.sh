#!/usr/bin/env bash
# Regenerate every fixture, in dependency order, ONE PROCESS PER GENERATOR: the mock
# commitment tree is module-global, so generators sharing a process would place notes at the
# wrong leaf indices. Needed whenever the circuits or keys change (later fixtures decrypt the
# notes of the deposit fixtures they spend).
#   FIXTURE_CIRCUITS=<circuits artifacts dir> test/fixtures/scripts/gen-all.sh
set -euo pipefail
cd "$(dirname "$0")/../../.."
for g in deposits deposits4x2 reentrantDeposit transfers transfers4x2 transfers4x4 packedUserOp \
         withdrawals withdrawalsFromPreTx withdrawalsFromTestnetWeth reentrantWithdraw callAdaptors morphoSupply morphoWithdraw register treeUpdate; do
  echo "== $g"
  npx ts-node test/fixtures/scripts/index.ts "$g"
done
echo "== erc4337 effective fee"
npx ts-node test/fixtures/scripts/genERC4337EffectiveGasPriceFee.ts
