#!/usr/bin/env python3
"""Check a set of proving keys (zkeys) against script/ceremony-manifest.json.

A wrong zkey cannot forge proofs, but every proof made with it fails on-chain
with InvalidTransactionProof. The verifying-key delta is the only thing that
distinguishes one phase-2 ceremony from another, so this reads each zkey's
Groth16 header (first 8 KB — a range request, not the full file) and compares
its delta and public-input count with the verifier the pool actually uses.

  python3 script/hyperevm/check-zkeys.py https://<circuits-host>/mainnet-circuits
  python3 script/hyperevm/check-zkeys.py /abs/path/to/mainnet-circuits
"""
import struct, json, sys, urllib.request
Q = 21888242871839275222246405745257275088696311157297823662689037894645226208583  # BN254 base field
RINV = pow(pow(2, 256, Q), -1, Q)
import os
man = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'ceremony-manifest.json')))
NAMES = {'register':'VerifierRegister','treeUpdate':'VerifierTreeUpdate', **{f'transact{k}':f'VerifierTransact{k}' for k in ['21','22','23','42','44','82','84']}}
def header(url):
    if url.startswith('/'):
        b = open(url,'rb').read(8192)
    else:
      req = urllib.request.Request(url, headers={'Range':'bytes=0-8191','User-Agent':'Mozilla/5.0 (Macintosh) veilnyx-zkey-audit'})
      b = urllib.request.urlopen(req, timeout=60).read()
    assert b[:4] == b'zkey', 'not a zkey'
    v, n = struct.unpack('<II', b[4:12]); off = 12
    for _ in range(n):
        t, sz = struct.unpack('<IQ', b[off:off+12]); off += 12
        if t == 2:
            h = b[off:off+sz]; break
        off += sz
    n8q = struct.unpack('<I', h[:4])[0]; o = 4 + n8q
    n8r = struct.unpack('<I', h[o:o+4])[0]; o += 4 + n8r
    nVars, nPub, dom = struct.unpack('<III', h[o:o+12]); o += 12
    o += 64 + 64 + 128 + 128 + 64          # alpha1, beta1, beta2, gamma2, delta1
    fe = lambda i: int.from_bytes(h[o+32*i:o+32*i+32], 'little') * RINV % Q
    return nPub, {str(fe(0)), str(fe(1))}
bad = 0
for c, v in NAMES.items():
    url = f'{sys.argv[1]}/{c}/keys.zkey'
    try:
        nPub, dx = header(url)
        ok = dx == {man[v]['deltax1'], man[v]['deltax2']} and nPub == man[v]['publicInputs']
    except Exception as e:
        print(f'{c:12s} ERROR {e}'); bad += 1; continue
    bad += not ok
    print(f'{c:12s} nPublic {nPub:3d}  {"MATCHES ceremony manifest" if ok else "WRONG KEY (not the live verifier)"}')
print('\nall 9 match the ceremony manifest' if bad == 0 else f'\n{bad} of 9 wrong or missing — do NOT point users at this set')
sys.exit(1 if bad else 0)
