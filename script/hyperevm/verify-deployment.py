#!/usr/bin/env python3
"""Prove a HyperEVM deployment is exactly this commit's build, and is wired correctly.

Needs no other chain. Reads the deployment record written by deployCoreWithAdp.ts and, for
every contract, compares the on-chain runtime bytecode with this checkout's Hardhat artifacts
(`npx hardhat compile` first). Only per-chain values may differ, and only at the offsets the
compiler reports for them:
  - library links (deployedLinkReferences), filled with the addresses from the record;
  - immutables (build-info immutableReferences), whose values are then checked separately;
  - a library's call-protection self-address (bytes 1..20).
Metadata is compared too, so IDENTICAL means "built from this source with these settings".
The Poseidon contracts are raw bytecode (src/poseidon/t*.txt): their runtime is obtained by
executing that init code with eth_call and compared the same way.

Then checks the wiring: proxy implementation, the Pool's verifier/hasher/adaptor handler and
native token, every verifier registered in the Verifier router, and the immutables of the
Pool, Gateway, Paymaster and Hasher.

Any FAIL means the deployment must not be used. Requires foundry's `cast`.

  python3 script/hyperevm/verify-deployment.py deployments/hyperevm-999.json --rpc $RPC_HYPEREVM_MAINNET
"""
import argparse, glob, json, os, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
WHYPE = "0x5555555555555555555555555555555555555555"
LIBRARIES = {"AssetLogic", "MerkleTreeLogic", "QueuedMerkleTreeLogic", "ShieldedAddressLogic",
             "ShieldedTransactionLogic"}
TX_VERIFIER_IDS = [21, 22, 23, 42, 44, 82, 84]

fails = 0


def check(label, ok, detail=""):
    global fails
    fails += not ok
    print(f"  {'PASS' if ok else 'FAIL'}  {label}{'  ' + detail if detail else ''}")


def cast(*args, rpc):
    out = subprocess.run(["cast", args[0], "--rpc-url", rpc, *args[1:]], capture_output=True, text=True)
    if out.returncode != 0:
        raise RuntimeError(f"cast {' '.join(args[:2])}: {out.stderr.strip()}")
    return out.stdout.strip()


def addr(x):
    return "0x" + x.lower()[-40:]


def artifact(name):
    hits = [f for f in glob.glob(os.path.join(ROOT, "artifacts", "src", "**", f"{name}.json"), recursive=True)
            if not f.endswith(".dbg.json")]
    if len(hits) != 1:
        sys.exit(f"{name}: expected one artifact, found {len(hits)} (run `npx hardhat compile`)")
    a = json.load(open(hits[0]))
    dbg = json.load(open(hits[0][:-5] + ".dbg.json"))
    bi = json.load(open(os.path.normpath(os.path.join(os.path.dirname(hits[0]), dbg["buildInfo"]))))
    evm = bi["output"]["contracts"][a["sourceName"]][a["contractName"]]["evm"]["deployedBytecode"]
    return a, evm.get("immutableReferences", {})


def expected_and_masked(name, onchain, rec):
    """Returns (expected, onchain) hex without 0x, per-chain bytes masked, plus immutable values."""
    a, imm = artifact(name)
    exp = a["deployedBytecode"][2:].lower()
    on = onchain[2:].lower()
    for refs in a["deployedLinkReferences"].values():
        for lib, offs in refs.items():
            key = lib[0].lower() + lib[1:]
            for o in offs:
                s = o["start"] * 2
                exp = exp[:s] + rec[key][2:].lower() + exp[s + 40:]
    values = []
    for offs in imm.values():
        for o in offs:
            s, n = o["start"] * 2, o["length"] * 2
            values.append("0x" + on[s:s + n])
            on = on[:s] + "0" * n + on[s + n:]
            exp = exp[:s] + "0" * n + exp[s + n:]
    if name in LIBRARIES:
        on, exp = on[:2] + "0" * 40 + on[42:], exp[:2] + "0" * 40 + exp[42:]
    return exp, on, values


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("record", help="deployments/<network>-999.json from deployCoreWithAdp.ts")
    ap.add_argument("--rpc", required=True, help="RPC of the chain the record describes")
    a = ap.parse_args()
    rpc = a.rpc
    rec = {k: v.lower() for k, v in json.load(open(a.record))["addresses"].items()}

    print("Bytecode (on-chain vs this build):")
    immutables = {}
    for key, address in rec.items():
        onchain = cast("code", address, rpc=rpc)
        if onchain in ("0x", ""):
            check(f"{key:26s}", False, f"NO CODE at {address}")
            continue
        if key.startswith("poseidonT"):
            init = open(os.path.join(ROOT, "src", "poseidon", f"t{key[-1]}.txt")).read().strip()
            runtime = cast("call", "--create", init, rpc=rpc)
            check(f"{key:26s}", onchain.lower() == runtime.lower(), f"{len(onchain) // 2 - 1} B")
            continue
        name = {"poolImpl": "Pool", "poolProxy": "PoolProxy"}.get(key, key[0].upper() + key[1:])
        exp, on, values = expected_and_masked(name, onchain, rec)
        immutables[key] = {addr(v) for v in values}
        check(f"{key:26s}", exp == on, f"{len(on) // 2} B")

    print("Wiring:")
    call = lambda target, sig, *args: cast("call", target, sig, *[str(x) for x in args], rpc=rpc)
    pool = rec["poolProxy"]
    impl = addr(cast("storage", pool, "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc", rpc=rpc))
    check("proxy implementation = poolImpl", impl == rec["poolImpl"], impl)
    check("Pool __self immutable = poolImpl", immutables.get("poolImpl") == {rec["poolImpl"]})
    for getter, key in [("verifier()(address)", "verifier"), ("hasher()(address)", "hasher"),
                        ("adaptorHandler()(address)", "adaptorHandler")]:
        v = call(pool, getter).lower()
        check(f"pool.{getter.split('(')[0]} = {key}", v == rec[key], v)
    nw = call(pool, "nativeWToken()(address)").lower()
    check("pool.nativeWToken = WHYPE", nw == WHYPE, nw)
    a1 = call(pool, "getAsset(uint24)((uint24,uint8,address,bool,uint8,address,uint8))", 65537)
    check("asset 65537 = WHYPE (Paymaster GAS_ASSET_ID)", WHYPE in a1.lower(), a1[:80])

    ver = rec["verifier"]
    for vid in TX_VERIFIER_IDS:
        info = call(ver, "getTransactionVerifier(uint16)((uint16,bytes4,address))", vid).lower()
        check(f"verifier id {vid} -> verifierTransact{vid}", rec[f"verifierTransact{vid}"] in info, info)
    manager = call(ver, "verifierManager()(address)").lower()
    slot = lambda n: addr(cast("storage", ver, str(n), rpc=rpc))
    check("Verifier layout (slot 4 = verifierManager)", slot(4) == manager)
    check("register verifier -> verifierRegister", slot(2) == rec["verifierRegister"], slot(2))
    check("tree-update verifier -> verifierTreeUpdate", slot(3) == rec["verifierTreeUpdate"], slot(3))

    gw, pm = rec["gateway"], rec["paymaster"]
    ep = call(pm, "entryPoint()(address)").lower()
    check("paymaster.pool = poolProxy", call(pm, "pool()(address)").lower() == pool)
    check("paymaster.sender = gateway", call(pm, "sender()(address)").lower() == gw)
    check("paymaster immutables = {entryPoint, gateway, pool}", immutables.get("paymaster") == {ep, gw, pool})
    check("gateway.pool = poolProxy", call(gw, "pool()(address)").lower() == pool)
    check("gateway.entryPoint = paymaster.entryPoint", call(gw, "entryPoint()(address)").lower() == ep, ep)
    check("gateway.nativeWToken = WHYPE", call(gw, "nativeWToken()(address)").lower() == WHYPE)
    check("gateway immutables = {entryPoint, pool, WHYPE}", immutables.get("gateway") == {ep, pool, WHYPE})
    poseidons = {rec["poseidonT3"], rec["poseidonT4"], rec["poseidonT5"]}
    check("hasher immutables are the deployed Poseidon contracts", bool(immutables.get("hasher"))
          and immutables["hasher"] <= poseidons, str(sorted(immutables.get("hasher", []))))

    if fails:
        sys.exit(f"\n{fails} check(s) FAILED — do NOT use this deployment")
    print(f"\nDEPLOYMENT OK: {len(rec)} contracts identical to this build, wiring verified")


if __name__ == "__main__":
    main()
