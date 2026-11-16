#!/usr/bin/env python3
"""Compare runtime bytecode of this Hardhat build against deployed contracts.

Usage: compare-bytecode.py <rpc> <Name=address> [<Name=address> ...]

Masks ONLY what legitimately differs per deployment:
  - linked-library address slots (deployedLinkReferences),
  - immutable slots (immutableReferences),
  - a library's own address (PUSH20 at offset 1, its call-protection guard).
Everything else, including the CBOR metadata hash at the end (which commits to the exact
source files and compiler settings), must match byte for byte.
"""
import json, re, sys, glob, urllib.request

def rpc(url, method, params):
    req = urllib.request.Request(url, json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                                 {"content-type": "application/json", "user-agent": "curl/8.0"})
    return json.load(urllib.request.urlopen(req, timeout=60))["result"]

def build_outputs():
    out = {}
    for f in glob.glob("artifacts/build-info/*.json"):
        bi = json.load(open(f))
        for path, contracts in bi["output"]["contracts"].items():
            for name, c in contracts.items():
                out[(path, name)] = c["evm"]["deployedBytecode"]
    return out

def find(outputs, name):
    hits = [(p, n) for (p, n) in outputs if n == name and p.startswith("src/")]
    if len(hits) != 1:
        raise SystemExit(f"{name}: expected one src/ contract, found {hits}")
    return outputs[hits[0]]

def mask_ranges(db):
    ranges = []
    for libs in db.get("linkReferences", {}).values():
        for refs in libs.values():
            ranges += [(r["start"], r["length"]) for r in refs]
    for refs in db.get("immutableReferences", {}).values():
        ranges += [(r["start"], r["length"]) for r in refs]
    return ranges

def main():
    url, pairs = sys.argv[1], sys.argv[2:]
    outputs = build_outputs()
    bad = 0
    for pair in pairs:
        name, addr = pair.split("=")
        db = find(outputs, name)
        # Library placeholders are 40-char __$hash$__ tokens; zero them (they are masked below anyway).
        local = bytearray(bytes.fromhex(re.sub(r"__\$[0-9a-f]{34}\$__", "0" * 40, db["object"])))
        live = bytearray(bytes.fromhex(rpc(url, "eth_getCode", [addr, "latest"])[2:]))
        if len(local) != len(live):
            print(f"MISMATCH {name} @ {addr}: length local {len(local)} live {len(live)}"); bad += 1; continue
        ranges = mask_ranges(db)
        is_library = local[0] == 0x73  # PUSH20 <own address> call guard
        if is_library:
            ranges.append((1, 20))
        for s, l in ranges:
            local[s:s+l] = b"\0" * l
            live[s:s+l] = b"\0" * l
        if local == live:
            print(f"IDENTICAL {name} @ {addr} ({len(live)} bytes, {len(ranges)} masked slots incl. metadata kept)")
        else:
            diffs = [i for i in range(len(live)) if local[i] != live[i]]
            print(f"MISMATCH {name} @ {addr}: {len(diffs)} bytes differ, first at {diffs[0]}"); bad += 1
    sys.exit(1 if bad else 0)

if __name__ == "__main__":
    main()
