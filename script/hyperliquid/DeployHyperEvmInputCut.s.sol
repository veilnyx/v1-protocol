// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";

import {Pool} from "src/core/Pool.sol";
import {InitAddressParams, PoolConfigParams, IPool} from "src/interfaces/IPool.sol";
import {Verifier, TransactionVerifierInfo} from "src/core/Verifier.sol";
import {AdaptorHandler} from "src/core/AdaptorHandler.sol";
import {Gateway} from "src/core/Gateway.sol";
import {Paymaster} from "src/core/Paymaster.sol";
import {IVerifier} from "src/interfaces/IVerifier.sol";
import {IAdaptorHandler} from "src/interfaces/IAdaptorHandler.sol";
import {IHasher} from "src/interfaces/IHasher.sol";
import {IScreener} from "src/interfaces/IScreener.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {AssetType, AssetInitParams} from "src/libraries/AssetLogic.sol";
import {TREE_UPDATE_QUEUE_SIZE} from "src/base/Constants.sol";

import {VerifierRegister} from "src/verifiers/VerifierRegister.sol";
import {VerifierTreeUpdate} from "src/verifiers/VerifierTreeUpdate.sol";
import {VerifierTransact21} from "src/verifiers/VerifierTransact21.sol";
import {VerifierTransact22} from "src/verifiers/VerifierTransact22.sol";
import {VerifierTransact23} from "src/verifiers/VerifierTransact23.sol";
import {VerifierTransact42} from "src/verifiers/VerifierTransact42.sol";
import {VerifierTransact44} from "src/verifiers/VerifierTransact44.sol";
import {VerifierTransact82} from "src/verifiers/VerifierTransact82.sol";
import {VerifierTransact84} from "src/verifiers/VerifierTransact84.sol";

/// @title HyperEVM testnet (998) pool for the public-input cut (3/1/1 public inputs)
/// @notice Deploys a fresh pool next to the existing testnet pool, without touching it, and
///         clones that pool's configuration from script/hyperliquid/hyperevm-testnet-inputcut.json:
///         every asset in the same order (so asset ids are unchanged), every revoker in the same
///         order with the same keys and metadata (so revoker ids and the guardians' keys are
///         unchanged), the same fee/limit settings, and the same stateless Hasher and Screener.
///
/// TESTNET ONLY: the verifiers in src/verifiers on this branch come from single-contribution
/// development keys, not a ceremony.
///
/// The deployer needs HyperEVM big blocks (the verifiers and the Pool exceed the 3M small-block
/// limit) and must be a HyperCore user for that.
///
///   PRIVATE_KEY=0x.. forge script script/hyperliquid/DeployHyperEvmInputCut.s.sol:DeployHyperEvmInputCut \
///     --rpc-url https://rpc.hyperliquid-testnet.xyz/evm --broadcast --slow
contract DeployHyperEvmInputCut is Script {
    string internal constant CONFIG = "/script/hyperliquid/hyperevm-testnet-inputcut.json";

    struct Deployed {
        address poolProxy;
        address poolImpl;
        address verifier;
        address adaptorHandler;
        address gateway;
        address paymaster;
        address[9] verifiers;
    }

    function run() external {
        require(block.chainid == 998, "testnet 998 only");
        string memory cfg = vm.readFile(string.concat(vm.projectRoot(), CONFIG));
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address me = vm.addr(pk);
        console2.log("deployer:", me);

        Deployed memory d;
        vm.startBroadcast(pk);

        (d.verifier, d.verifiers) = _deployVerifiers(me);
        d.adaptorHandler = address(new AdaptorHandler());
        d.poolImpl = address(new Pool());

        bytes memory initData = abi.encodeCall(
            Pool.initialize,
            (
                TREE_UPDATE_QUEUE_SIZE,
                InitAddressParams({
                    verifier: IVerifier(d.verifier),
                    adaptorHandler: IAdaptorHandler(d.adaptorHandler),
                    screener: IScreener(vm.parseJsonAddress(cfg, ".screener")),
                    hasher: IHasher(vm.parseJsonAddress(cfg, ".hasher")),
                    pauser: vm.parseJsonAddress(cfg, ".pauser")
                }),
                PoolConfigParams({
                    withdrawFeeBps: vm.parseJsonUint(cfg, ".withdrawFeeBps"),
                    tvlLimitUsd: type(uint256).max,
                    minDepositUsd: vm.parseJsonUint(cfg, ".minDepositUsd"),
                    maxDepositUsd: type(uint256).max,
                    priceFeedStalenessThreshold: vm.parseJsonUint(cfg, ".priceFeedStalenessThreshold"),
                    nativeWToken: IWToken(vm.parseJsonAddress(cfg, ".nativeWToken"))
                })
            )
        );
        d.poolProxy = address(new ERC1967Proxy(d.poolImpl, initData));
        AdaptorHandler(payable(d.adaptorHandler)).setVeilnyxPool(IPool(d.poolProxy));

        IEntryPoint ep = IEntryPoint(vm.parseJsonAddress(cfg, ".entryPoint"));
        IWToken wToken = IWToken(vm.parseJsonAddress(cfg, ".nativeWToken"));
        d.gateway = address(new Gateway(ep, wToken, IPool(d.poolProxy)));
        d.paymaster = address(new Paymaster(ep, d.gateway, IPool(d.poolProxy), 1 days));

        _registerAssets(cfg, Pool(payable(d.poolProxy)));
        _registerRevokers(cfg, Pool(payable(d.poolProxy)));
        Pool(payable(d.poolProxy)).setVersion(2);

        vm.stopBroadcast();
        _check(cfg, d);
        _report(d);
    }

    function _deployVerifiers(address manager) internal returns (address router, address[9] memory v) {
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

        router = address(new Verifier(infos, address(vr), address(vtu), manager));
        v = [address(vr), address(vtu), address(v21), address(v22), address(v23), address(v42), address(v44), address(v82), address(v84)];
    }

    function _registerAssets(string memory cfg, Pool pool) internal {
        address[] memory addrs = vm.parseJsonAddressArray(cfg, ".assetAddresses");
        uint256[] memory prec = vm.parseJsonUintArray(cfg, ".assetPrecisions");
        address[] memory feeds = vm.parseJsonAddressArray(cfg, ".assetFeeds");
        require(addrs.length == prec.length && addrs.length == feeds.length, "asset arrays");
        AssetInitParams[] memory p = new AssetInitParams[](addrs.length);
        for (uint256 i = 0; i < addrs.length; i++) {
            p[i] = AssetInitParams({
                assetAddress: addrs[i],
                precision: uint8(prec[i]),
                usdPriceFeed: AggregatorV3Interface(feeds[i])
            });
        }
        pool.addAssets(AssetType.ERC20, p);
    }

    function _registerRevokers(string memory cfg, Pool pool) internal {
        uint256[] memory rx = vm.parseJsonUintArray(cfg, ".revokerPublicKeysX");
        uint256[] memory ry = vm.parseJsonUintArray(cfg, ".revokerPublicKeysY");
        uint256[] memory ex = vm.parseJsonUintArray(cfg, ".encryptionPublicKeysX");
        uint256[] memory ey = vm.parseJsonUintArray(cfg, ".encryptionPublicKeysY");
        bytes[] memory meta = vm.parseJsonBytesArray(cfg, ".revokerMetadata");
        for (uint256 i = 0; i < rx.length; i++) {
            pool.registerRevoker([rx[i], ry[i]], [ex[i], ey[i]], meta[i]);
        }
    }

    /// Read back what was configured; any mismatch means the app's asset/revoker ids would be wrong.
    function _check(string memory cfg, Deployed memory d) internal view {
        Pool pool = Pool(payable(d.poolProxy));
        address[] memory addrs = vm.parseJsonAddressArray(cfg, ".assetAddresses");
        for (uint256 i = 0; i < addrs.length; i++) {
            require(pool.getAsset(uint24(65537 + i)).assetAddress == addrs[i], "asset id mismatch");
        }
        uint256[] memory rx = vm.parseJsonUintArray(cfg, ".revokerPublicKeysX");
        for (uint256 i = 0; i < rx.length; i++) {
            require(pool.getRevokerData(i).revokerPublicKey[0] == rx[i], "revoker id mismatch");
        }
        require(address(pool.verifier()) == d.verifier, "verifier");
    }

    function _report(Deployed memory d) internal pure {
        console2.log("poolProxy      ", d.poolProxy);
        console2.log("poolImpl       ", d.poolImpl);
        console2.log("verifierRouter ", d.verifier);
        console2.log("adaptorHandler ", d.adaptorHandler);
        console2.log("gateway        ", d.gateway);
        console2.log("paymaster      ", d.paymaster);
        string[9] memory names =
            ["register", "treeUpdate", "transact21", "transact22", "transact23", "transact42", "transact44", "transact82", "transact84"];
        for (uint256 i = 0; i < 9; i++) {
            console2.log(names[i], d.verifiers[i]);
        }
    }
}
