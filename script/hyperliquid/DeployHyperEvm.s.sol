// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Pool} from "src/core/Pool.sol";
import {InitAddressParams, PoolConfigParams, IPool} from "src/interfaces/IPool.sol";
import {Verifier, TransactionVerifierInfo} from "src/core/Verifier.sol";
import {AdaptorHandler} from "src/core/AdaptorHandler.sol";
import {Gateway} from "src/core/Gateway.sol";
import {Paymaster} from "src/core/Paymaster.sol";
import {Hasher} from "src/core/Hasher.sol";
import {IPoseidon} from "src/interfaces/IPoseidon.sol";
import {IVerifier} from "src/interfaces/IVerifier.sol";
import {IAdaptorHandler} from "src/interfaces/IAdaptorHandler.sol";
import {IHasher} from "src/interfaces/IHasher.sol";
import {IScreener} from "src/interfaces/IScreener.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {AssetType, AssetInitParams} from "src/libraries/AssetLogic.sol";

import {VerifierRegister} from "src/verifiers/VerifierRegister.sol";
import {VerifierTreeUpdate} from "src/verifiers/VerifierTreeUpdate.sol";
import {VerifierTransact21} from "src/verifiers/VerifierTransact21.sol";
import {VerifierTransact22} from "src/verifiers/VerifierTransact22.sol";
import {VerifierTransact23} from "src/verifiers/VerifierTransact23.sol";
import {VerifierTransact42} from "src/verifiers/VerifierTransact42.sol";
import {VerifierTransact44} from "src/verifiers/VerifierTransact44.sol";
import {VerifierTransact82} from "src/verifiers/VerifierTransact82.sol";
import {VerifierTransact84} from "src/verifiers/VerifierTransact84.sol";

import {MockScreener} from "test/mocks/MockScreener.sol";
import {MockAggregatorV3} from "test/mocks/MockAggregatorV3.sol";

/// @title Full Veilnyx deployment for HyperEVM testnet (chain 998)
/// @notice Unlike HyperEvmE2E, this deploys the COMPLETE stack — all seven transact
///         verifiers, Gateway and Paymaster — and registers real linked tokens
///         rather than mocks, so a frontend can be pointed at it.
///
/// TESTNET ONLY. Every verifier here was generated locally with the compiler's
/// hardcoded `echo "test"` entropy, so the toxic waste is public and anyone can
/// forge proofs. This must never be pointed at a mainnet deployment path.
///
/// Requires `use_big_blocks(True)` on the deploying address first: the verifiers do
/// not fit in HyperEVM's 3M-gas small blocks, and the address must already be a
/// HyperCore user for that action to be accepted.
///
/// Run:
///   PRIVATE_KEY=0x... forge script script/hyperliquid/DeployHyperEvm.s.sol:DeployHyperEvm \
///     --rpc-url https://rpcs.chain.link/hyperevm/testnet --broadcast --slow --non-interactive
contract DeployHyperEvm is Script {
    // ---- external, verified present on chain 998 ----
    address constant ENTRY_POINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032; // v0.7
    address constant WHYPE = 0x5555555555555555555555555555555555555555;

    /// @dev The linked USDC ERC20 (token index 0) is a proxy whose implementation
    ///      reverts on every call on testnet, so it is unusable. TZERO is the
    ///      substitute: symbol USD_T0, 6 EVM decimals over 8 Core decimals, i.e.
    ///      the same 100x bridge scale USDC would have had.
    address constant TZERO = 0x779Ded0c9e1022225f8E0630b35a9b54bE713736;
    address constant UBTC = 0x09F83c5052784c63603184e016e1Db7a24626503;

    struct Deployed {
        address poolProxy;
        address poolImpl;
        address verifier;
        address hasher;
        address adaptorHandler;
        address gateway;
        address paymaster;
        address screener;
        address feed;
        address[9] verifiers;
    }

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address me = vm.addr(pk);
        console2.log("deployer:", me);
        console2.log("chain   :", block.chainid);

        Deployed memory d;

        vm.startBroadcast(pk);

        d.hasher = address(_deployHasher());
        (d.verifier, d.verifiers) = _deployVerifiers(me);

        d.adaptorHandler = address(new AdaptorHandler());
        d.screener = address(new MockScreener());
        d.poolImpl = address(new Pool());

        bytes memory initData = abi.encodeCall(
            Pool.initialize,
            (
                InitAddressParams({
                    verifier: IVerifier(d.verifier),
                    adaptorHandler: IAdaptorHandler(d.adaptorHandler),
                    screener: IScreener(d.screener),
                    hasher: IHasher(d.hasher),
                    pauser: me
                }),
                PoolConfigParams({
                    withdrawFeeBps: 5,
                    tvlLimitUsd: type(uint256).max,
                    minDepositUsd: 0,
                    maxDepositUsd: type(uint256).max,
                    priceFeedStalenessThreshold: 1 days,
                    nativeWToken: IWToken(WHYPE)
                })
            )
        );
        d.poolProxy = address(new ERC1967Proxy(d.poolImpl, initData));
        AdaptorHandler(payable(d.adaptorHandler)).setVeilnyxPool(IPool(d.poolProxy));

        // ERC-4337. EntryPoint v0.6/0.7/0.8 are all live on 998; v0.7 is used here.
        d.gateway = address(new Gateway(IEntryPoint(ENTRY_POINT), IWToken(WHYPE), IPool(d.poolProxy)));
        d.paymaster = address(new Paymaster(IEntryPoint(ENTRY_POINT), d.gateway, IPool(d.poolProxy), 1 days));

        // Chainlink publishes no feeds on this testnet, so a flat mock stands in.
        // The Pool only reads feeds for the TVL limit, which is uncapped here.
        d.feed = address(new MockAggregatorV3(int256(1e8), 8));

        _registerAssets(d.poolProxy, d.feed);
        _registerRevoker(d.poolProxy);
        Pool(payable(d.poolProxy)).setVersion(1);

        vm.stopBroadcast();

        _report(d);
    }

    function _deployVerifiers(address me) internal returns (address registry, address[9] memory v) {
        VerifierRegister vr = new VerifierRegister();
        VerifierTreeUpdate vtu = new VerifierTreeUpdate();
        VerifierTransact21 v21 = new VerifierTransact21();
        VerifierTransact22 v22 = new VerifierTransact22();
        VerifierTransact23 v23 = new VerifierTransact23();
        VerifierTransact42 v42 = new VerifierTransact42();
        VerifierTransact44 v44 = new VerifierTransact44();
        VerifierTransact82 v82 = new VerifierTransact82();
        VerifierTransact84 v84 = new VerifierTransact84();

        TransactionVerifierInfo[] memory infos = new TransactionVerifierInfo[](7);
        infos[0] = TransactionVerifierInfo({id: 21, addr: address(v21), selector: v21.verifyProof.selector});
        infos[1] = TransactionVerifierInfo({id: 22, addr: address(v22), selector: v22.verifyProof.selector});
        infos[2] = TransactionVerifierInfo({id: 23, addr: address(v23), selector: v23.verifyProof.selector});
        infos[3] = TransactionVerifierInfo({id: 42, addr: address(v42), selector: v42.verifyProof.selector});
        infos[4] = TransactionVerifierInfo({id: 44, addr: address(v44), selector: v44.verifyProof.selector});
        infos[5] = TransactionVerifierInfo({id: 82, addr: address(v82), selector: v82.verifyProof.selector});
        infos[6] = TransactionVerifierInfo({id: 84, addr: address(v84), selector: v84.verifyProof.selector});

        registry = address(new Verifier(infos, address(vr), address(vtu), me));
        v = [
            address(vr),
            address(vtu),
            address(v21),
            address(v22),
            address(v23),
            address(v42),
            address(v44),
            address(v82),
            address(v84)
        ];
    }

    function _registerAssets(address pool, address feed) internal {
        AssetInitParams[] memory p = new AssetInitParams[](3);
        p[0] = AssetInitParams({assetAddress: WHYPE, precision: 18, usdPriceFeed: AggregatorV3Interface(feed)});
        p[1] = AssetInitParams({assetAddress: TZERO, precision: 6, usdPriceFeed: AggregatorV3Interface(feed)});
        p[2] = AssetInitParams({assetAddress: UBTC, precision: 8, usdPriceFeed: AggregatorV3Interface(feed)});
        Pool(payable(pool)).addAssets(AssetType.ERC20, p);
    }

    /// @dev Keys come from test/fixtures/config.json so the deployment stays in step
    ///      with whatever the SDK and frontend encrypt against. A mismatch here does
    ///      not fail loudly; it produces notes nobody can decrypt.
    function _registerRevoker(address pool) internal {
        string memory cfg = vm.readFile(string.concat(vm.projectRoot(), "/test/fixtures/config.json"));
        uint256[2] memory rpk;
        uint256[2] memory epk;
        rpk[0] = vm.parseJsonUint(cfg, ".revokerPublicKey[0]");
        rpk[1] = vm.parseJsonUint(cfg, ".revokerPublicKey[1]");
        epk[0] = vm.parseJsonUint(cfg, ".encryptionPublicKey[0]");
        epk[1] = vm.parseJsonUint(cfg, ".encryptionPublicKey[1]");
        Pool(payable(pool)).registerRevoker(rpk, epk, bytes("veilnyx-hyperevm-testnet"));
    }

    function _deployHasher() internal returns (Hasher) {
        bytes memory t3 = vm.parseBytes(vm.readFile(string.concat(vm.projectRoot(), "/src/poseidon/t3.txt")));
        bytes memory t4 = vm.parseBytes(vm.readFile(string.concat(vm.projectRoot(), "/src/poseidon/t4.txt")));
        bytes memory t5 = vm.parseBytes(vm.readFile(string.concat(vm.projectRoot(), "/src/poseidon/t5.txt")));
        address a;
        address b;
        address c;
        assembly {
            a := create(0, add(t3, 0x20), mload(t3))
            b := create(0, add(t4, 0x20), mload(t4))
            c := create(0, add(t5, 0x20), mload(t5))
        }
        return new Hasher(IPoseidon(a), IPoseidon(b), IPoseidon(c));
    }

    function _report(Deployed memory d) internal view {
        console2.log("");
        console2.log("poolProxy      ", d.poolProxy);
        console2.log("poolImpl       ", d.poolImpl);
        console2.log("verifier       ", d.verifier);
        console2.log("hasher         ", d.hasher);
        console2.log("adaptorHandler ", d.adaptorHandler);
        console2.log("gateway        ", d.gateway);
        console2.log("paymaster      ", d.paymaster);
        console2.log("screener       ", d.screener);
        console2.log("priceFeed      ", d.feed);
        string[9] memory names =
            ["register", "treeUpdate", "transact21", "transact22", "transact23", "transact42", "transact44", "transact82", "transact84"];
        for (uint256 i = 0; i < 9; i++) {
            console2.log(names[i], d.verifiers[i]);
        }
    }
}
