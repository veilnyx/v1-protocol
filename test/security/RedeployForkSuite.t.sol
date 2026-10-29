// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// Attack suite for the Palliora redeploy: this branch's Pool, deployed the way the redeploy will
// deploy it on HyperEVM 999, with the v2 transaction hash enabled. Every fixture is a real
// Groth16 proof made with the PRODUCTION ceremony keys by generators/genRedeployForkFixtures.
//
// Needs a HyperEVM mainnet RPC; skipped without one:
//   HYPEREVM_RPC_URL=https://rpc.hyperliquid.xyz/evm forge test --match-path test/security/RedeployForkSuite.t.sol -vv
// (FORK_BLOCK pins a block; the default is the latest.)
//
// Reused from the live 999 deployment, as the redeploy plans to: the nine ceremony verifiers,
// the Poseidon hasher, USDC, WHYPE and the price feeds. Deployed fresh from this branch: the Pool
// implementation and proxy, the Verifier router and the AdaptorHandler. The proxy sits at a fixed
// address because the v2 hash binds the pool address.

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {BaseTest} from "test/fixtures/BaseTest.sol";
import {Pool} from "src/core/Pool.sol";
import {Verifier, TransactionVerifierInfo} from "src/core/Verifier.sol";
import {AdaptorHandler} from "src/core/AdaptorHandler.sol";
import {VerifierTransact21} from "src/verifiers/VerifierTransact21.sol";
import {IPool, InitAddressParams, PoolConfigParams} from "src/interfaces/IPool.sol";
import {IVerifier} from "src/interfaces/IVerifier.sol";
import {IAdaptorHandler} from "src/interfaces/IAdaptorHandler.sol";
import {IScreener} from "src/interfaces/IScreener.sol";
import {IHasher} from "src/interfaces/IHasher.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {AssetType, AssetInitParams} from "src/libraries/AssetLogic.sol";
import {ShieldedTransaction, ShieldedTransactionType} from "src/libraries/ShieldedTransactionLogic.sol";
import {ShieldedAddressRegistrationData} from "src/libraries/ShieldedAddressLogic.sol";
import {QueuedMerkleTreeLogic, TreeUpdateData} from "src/libraries/QueuedMerkleTreeLogic.sol";
import {FIELD_SIZE, MESSAGE_REGISTER_ADDRESS, EIP712_DOMAIN_NAME, EIP712_DOMAIN_VERSION, EIP712_TYPEHASH_REGISTER_ADDRESS} from "src/base/Constants.sol";

contract RedeployForkSuite is BaseTest {
    /// address(uint160(uint256(keccak256("palliora.redeploy.fork.pool")))): the v2 hashes in the
    /// fixtures are bound to it (REDEPLOY_POOL in the generator).
    address constant POOL = address(uint160(uint256(keccak256("palliora.redeploy.fork.pool"))));
    address constant POOL_2 = address(uint160(uint256(keccak256("palliora.redeploy.fork.pool.2"))));

    // ---- live HyperEVM 999 contracts reused by the redeploy (deployments/hyperevm-999.json) ----
    address constant HASHER = 0xA9d61c4A66705314157D3DEb726463162f2D95b5;
    address constant V_REGISTER = 0x82C8CD776707eeeD95a4b248d73B63dabAE2d10b;
    address constant V_TREE_UPDATE = 0x70Bd8f99f328d1967D5075402d73588A20c08CB9;
    address constant V_21 = 0x9c75948e2E0F63c003A96c0202b02AEBD95fa152;
    address constant V_22 = 0x6dc08A79E37490f050fD481Bf1e3237835354b06;
    address constant V_23 = 0xa9fD688c51D4279a087ba2ae3Ec4739c44Ee8BF4;
    address constant V_42 = 0x6C0972faA323Ed2cBCaEac6345D3625c39dBA1Bb;
    address constant V_44 = 0xd08eaFFbfC9Bdbf54Ed65dfe0091c205082D8538;
    address constant V_82 = 0xab0c362d4fB0f10B32E1e6D3cF2B91076c90ba53;
    address constant V_84 = 0xa88771E6e7104d5423ACFFF246c1b08ac13d69A9;
    address constant PAUSER = 0x50887b9a36E734cF861FE236fA6b4bE68D205113;
    address constant WHYPE = 0x5555555555555555555555555555555555555555;
    address constant USDC = 0xb88339CB7199b77E23DB6E890353E22632Ba630f;
    address constant WHYPE_FEED = 0xa8a94Da411425634e3Ed6C331a32ab4fd774aa43;
    address constant USDC_FEED = 0x4C89968338b75551243C99B452c84a01888282fD;
    uint256 constant Q = 21888242871839275222246405745257275088696311157297823662689037894645226208583; // BN254 base field

    uint256 constant PK_ALICE = 0xa11ce;
    uint256 constant PK_BOB = 0xb0b;
    uint256 constant PK_MALLORY = 0xbad0;
    address alice;
    address bob;
    address mallory;
    address relayer = address(0xFEE1);

    Pool pool;
    Verifier router;
    AdaptorHandler handler;

    function setUp() public {
        string memory rpc = vm.envOr("HYPEREVM_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true);
            return;
        }
        uint256 forkBlock = vm.envOr("FORK_BLOCK", uint256(0));
        if (forkBlock == 0) vm.createSelectFork(rpc);
        else vm.createSelectFork(rpc, forkBlock);
        require(block.chainid == 999, "HYPEREVM_RPC_URL must be HyperEVM mainnet");

        BaseTest._setUp(); // fixture (revoker keys) and loaders
        alice = vm.addr(PK_ALICE);
        bob = vm.addr(PK_BOB);
        mallory = vm.addr(PK_MALLORY);

        router = _deployRouter();
        handler = new AdaptorHandler();
        pool = _deployPool(POOL);
        handler.setVeilnyxPool(IPool(address(pool)));

        _register("redeploy_register_alice", PK_ALICE);
        _register("redeploy_register_bob", PK_BOB);
        _register("redeploy_register_mallory", PK_MALLORY);

        deal(USDC, relayer, 10_000e6);
        vm.prank(relayer);
        IERC20(USDC).approve(address(pool), type(uint256).max);
    }

    // ============================== deployment ==============================

    function _deployRouter() internal returns (Verifier r) {
        bytes4 sel = VerifierTransact21.verifyProof.selector; // same ABI for every transact shape
        TransactionVerifierInfo[] memory v = new TransactionVerifierInfo[](7);
        v[0] = TransactionVerifierInfo({id: 21, selector: sel, addr: V_21});
        v[1] = TransactionVerifierInfo({id: 22, selector: sel, addr: V_22});
        v[2] = TransactionVerifierInfo({id: 23, selector: sel, addr: V_23});
        v[3] = TransactionVerifierInfo({id: 42, selector: sel, addr: V_42});
        v[4] = TransactionVerifierInfo({id: 44, selector: sel, addr: V_44});
        v[5] = TransactionVerifierInfo({id: 82, selector: sel, addr: V_82});
        v[6] = TransactionVerifierInfo({id: 84, selector: sel, addr: V_84});
        r = new Verifier(v, V_REGISTER, V_TREE_UPDATE, address(this));
    }

    function _deployPool(address at) internal returns (Pool p) {
        InitAddressParams memory ia = InitAddressParams({
            verifier: IVerifier(address(router)),
            adaptorHandler: IAdaptorHandler(address(handler)),
            screener: IScreener(address(0)),
            hasher: IHasher(HASHER),
            pauser: PAUSER
        });
        PoolConfigParams memory pc = PoolConfigParams({
            withdrawFeeBps: 0,
            tvlLimitUsd: 5_000e6,
            minDepositUsd: 2e6,
            maxDepositUsd: 250e6,
            priceFeedStalenessThreshold: 108000,
            nativeWToken: IWToken(WHYPE)
        });
        Pool impl = new Pool();
        deployCodeTo(
            "ERC1967Proxy.sol:ERC1967Proxy",
            abi.encode(address(impl), abi.encodeCall(Pool.initialize, (uint8(10), ia, pc))),
            at
        );
        p = Pool(payable(at));
        AssetInitParams[] memory a = new AssetInitParams[](2);
        a[0] = AssetInitParams({assetAddress: WHYPE, precision: 18, usdPriceFeed: AggregatorV3Interface(WHYPE_FEED)});
        a[1] = AssetInitParams({assetAddress: USDC, precision: 6, usdPriceFeed: AggregatorV3Interface(USDC_FEED)});
        p.addAssets(AssetType.ERC20, a);
        assertEq(p.getAsset(USDC).id, 65538, "USDC id as on the live pool");
        p.registerRevoker(fixture.revokerPublicKey, fixture.encryptionPublicKey, "");
        p.enableTxHashV2();
    }

    function _sig(Pool p, uint256 pk, bytes memory shieldedAddress, string memory domainName) internal view returns (bytes memory) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(domainName)),
                keccak256(bytes(EIP712_DOMAIN_VERSION)),
                block.chainid,
                address(p)
            )
        );
        bytes32 h = MessageHashUtils.toTypedDataHash(
            domain,
            keccak256(abi.encode(EIP712_TYPEHASH_REGISTER_ADDRESS, keccak256(bytes(MESSAGE_REGISTER_ADDRESS)), keccak256(shieldedAddress)))
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, h);
        return abi.encodePacked(r, s, v);
    }

    function _sig(Pool p, uint256 pk, bytes memory shieldedAddress) internal view returns (bytes memory) {
        return _sig(p, pk, shieldedAddress, EIP712_DOMAIN_NAME);
    }

    function _register(string memory name, uint256 pk) internal {
        ShieldedAddressRegistrationData memory reg = _loadShieldedAddressRegistrationData(name);
        reg.signature = _sig(pool, pk, reg.shieldedAddress);
        vm.prank(relayer);
        pool.registerAddress(reg);
    }

    function _tx(string memory name) internal view returns (ShieldedTransaction memory) {
        return _loadShieldedTransaction(string.concat("redeploy_", name));
    }

    function _tu(string memory name) internal view returns (TreeUpdateData memory) {
        return _loadTreeUpdateData(string.concat("redeploy_", name));
    }

    function _send(ShieldedTransaction memory stx) internal {
        vm.prank(relayer);
        pool.transact(stx);
    }

    function _sendExpect(ShieldedTransaction memory stx, bytes memory err) internal {
        vm.prank(relayer);
        vm.expectRevert(err);
        pool.transact(stx);
    }

    function _toR1() internal {
        _send(_tx("deposit_alice_100"));
        _send(_tx("deposit_bob_50"));
        pool.updateCommitmentTree(_tu("tree_update_1"));
    }

    function _toR2() internal {
        _toR1();
        _send(_tx("withdraw_alice_40"));
        pool.updateCommitmentTree(_tu("tree_update_2"));
    }

    function _toR3() internal {
        _toR2();
        _send(_tx("transfer_bob_to_alice_20"));
        pool.updateCommitmentTree(_tu("tree_update_3"));
    }

    function _word(bytes memory b, uint256 i) internal pure returns (uint256 w) {
        assembly {
            w := mload(add(add(b, 0x20), mul(i, 0x20)))
        }
    }

    function _setWord(bytes memory b, uint256 i, uint256 w) internal pure {
        assembly {
            mstore(add(add(b, 0x20), mul(i, 0x20)), w)
        }
    }

    function _copy(bytes memory b) internal pure returns (bytes memory c) {
        c = bytes.concat(b);
    }

    /// Flip one bit, or append a byte when the field is empty (so the tamper is never a no-op).
    function _flip(bytes memory b, uint256 at) internal pure returns (bytes memory r) {
        if (b.length <= at) return bytes.concat(b, hex"01");
        r = _copy(b);
        r[at] = r[at] ^ 0x01;
    }

    // ============================== deployment checks ==============================

    function test_00_deployment() public view {
        (, string memory name, string memory ver, uint256 chainId, address verifying, , ) = pool.eip712Domain();
        assertEq(name, "Palliora");
        assertEq(ver, "1");
        assertEq(chainId, 999);
        assertEq(verifying, POOL);
        assertEq(pool.txHashVersion(), 2);
        assertEq(address(pool.verifier()), address(router));
        assertEq(pool.owner(), address(this));
    }

    function test_01_honestFlow() public {
        uint256 a0 = IERC20(USDC).balanceOf(alice);
        uint256 b0 = IERC20(USDC).balanceOf(bob);
        _toR3();
        _send(_tx("withdraw_bob_10"));
        assertEq(IERC20(USDC).balanceOf(alice) - a0, 40e6, "alice got 40");
        assertEq(IERC20(USDC).balanceOf(bob) - b0, 10e6, "bob got 10");
        assertEq(IERC20(USDC).balanceOf(address(pool)), 100e6, "pool holds the rest");
    }

    // ============================== v2 HASH ==============================

    /// The same spend, signed over the legacy hash: the v2 pool rejects it.
    function test_v2_legacySignedTxRejected() public {
        _toR1();
        _sendExpect(_tx("withdraw_alice_40_legacy_hash"), abi.encodeWithSelector(IPool.InvalidTransactionProof.selector));
        _send(_tx("withdraw_alice_40")); // the v2-signed one works
    }

    /// Signed for another pool, or for another chain: not valid here.
    function test_v2_domainSeparated() public {
        _toR1();
        _sendExpect(_tx("withdraw_alice_40_other_pool"), abi.encodeWithSelector(IPool.InvalidTransactionProof.selector));
        _sendExpect(_tx("withdraw_alice_40_other_chain"), abi.encodeWithSelector(IPool.InvalidTransactionProof.selector));
        _send(_tx("withdraw_alice_40"));
    }

    /// L-2: one signature from Alice, re-proved by someone with her viewing key and note openings
    /// with the change redirected to Mallory. The proof is internally valid (it proves the hash
    /// Alice signed), but v2 covers the outputs, so the pool's hash differs and it is rejected.
    function test_v2_L2_reproveWithOtherOutputsRejected() public {
        _toR1();
        ShieldedTransaction memory honest = _tx("withdraw_alice_40");
        ShieldedTransaction memory reproved = _tx("l2_reprove_change_to_mallory");
        assertEq(reproved.nullifiers[0], honest.nullifiers[0], "same note");
        assertTrue(reproved.commitments[0] != honest.commitments[0] || reproved.commitments[1] != honest.commitments[1], "different outputs");
        _sendExpect(reproved, abi.encodeWithSelector(IPool.InvalidTransactionProof.selector));
        _send(honest);
    }

    // ============================== DOUBLE SPEND ==============================

    function test_doubleSpend_replaySameTx() public {
        _toR1();
        ShieldedTransaction memory w = _tx("withdraw_alice_40");
        _send(w);
        _sendExpect(w, abi.encodeWithSelector(IPool.DoubleSpend.selector, w.nullifiers[0]));
    }

    function test_doubleSpend_newProofSameNote() public {
        _toR1();
        _send(_tx("withdraw_alice_40"));
        ShieldedTransaction memory w2 = _tx("double_spend_new_proof");
        _sendExpect(w2, abi.encodeWithSelector(IPool.DoubleSpend.selector, w2.nullifiers[0]));
    }

    function test_doubleSpend_aliasedNullifier() public {
        _toR1();
        ShieldedTransaction memory w = _tx("withdraw_alice_40");
        ShieldedTransaction memory a = _tx("double_spend_aliased_nullifier");
        assertEq(a.nullifiers[0], w.nullifiers[0] + FIELD_SIZE, "aliased = n + p");
        _sendExpect(a, abi.encodeWithSelector(IPool.NonCanonicalFieldElement.selector, a.nullifiers[0]));
        _send(w);
        _sendExpect(a, abi.encodeWithSelector(IPool.NonCanonicalFieldElement.selector, a.nullifiers[0]));
    }

    /// Groth16 proofs are malleable: (-A, -B, C) verifies too. Harmless because the nullifier,
    /// not the proof bytes, is what stops reuse.
    function test_proofMalleability_cannotDoubleSpend() public {
        _toR1();
        ShieldedTransaction memory w = _tx("withdraw_alice_40");
        ShieldedTransaction memory m = _tx("withdraw_alice_40");
        m.proof = _copy(w.proof);
        _setWord(m.proof, 1, Q - _word(w.proof, 1)); // -A
        _setWord(m.proof, 4, Q - _word(w.proof, 4)); // -B (y1)
        _setWord(m.proof, 5, Q - _word(w.proof, 5)); // -B (y0)
        uint256 bal = IERC20(USDC).balanceOf(alice);
        _send(m); // the malleated proof verifies
        assertEq(IERC20(USDC).balanceOf(alice) - bal, 40e6, "paid to Alice's recipient");
        _sendExpect(w, abi.encodeWithSelector(IPool.DoubleSpend.selector, w.nullifiers[0]));
        _sendExpect(m, abi.encodeWithSelector(IPool.DoubleSpend.selector, w.nullifiers[0]));
    }

    /// A deposit spends dummy input notes whose nullifiers are marked too, so it cannot be replayed.
    function test_depositReplay() public {
        ShieldedTransaction memory d = _tx("deposit_alice_100");
        _send(d);
        _sendExpect(d, abi.encodeWithSelector(IPool.DoubleSpend.selector, d.nullifiers[0]));
    }

    // ============================== OWNERSHIP / TAMPERING ==============================

    function test_frontrun_changeRecipient() public {
        _toR1();
        ShieldedTransaction memory m = _tx("withdraw_alice_40");
        m.targetData = abi.encodePacked(mallory);
        _sendExpect(m, abi.encodeWithSelector(IPool.InvalidTransactionProof.selector));
        assertEq(IERC20(USDC).balanceOf(mallory), 0);
        _send(_tx("withdraw_alice_40"));
    }

    function test_frontrun_honestCopyPaysOwnerRecipient() public {
        _toR1();
        ShieldedTransaction memory w = _tx("withdraw_alice_40");
        uint256 a0 = IERC20(USDC).balanceOf(alice);
        vm.prank(mallory);
        pool.transact(w);
        assertEq(IERC20(USDC).balanceOf(alice) - a0, 40e6, "funds still go to Alice's recipient");
        assertEq(IERC20(USDC).balanceOf(mallory), 0);
    }

    function test_tamper_eachField() public {
        _toR1();
        ShieldedTransaction memory w = _tx("withdraw_alice_40");
        string[14] memory names = ["pubAssets value", "pubAssets id", "commitment[0]", "betaUHF", "feeData", "refundAddress", "assetsMemo", "keysMemo", "notesMemo", "txType->TRANSFER", "proof byte", "proof zero", "revokerId", "targetData payload"];
        for (uint256 i; i < names.length; i++) {
            ShieldedTransaction memory m = _tx("withdraw_alice_40");
            if (i == 0) m.pubAssets[0] = m.pubAssets[0] + 1;
            if (i == 1) m.pubAssets[0] = (uint248(65537) << 224) | (m.pubAssets[0] & ((uint248(1) << 224) - 1));
            if (i == 2) m.commitments[0] = (m.commitments[0] + 1) % FIELD_SIZE;
            if (i == 3) m.betaUHF = (m.betaUHF + 1) % FIELD_SIZE;
            if (i == 4) m.feeData = uint256(uint160(mallory)) << 96;
            if (i == 5) m.refundAddress = m.refundAddress ^ 1;
            if (i == 6) m.assetsMemo = _flip(w.assetsMemo, 0);
            if (i == 7) m.keysMemo = _flip(w.keysMemo, 0);
            if (i == 8) m.notesMemo = _flip(w.notesMemo, 31);
            if (i == 9) m.txType = ShieldedTransactionType.TRANSFER;
            if (i == 10) {
                m.proof = _copy(w.proof);
                m.proof[40] = m.proof[40] ^ 0x01;
            }
            if (i == 11) m.proof = new bytes(w.proof.length);
            if (i == 12) m.revokerId = 1;
            if (i == 13) m.targetData = bytes.concat(w.targetData, hex"00");
            vm.prank(relayer);
            try pool.transact(m) {
                console2.log("!!! ACCEPTED TAMPERED FIELD:", names[i]);
                fail();
            } catch (bytes memory e) {
                console2.log(string.concat("tamper rejected: ", names[i]));
                console2.logBytes4(bytes4(e));
            }
        }
        _send(w);
    }

    /// L-1 (circuit; fixed at the next ceremony): a fake input with value p - assetId skips the
    /// Merkle check. The pool accepts it and the only effect is destroyed value.
    function test_L1_fakeNegativeInput_onlyDestroysValue() public {
        _toR3();
        ShieldedTransaction memory l1 = _tx("l1_fake_negative_input");
        uint256 pool0 = IERC20(USDC).balanceOf(address(pool));
        uint256 bob0 = IERC20(USDC).balanceOf(bob);
        _send(l1);
        assertEq(pool0 - IERC20(USDC).balanceOf(address(pool)), 10e6, "pool pays exactly the public 10 USDC");
        assertEq(IERC20(USDC).balanceOf(bob) - bob0, 10e6, "bob receives 10 USDC");
        _sendExpect(_tx("withdraw_bob_10"), abi.encodeWithSelector(IPool.DoubleSpend.selector, l1.nullifiers[0]));
    }

    function test_unknownRoots() public {
        _toR1();
        ShieldedTransaction memory m = _tx("withdraw_alice_40");
        m.commitmentTreeRoot = 12345;
        _sendExpect(m, abi.encodeWithSelector(IPool.UnknownCommitmentTreeRoot.selector));
        m = _tx("withdraw_alice_40");
        m.addressTreeRoot = 12345;
        _sendExpect(m, abi.encodeWithSelector(IPool.UnknownAddressTreeRoot.selector));
        m = _tx("withdraw_alice_40");
        m.revokerId = 7;
        _sendExpect(m, abi.encodeWithSelector(IPool.InvalidRevoker.selector, uint256(7)));
    }

    /// A root the pool knows (R0, the empty tree) from before the note existed.
    function test_knownButWrongRoot() public {
        (, , uint256 r0, , ) = pool.getCommitmentTreeState();
        _toR1();
        ShieldedTransaction memory m = _tx("withdraw_alice_40");
        assertTrue(m.commitmentTreeRoot != r0);
        m.commitmentTreeRoot = r0;
        _sendExpect(m, abi.encodeWithSelector(IPool.InvalidTransactionProof.selector));
    }

    // ============================== FEES ==============================

    function test_fee_mintOnDeposit() public {
        _sendExpect(_tx("fee_mint_deposit"), abi.encodeWithSelector(IPool.UnbackedFee.selector, uint24(65538), uint256(200e6)));
    }

    function test_fee_mismatchedAssetAndExceedsValue() public {
        _toR3();
        _sendExpect(_tx("fee_mismatched_asset"), abi.encodeWithSelector(IPool.UnbackedFee.selector, uint24(65537), uint256(1e18)));
        _sendExpect(_tx("fee_exceeds_value"), abi.encodeWithSelector(IPool.UnbackedFee.selector, uint24(65538), uint256(25e6)));
        _send(_tx("withdraw_bob_10"));
    }

    // ============================== COMMITMENTS / TREE ==============================

    function test_aliasedCommitmentRejected() public {
        ShieldedTransaction memory d = _tx("deposit_aliased_commitment");
        assertGe(d.commitments[0], FIELD_SIZE);
        _sendExpect(d, abi.encodeWithSelector(IPool.NonCanonicalFieldElement.selector, d.commitments[0]));
        _toR1();
    }

    function test_treeUpdate_forgedAndReplayed() public {
        _send(_tx("deposit_alice_100"));
        _send(_tx("deposit_bob_50"));
        TreeUpdateData memory t = _tu("tree_update_1");
        TreeUpdateData memory f = _tu("tree_update_1");
        f.newRoot = (t.newRoot + 1) % FIELD_SIZE;
        vm.expectRevert(QueuedMerkleTreeLogic.InvalidProof.selector);
        pool.updateCommitmentTree(f);
        f = _tu("tree_update_1");
        f.newLevelSubtrees[3] = (t.newLevelSubtrees[3] + 1) % FIELD_SIZE;
        vm.expectRevert(QueuedMerkleTreeLogic.InvalidProof.selector);
        pool.updateCommitmentTree(f);
        f = _tu("tree_update_1");
        f.batchSize = 0;
        vm.expectRevert(QueuedMerkleTreeLogic.InvalidBatchSize.selector);
        pool.updateCommitmentTree(f);
        pool.updateCommitmentTree(t);
        vm.expectRevert(QueuedMerkleTreeLogic.InvalidBatchSize.selector);
        pool.updateCommitmentTree(t); // replay: nothing left to insert
    }

    /// #40: a tree-update proof made for the leaves queued at the time stays valid after more
    /// leaves are queued (it inserts exactly its batch), and a second update finishes the job.
    function test_treeUpdate_earlyProofSurvivesNewLeaves() public {
        _send(_tx("deposit_alice_100"));
        TreeUpdateData memory early = _tu("tree_update_early");
        _send(_tx("deposit_bob_50")); // queued before the early proof lands
        pool.updateCommitmentTree(early);
        pool.updateCommitmentTree(_tu("tree_update_after_early"));
        (, , uint256 root, , ) = pool.getCommitmentTreeState();
        assertEq(root, _tu("tree_update_1").newRoot, "same root as one batch");
        _send(_tx("withdraw_alice_40")); // spends against it
    }

    // ============================== REGISTRATION ==============================

    function test_reg_domainIsPalliora_oldNameRejected() public {
        Pool p = _deployPool(POOL_2);
        ShieldedAddressRegistrationData memory reg = _loadShieldedAddressRegistrationData("redeploy_register_alice");
        reg.signature = _sig(p, PK_ALICE, reg.shieldedAddress, "Veilnyx");
        vm.expectRevert(IPool.InvalidAddressProof.selector); // recovers some other address
        p.registerAddress(reg);
        reg.signature = _sig(p, PK_ALICE, reg.shieldedAddress, "Palliora");
        p.registerAddress(reg);
    }

    function test_reg_replay() public {
        ShieldedAddressRegistrationData memory reg = _loadShieldedAddressRegistrationData("redeploy_register_alice");
        reg.signature = _sig(pool, PK_ALICE, reg.shieldedAddress);
        vm.expectRevert(abi.encodeWithSelector(IPool.RootAddressAlreadyRegistered.selector, uint256(bytes32(_slice32(reg.shieldedAddress)))));
        pool.registerAddress(reg);
    }

    function test_reg_signedByAnotherEOA() public {
        Pool p = _deployPool(POOL_2);
        ShieldedAddressRegistrationData memory reg = _loadShieldedAddressRegistrationData("redeploy_register_alice");
        reg.signature = _sig(p, PK_MALLORY, reg.shieldedAddress);
        vm.expectRevert(IPool.InvalidAddressProof.selector);
        p.registerAddress(reg);
    }

    function test_reg_mallorysProofForAlicesAddress() public {
        Pool p = _deployPool(POOL_2);
        ShieldedAddressRegistrationData memory alices = _loadShieldedAddressRegistrationData("redeploy_register_alice");
        ShieldedAddressRegistrationData memory reg = _loadShieldedAddressRegistrationData("redeploy_register_mallory_again");
        reg.shieldedAddress = alices.shieldedAddress;
        reg.signature = _sig(p, PK_MALLORY, reg.shieldedAddress);
        vm.expectRevert(IPool.InvalidAddressProof.selector);
        p.registerAddress(reg);
    }

    function test_reg_rebindAliceToMalloryEOA() public {
        ShieldedAddressRegistrationData memory reg = _loadShieldedAddressRegistrationData("redeploy_register_alice_to_mallory_eoa");
        reg.signature = _sig(pool, PK_MALLORY, reg.shieldedAddress);
        vm.expectRevert(abi.encodeWithSelector(IPool.RootAddressAlreadyRegistered.selector, uint256(bytes32(_slice32(reg.shieldedAddress)))));
        pool.registerAddress(reg);
    }

    /// The same key registered again.
    function test_reg_duplicateKey() public {
        ShieldedAddressRegistrationData memory reg = _loadShieldedAddressRegistrationData("redeploy_register_mallory_again");
        reg.signature = _sig(pool, PK_MALLORY, reg.shieldedAddress);
        vm.expectRevert(abi.encodeWithSelector(IPool.RootAddressAlreadyRegistered.selector, uint256(bytes32(_slice32(reg.shieldedAddress)))));
        pool.registerAddress(reg);
    }

    /// A different key for a wallet that is already registered: one shielded address per wallet.
    function test_reg_secondKeyForSameEOA() public {
        ShieldedAddressRegistrationData memory reg = _loadShieldedAddressRegistrationData("redeploy_register_mallory_second_account");
        reg.signature = _sig(pool, PK_MALLORY, reg.shieldedAddress);
        vm.expectRevert(abi.encodeWithSelector(IPool.PublicAddressAlreadyRegistered.selector, mallory));
        pool.registerAddress(reg);
    }

    function test_reg_tamperedProof() public {
        Pool p = _deployPool(POOL_2);
        ShieldedAddressRegistrationData memory reg = _loadShieldedAddressRegistrationData("redeploy_register_alice");
        reg.signature = _sig(p, PK_ALICE, reg.shieldedAddress);
        bytes memory good = reg.proof;
        reg.proof = _copy(good);
        reg.proof[33] = reg.proof[33] ^ 0x01;
        vm.expectRevert(IPool.InvalidAddressProof.selector);
        p.registerAddress(reg);
        reg.proof = good;
        reg.signature = _sig(pool, PK_ALICE, reg.shieldedAddress); // signed for ANOTHER pool's domain
        vm.expectRevert(IPool.InvalidAddressProof.selector);
        p.registerAddress(reg);
        reg.signature = _sig(p, PK_ALICE, reg.shieldedAddress);
        p.registerAddress(reg);
    }

    function _slice32(bytes memory b) internal pure returns (bytes32 w) {
        assembly {
            w := mload(add(b, 0x20))
        }
    }

    // ============================== GENERATOR-PRODUCED ATTACK PROOFS ==============================
    // Proofs the circuit should not have allowed. Missing fixture = the circuit refused (good);
    // if one exists, the pool must reject it.

    function test_attackProofs_ifAny() public {
        _toR3();
        string[9] memory names = [
            "steal_alice_note_with_mallory_key",
            "phantom_note_mallory_owner",
            "sender_steals_sent_note",
            "third_party_steals_received_note",
            "same_note_twice_in_one_tx",
            "inflate_change_note",
            "field_wraparound_outputs",
            "asset_confusion_output",
            "c2_withdraw_from_dummies"
        ];
        for (uint256 i; i < names.length; i++) {
            string memory path = string.concat(vm.projectRoot(), "/test/fixtures/data/redeploy_", names[i], ".txt");
            if (!vm.exists(path)) {
                console2.log(string.concat("no proof could be produced (circuit refused): ", names[i]));
                continue;
            }
            ShieldedTransaction memory a = _tx(names[i]);
            vm.prank(relayer);
            try pool.transact(a) {
                console2.log(string.concat("!!! ATTACK PROOF ACCEPTED: ", names[i]));
                fail();
            } catch (bytes memory e) {
                console2.log(string.concat("attack proof rejected by pool: ", names[i]));
                console2.logBytes4(bytes4(e));
            }
        }
    }

    // ============================== ACCESS CONTROL ==============================

    function test_accessControl() public {
        AssetInitParams[] memory a = new AssetInitParams[](0);
        vm.startPrank(mallory);
        vm.expectRevert();
        pool.addAssets(AssetType.ERC20, a);
        vm.expectRevert();
        pool.pause();
        vm.expectRevert();
        pool.setPauser(mallory);
        vm.expectRevert();
        pool.registerRevoker(fixture.revokerPublicKey, fixture.encryptionPublicKey, "");
        vm.expectRevert();
        pool.enableTxHashV2();
        vm.expectRevert();
        pool.upgradeToAndCall(address(0xdead), "");
        vm.stopPrank();
        vm.prank(PAUSER);
        pool.pause();
        _sendExpect(_tx("deposit_alice_100"), abi.encodeWithSignature("EnforcedPause()"));
    }
}
