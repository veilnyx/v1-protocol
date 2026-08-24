# Deployments — HyperEVM testnet (chain 998)

RPC `https://rpc.hyperliquid-testnet.xyz/evm` · deployer/owner/keeper for all of it:
`0xd5182b47388e0ffe14781b9dBb7E9b699624cA96` (admin). Last updated 2026-08-24.

## Veilnyx core stack (DeployHyperEvm.s.sol)

| contract | address |
|---|---|
| Pool proxy | `0x775f14F0c514F757950053463904Db0793Fd6A3e` |
| Pool implementation | `0xe99AEb49816ac6fd331bE786379a6B4AfAbA8670` |
| Verifier (router) | `0x3883549a4D83153d24a7a6B8ee1188296276B67F` |
| Hasher | `0xe1334b83972Fb6e551aFb874CCBc2485Ac36C415` |
| AdaptorHandler | `0xDd53dD059C667aeE9985D629490C19c080433845` |
| Gateway | `0x6AECF8D05aac25617F98ca4F930103bCaC14030a` |
| Paymaster | `0xE0e0695769311597B457d9EcD5FdaCD094619BA4` |
| MockScreener | `0x13Dd9C75f1014D72AbCcAc88d7f56089516D6C10` |
| MockAggregatorV3 (price feed) | `0xe93fd7Ebf16ab43f545e45a8e78f93EE47987d21` |
| VerifierRegister | `0x07C4AF904dc2829A128e0d44eEC204dc58135F42` |
| VerifierTreeUpdate | `0xbd803bd97810C700F42725729869D1AE32C95A8B` |
| VerifierTransact21 | `0x28B1eA279F28eDA374711c326Ca1e3f22fC67f0e` |
| VerifierTransact22 | `0xEA5342d4D1f265Da3FFb8AE14851369085d424f2` |
| VerifierTransact23 | `0xB7e7A5B8Ef9eD68BcfF3b13B6f1b1d2d9c2f7E1c` |
| VerifierTransact42 | `0x558Bc37942D1C19b91495b1B4D1095CD809fe75b` |
| VerifierTransact44 | `0x08b01d3db2f0b8DC31A8eA2dB66914d377967867` |
| VerifierTransact82 | `0xA7917E42188bE73722202A00bEFC39C8e85C80b1` |
| VerifierTransact84 | `0xE3526Ad9920Adb5Fb98b7F333B6FE4dc1cA7f862` |

## PerpVault — LIVE team-testing set (final bytecode, use this one)

| contract | address | pool asset id |
|---|---|---|
| **PerpVault "BTC Long 2x"** (= share token) | `0xE1d9d1d85308fdC87E1B1cA39a5660b7db56B5c8` | 65542 |
| CLAIM token | `0x31d634e23951508E8f498EE332Fc9B377501A482` | 65543 |
| PerpVaultAdaptor (whitelisted in Pool) | `0x00679D0f92D57b066401A8b04808c42Eb9A22d00` | — |
| tUSDC (mock, vault asset) | `0x8B090416f15508402ec8221614FAf472fC1503a0` | 65544 |
| tUSDC faucet (5,000/addr/hour) | `0x71190553443273e4fe79EdC5be1776334ac56Acd` | — |

Vault config: perp index 3 (BTC), coreTokenIndex 0 (USDC, `ALLOW_BROKEN_LINK` —
tUSDC is deliberately unlinked), target 2x, deposit cap 1,000,000 tUSDC.

## Retired drill contracts (do not use; some hold stranded testnet funds)

| contract | address | note |
|---|---|---|
| Vault v0 "BTC Long 2x" | `0x2B08C58dBD3afa43F04125087D4eEfCb6936D16f` | pre-audit bytecode; asset USD-T0 vs coreTokenIndex 0 — the misconfiguration the deploy script now rejects |
| Drill vault (liquidation drill) | `0xCC8e1dC62f92067E979E98C77Fd44aA0842198Ad` | pre-audit |
| Drill vault 2x | `0x3a0dD35f30C63C3A31b70f8c3203acD3c887A779` | holds ~40 real Core USDC, unrecoverable (windfall vault, no shares) |
| Drill vault 1x | `0x292331d85707E8EC9Ef8c69b0D02835662393023` | pre-P0; ~40 Core USDC + spot |
| P1 drill vault | `0x3899FadCe22c8CAeD6d808148e8a9f711450084e` | floored-size widening bug, superseded |
| P1b drill vault | `0x2024F614260025648ebC82498A61f3Fdd8D23b9F` | P1 gate drill; ~40 Core USDC |
| P2 vault | `0x22eadA81D357bEBAB306D08373a88e65C13B587d` | pre-invariant-fixes bytecode (asset ids 65540/65541) |
| P2 adaptor | `0x31B48E0cD2AE6f6aB9362cae7FEC4382CF4941EF` | points at P2 vault |
| SpotProbe | `0xcD4Cf6f9b8D75E527E78B0653C55228BC3117732` | proved contract spotSend works; drained |

## Pre-existing tokens referenced (not ours)

| token | address | pool asset id |
|---|---|---|
| WHYPE (native wrap) | `0x5555555555555555555555555555555555555555` | 65537 |
| USD-T0 / "TZERO" | `0x779Ded0c9e1022225f8E0630b35a9b54bE713736` | 65538 |
| UBTC | `0x09F83c5052784c63603184e016e1Db7a24626503` | 65539 |
| USDC evm link (Core token 0) | `0x0b80659a4076e9E93c7dBe0f10675A16a3E5C206` | dead proxy — every call reverts; why tUSDC exists |

## Local fixture addresses (anvil only, NOT deployed anywhere)

Proof-bound in `perp_vault_deposit_10_usdc`: adaptor
`0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE`, vault
`0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf` (deployCodeTo at test time).
