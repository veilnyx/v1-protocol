# Audit Scope - Veilnyx

## Overview
Veilnyx is a compliant-privacy protocol enabled by ZK and threshold cryptography at its core.

### Key Features
1. Multi-asset privacy pool
2. Fully private P-2-P transfers
3. Gas fee in any asset of choice ( should be supported by the protocol )
4. Involuntary Compliance protected by Threshold privacy (Revoker + Guardian network)
5. Voluntary compliance
6. Reduced proof verification costs through proof aggregation (developed but not shipping)

## Scope Details
| Contract              | SLOC  | Purpose | Ext. Libraries Used |
|-----------------------|------ |---------|----------------|
| src/core/AdaptorHandler.sol    | 57   | Handle calls to external protocol adaptors. | OpenZeppelin
| src/core/Gateway.sol         | 68 | Acts as a gateway contract to the core protocol contracts. Decides whehter to route the tx to Mempool or the Pool directly, perform wrapping of assets, etc. | Openzeppelin, Account-abstraction | 
|  src/core/Hasher.sol         | 37 | Maintains the addresses of each poseidon contract and calls the right one, based on the size of inputs to be hashed. | - |
| src/core/Paymaster.sol  | 163 | Enables users to pay gas fees in any asset of choice thats supported by the Veilnyx protocol. | Openzeppelin, Chainlink, Account-abstraction |
| src/core/Pool.sol | 334 | The implementation of the multi-asset Veilnyx Pool contract (upgradeable). | Openzeppelin
| src/core/PoolProxy.sol | 8 | UUPS proxy contract for the Veilnyx Pool. | Openzeppelin
| src/core/Verifier.sol | 79 | Registry and call dispatcher for all Veilnyx's ZK proof verifiers. | -
| libraries/Asset.sol | 148 | Provides multi-asset ops like adding, updating, transfering, receiving and checkers |  Openzeppelin
| libraries/MerkleTree.sol | 206 | Leaf insertion logic for Merkle-tree | -
| libraries/QueuedMerkleTree.sol | 200 | Merkle tree root update using ZK representing insertion of multiple leaves together | - |
| libraries/ShieldedAddress.sol | 124 | Validates and manages Shielded address registration using ZK |  Openzeppelin
| libraries/ShieldedTransaction.sol | 619 | Validates and executes Shielded Transaction (STX) | - |
| base/AdaptorBase.sol | 36|  Base contract for AdaptorHandler | - |
| base/Constants.sol | 10 | Provides the constant value used in Veilnyx protocol | - |
| base/PoolStorage.sol | 32 | Holds the Pool contract storage vars and their respective slots | - |
| adaptors/uniswap-v3 | 83 | Adaptor for Uniswap V3 protocol | Openzeppelin |
| adaptors/aave-v3/AaveV3Adaptor.sol | 121 | Adaptor for Aave V3 protocol | Openzeppelin |
| adaptors/beefy-v7/BeefyV7Adaptor.sol | 90 | Adaptor for Beefy V7 protocol | Openzeppelin |
| adaptors/curveNG/CurveNGAdaptor.sol | 470 | Adaptor for Curve protocol| Openzeppelin |
| adaptors/ethena/EthenaAdaptor.sol | 47 | Adaptor for Ethena protocol | Openzeppelin |
| adaptors/lido/LidoAdaptor.sol | 116 | Adaptor for Lido staking | Openzeppelin |
| adaptors/morpho/MorphoVaultAdaptor.sol | 95 | Adaptor for Morpho protocol | Openzeppelin |
| adaptors/oneInch-v6/OneInchAdaptor.sol | 53 | Adaptor for 1Inch protocol | Openzeppelin |
| adaptors/rocketpool/RocketPoolAdaptor.sol | 133 | Adaptor for RocketPool protocol | Openzeppelin |
| src/interfaces/ | 280 | Interfaces of Veilnyx protocol | - |
| src/poseidon/ | - | Contains poseidon hash bytecodes for diff. input sizes | iden3/circomlibjs |
| Total SLOC | 3,609 | 

### Out of Scope
- List of contracts/files excluded from audit
  - src/core/Mempool.sol
  - src/core/MempoolProxy.sol
  - src/core/Screener.sol
  - src/libraries/EIP712.sol [TODO: Merge PR #16](https://github.com/veilnyx/v1-protocol/pull/16)
  - src/libraries/MempoolValidator.sol
  - src/base/MempoolStorage.sol
  - src/verifiers (Will be covered by ZK circuit audits)
- Audited Third-party dependencies
  - @openzeppelin
  - @account-abstraction
  - @chainlink
- Known issues

### Roles & Actors
| Role | Privileges | Restrictions |
|------|-----------|--------------|
| Admin | 1. Can upgrade the implementation logic <br> 2. Can pause protocol operations <br> 3. Add asset support <br> 4. Add external protocol adaptor support <br> 5. Register new revokers and modify existing revoker's status <br> 6. Withdraw protocol fees <br> 7. Set and update protocol fees <br> 8. Update verification tracker service | Cannot transact |
| User | Can transact: deposit, transfer, withdraw, call external protocols privately | Cannot control protocol level ops |
| Revoker | Can revoke transaction | Cannot decrypt tx without the threshold no. of permissions received from the guardian network |
| Guardian | Can contribute to a revoke request by providing cryptographic permission | Cannot decrypt tx alone 


## Known Issues / Accepted Risks
- Pre-verification using Nebra is not working since Nebra is down. 

## Areas of Focus / Concern / Known issues
- Revoker can make themselves immune to involuntary compliance. Fix is to prevent revokers from transacting on the protocol.
- Available Circuits: When transacting with high amounts, the no. of input notes can grow, and the circuits should be available to support that.
- UTXO algorithm
- ZK proof verification
- Compliance logic
- Complex logic sections

## Setup & Testing

### Installation
```bash
pnpm install
```

### Running Tests

### Generating fixtures (creates STX using SDK through FFI)
```bash
pnpm test:prepare
```

### Run test using generated fixture
```bash
forge test --mt test_weth_deposit
```

### Coverage
```bash
forge coverage
```

## Commit Hash
`0dae69fef05dc1bac3cf4da04ab4ffc4fb50077a`

## Deployment Chain(s)
- Ethereum Sepolia
- etc