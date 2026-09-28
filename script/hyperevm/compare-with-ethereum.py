#!/usr/bin/env python3
"""Prove a HyperEVM deployment is byte-for-byte the live Ethereum pool.

Reads the deployment record written by deployCoreWithAdp.ts and compares every
contract's runtime bytecode on the target chain with its live Ethereum twin
(script/hyperevm/ethereum-reference.json). The only bytes allowed to differ are
the per-chain addresses baked into the code — library links, immutables
(pool / gateway / Poseidon addresses, the UUPS self-address) and the wrapped
native token (WETH on Ethereum, WHYPE on HyperEVM) — so each chain's own
addresses are masked out before comparing.

Any DIFFERS line means the deployed contract is NOT the audited Ethereum code.

Requires foundry's `cast`.

  python3 script/hyperevm/compare-with-ethereum.py deployments/hyperevm-999.json \
      --rpc $RPC_HYPEREVM_MAINNET --eth-rpc https://ethereum-rpc.publicnode.com
"""
import argparse, json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
WHYPE = "5555555555555555555555555555555555555555"

# ethereum-reference.json name -> deployment-record key
KEYS = {
    "PoolProxy": "poolProxy", "Pool": "poolImpl", "Verifier": "verifier", "Hasher": "hasher",
    "AdaptorHandler": "adaptorHandler", "Gateway": "gateway", "Paymaster": "paymaster",
    "AssetLogic": "assetLogic", "MerkleTreeLogic": "merkleTreeLogic",
    "QueuedMerkleTreeLogic": "queuedMerkleTreeLogic", "ShieldedAddressLogic": "shieldedAddressLogic",
    "ShieldedTransactionLogic": "shieldedTransactionLogic",
    "PoseidonT3": "poseidonT3", "PoseidonT4": "poseidonT4", "PoseidonT5": "poseidonT5",
}


def code(addr, rpc):
    out = subprocess.run(["cast", "code", addr, "--rpc-url", rpc], capture_output=True, text=True)
    if out.returncode != 0:
        raise RuntimeError(f"cast code {addr}: {out.stderr.strip()}")
    return out.stdout.strip().lower()


def mask(c, addrs):
    for a in addrs:
        c = c.replace(a, "0" * 40)
    return c


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("record", help="deployments/<network>-999.json from deployCoreWithAdp.ts")
    ap.add_argument("--rpc", required=True, help="RPC of the chain the record describes")
    ap.add_argument("--eth-rpc", default="https://ethereum-rpc.publicnode.com")
    a = ap.parse_args()

    ref = json.load(open(os.path.join(HERE, "ethereum-reference.json")))
    live = ref["contracts"]
    rec = json.load(open(a.record))["addresses"]

    names = sorted(live, key=lambda n: (n.startswith("Verifier"), n))
    mapped = {}
    for n in names:
        key = KEYS.get(n) or (n[0].lower() + n[1:])
        if key not in rec:
            sys.exit(f"{n}: no '{key}' in {a.record}")
        mapped[n] = rec[key]

    eth_mask = [x.lower()[2:] for x in live.values()] + [ref["wrappedNative"].lower()[2:]]
    new_mask = [x.lower()[2:] for x in mapped.values()] + [WHYPE]

    bad = 0
    for n in names:
        lc, nc = code(live[n], a.eth_rpc), code(mapped[n], a.rpc)
        if nc in ("0x", ""):
            print(f"{n:26s} NO CODE at {mapped[n]}")
            bad += 1
            continue
        ok = mask(lc, eth_mask) == mask(nc, new_mask)
        bad += not ok
        print(f"{n:26s} {len(nc) // 2:6d} B  {'IDENTICAL' if ok else 'DIFFERS'}")

    if bad:
        sys.exit(f"\n{bad} contract(s) differ from the live Ethereum pool — do NOT unpause")
    print(f"\n{len(names)} contracts IDENTICAL to the live Ethereum pool (per-chain addresses masked)")


if __name__ == "__main__":
    main()
