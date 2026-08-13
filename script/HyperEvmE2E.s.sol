// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {console2} from "forge-std/console2.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {PoolTest} from "test/fixtures/PoolTest.sol";
import {Pool} from "src/core/Pool.sol";
import {InitAddressParams, PoolConfigParams, IPool} from "src/interfaces/IPool.sol";
import {VerifierTransact21} from "src/verifiers/VerifierTransact21.sol";
import {VerifierTransact22} from "src/verifiers/VerifierTransact22.sol";
import {VerifierTransact23} from "src/verifiers/VerifierTransact23.sol";
import {VerifierRegister} from "src/verifiers/VerifierRegister.sol";
import {VerifierTreeUpdate} from "src/verifiers/VerifierTreeUpdate.sol";
import {Verifier, TransactionVerifierInfo} from "src/core/Verifier.sol";
import {AdaptorHandler} from "src/core/AdaptorHandler.sol";
import {IVerifier} from "src/interfaces/IVerifier.sol";
import {IAdaptorHandler} from "src/interfaces/IAdaptorHandler.sol";
import {IHasher} from "src/interfaces/IHasher.sol";
import {IScreener} from "src/interfaces/IScreener.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {MockPool} from "test/mocks/MockPool.sol";
import {MockScreener} from "test/mocks/MockScreener.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockERC20ForReentrancyTest} from "test/mocks/MockERC20ForReentrancyTest.sol";
import {MockAggregatorV3} from "test/mocks/MockAggregatorV3.sol";
import {FixtureLib} from "test/fixtures/Fixture.sol";
import {AssetType} from "src/libraries/AssetLogic.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransactionLogic.sol";
import {ShieldedAddressRegistrationData} from "src/libraries/ShieldedAddressLogic.sol";

/**
 * Full Veilnyx stack on HyperEVM: deploy, register, then a REAL private deposit and
 * withdrawal with on-chain Groth16 verification.
 *
 *   forge script script/HyperEvmE2E.s.sol:HyperEvmE2E --rpc-url $RPC --broadcast --slow
 *
 * The test harness cannot be reused verbatim for a live chain: BaseTest/PoolBaseTest
 * pass `address(this)` as the mock-token owner and the verifier manager, and a script
 * contract is ephemeral, so Foundry rejects it. This deploys the same stack with the
 * broadcasting EOA in those roles. PoolTest's chain-id branch for asset config is also
 * bypassed, so chain 998 needs no asset entry.
 */
contract HyperEvmE2E is PoolTest {
    function _deployAll(address me) internal {
        fixture = FixtureLib.load(vm);
        // Config is deliberately NOT deployed: it reads files via cheatcodes, which
        // cannot execute as a real transaction. Only wToken was needed from it, and
        // native-ETH deposits are out of scope here, so it stays unset.
        token1 = new MockERC20(me, 18);
        token2 = new MockERC20(me, 6);
        tokenReent = new MockERC20ForReentrancyTest(me, 18);

        addressTreeDepth = fixture.addressTreeDepth;
        commitmentTreeDepth = fixture.commitmentTreeDepth;

        VerifierTransact21 vt21 = new VerifierTransact21();
        VerifierTransact22 vt22 = new VerifierTransact22();
        VerifierTransact23 vt23 = new VerifierTransact23();
        VerifierRegister vr = new VerifierRegister();
        VerifierTreeUpdate vTreeUpdate = new VerifierTreeUpdate();

        TransactionVerifierInfo[] memory vInfos = new TransactionVerifierInfo[](3);
        vInfos[0] = TransactionVerifierInfo({id: 21, addr: address(vt21), selector: vt21.verifyProof.selector});
        vInfos[1] = TransactionVerifierInfo({id: 22, addr: address(vt22), selector: vt22.verifyProof.selector});
        vInfos[2] = TransactionVerifierInfo({id: 23, addr: address(vt23), selector: vt23.verifyProof.selector});

        verifier = new Verifier(vInfos, address(vr), address(vTreeUpdate), me);
        adaptorHandler = new AdaptorHandler();
        pool = new MockPool();
        screener = new MockScreener();
        hasher = _deployHasher();

        bytes memory initData = abi.encodeCall(
            Pool.initialize,
            (
                InitAddressParams({
                    verifier: IVerifier(address(verifier)),
                    adaptorHandler: IAdaptorHandler(address(adaptorHandler)),
                    screener: IScreener(address(screener)),
                    hasher: IHasher(address(hasher)),
                    // Pausing stays with the deploying EOA on a throwaway testnet
                    // deployment; zeroAddress would leave it owner-only.
                    pauser: me
                }),
                PoolConfigParams({
                    withdrawFeeBps: fixture.withdrawFeeBps,
                    tvlLimitUsd: type(uint256).max,
                    minDepositUsd: 0,
                    maxDepositUsd: type(uint256).max,
                    priceFeedStalenessThreshold: 1 days,
                    nativeWToken: IWToken(address(0))
                })
            )
        );
        ERC1967Proxy poolProxy = new ERC1967Proxy(address(pool), initData);
        pool = MockPool(payable(address(poolProxy)));
        adaptorHandler.setVeilnyxPool(IPool(address(pool)));

        // ---- assets, revoker, sender ----
        _defaultMockFeed = new MockAggregatorV3(int256(1e8), 8);

        address[] memory a = new address[](3);
        uint8[] memory p = new uint8[](3);
        AggregatorV3Interface[] memory f = new AggregatorV3Interface[](3);
        a[0] = address(token1); a[1] = address(token2); a[2] = address(tokenReent);
        p[0] = MockERC20(a[0]).decimals();
        p[1] = MockERC20(a[1]).decimals();
        p[2] = MockERC20(a[2]).decimals();
        f[0] = AggregatorV3Interface(address(_defaultMockFeed));
        f[1] = AggregatorV3Interface(address(_defaultMockFeed));
        f[2] = AggregatorV3Interface(address(_defaultMockFeed));

        pool.addAssets(AssetType.ERC20, _toAssetInitParams(a, p, f));
        asset1 = pool.getAsset(a[0]);
        asset2 = pool.getAsset(a[1]);

        pool.registerRevoker(fixture.revokerPublicKey, fixture.encryptionPublicKey, revokerMetaData);

        // The Pool recovers `publicAddress` from this EIP-712 signature and binds it
        // into the register proof (ShieldedAddressLogic:40-42), so it must be signed
        // by the key the fixture's proof was generated for. An arbitrary key recovers
        // a different address and the proof correctly rejects with InvalidAddressProof.
        // The signature cannot be lifted from the fixture either: the EIP-712 domain
        // covers chainId and the pool address, both of which differ here.
        bytes memory signature = _getRegisterAddressSignature(
            fixture.registrant.privateKey,
            bytes.concat(
                bytes32(fixture.sender.rootAddress),
                bytes32(fixture.sender.signPublicKey[0]),
                bytes32(fixture.sender.signPublicKey[1]),
                bytes32(fixture.sender.viewPublicKey[0]),
                bytes32(fixture.sender.viewPublicKey[1])
            )
        );
        ShieldedAddressRegistrationData memory reg =
            _loadShieldedAddressRegistrationData("register_sender");
        reg.signature = signature;
        pool.registerAddress(reg);
    }

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address me = vm.addr(pk);
        console2.log("deployer:", me);

        vm.startBroadcast(pk);

        _deployAll(me);
        console2.log("pool proxy:", address(pool));
        console2.log("verifier  :", address(verifier));

        uint256 d1 = 10000 ether;
        uint256 d2 = 10000e6;
        MockERC20(asset1.assetAddress).mint(me, d1);
        MockERC20(asset2.assetAddress).mint(me, d2);
        MockERC20(asset1.assetAddress).approve(address(pool), d1);
        MockERC20(asset2.assetAddress).approve(address(pool), d2);

        uint256 before = MockERC20(asset1.assetAddress).balanceOf(address(pool));

        pool.transact(_loadShieldedTransaction("deposit_pre_tx"));
        console2.log("DEPOSIT ok, pool asset1:", MockERC20(asset1.assetAddress).balanceOf(address(pool)));

        _processCommitmentTreeQueue();
        console2.log("commitment tree flushed");

        // Pair the withdraw with a fixture from the same post-ceremony regeneration as
        // deposit_pre_tx (commit 8a65d25). Fixtures are generated against the tree state
        // a specific deposit produces, so mixing generations yields a commitment tree
        // root the Pool has never seen and reverts with UnknownCommitmentTreeRoot.
        // withdraw_100_weth_without_fee predates the ceremony and fails for that reason,
        // as do 17 other fixtures still referenced by the suite.
        pool.transact(_loadShieldedTransaction("withdraw_10_weth_with_weth_fee"));
        uint256 aft = MockERC20(asset1.assetAddress).balanceOf(address(pool));
        console2.log("WITHDRAW ok, pool asset1:", aft);
        console2.log("net pool delta:", aft - before);

        vm.stopBroadcast();
    }
}
