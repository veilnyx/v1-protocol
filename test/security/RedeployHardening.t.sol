// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {PoolBaseTest} from "test/fixtures/PoolBaseTest.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {IAdaptorHandler} from "src/interfaces/IAdaptorHandler.sol";
import {BabyJubJubLogic} from "src/libraries/BabyJubJubLogic.sol";
import {Asset, AssetType, AssetLogic} from "src/libraries/AssetLogic.sol";
import {QueuedMerkleTree, QueuedMerkleTreeLogic} from "src/libraries/QueuedMerkleTreeLogic.sol";
import {ShieldedTransaction, ShieldedTransactionLogic, ShieldedTransactionType} from "src/libraries/ShieldedTransactionLogic.sol";
import {FIELD_SIZE, TX_HASH_V2_TAG} from "src/base/Constants.sol";

/// Contract-side hardening that ships with the Palliora redeploy (no new ceremony):
///   - revoker keys must be in the BabyJubJub prime-order subgroup (mixed-order points rejected)
///   - opt-in v2 transaction hash: every field + chain id + pool address is signed
///   - CALL_ADAPTOR with refundAddress == 0 is rejected
///   - the commitment queue cannot grow past what the treeUpdate circuit can insert
///   - a deposit must credit the pool with exactly the amount the note is minted for
/// Real-proof coverage of the v2 hash is in RedeployForkSuite.t.sol.
contract RedeployHardeningTest is PoolBaseTest {
    // BabyJubJub test points (twisted Edwards form used by circomlib and the circuits)
    uint256 constant B8_X = 5299619240641551281634865583518297030282874472190772894086521144482721001553;
    uint256 constant B8_Y = 16950150798460657717958625567821834550301663161624707787222815936182638968203;
    // generator of the full group (order 8 * l): not in the prime-order subgroup
    uint256 constant G_X = 995203441582195749578291179787384436505546430278305826713579947235728471134;
    uint256 constant G_Y = 5472060717959818805561601436314318772137091100104008585924551046643952123905;
    // a point of order 4: (sqrt(1/a), 0)
    uint256 constant O4_X = 18930368022820495955728484915491405972470733850014661777449844430438130630919;
    // a point of order 8: [l]G
    uint256 constant O8_X = 4342719913949491028786768530115087822524712248835451589697801404893164183326;
    uint256 constant O8_Y = 4826523245007015323400664741523384119579596407052839571721035538011798951543;
    // revoker 0 on the live Ethereum and HyperEVM pools (both keys are prime-order)
    uint256 constant LIVE_REVOKER_X = 19670944452806042525069794818829249411975318219685565589987272359777840230253;
    uint256 constant LIVE_REVOKER_Y = 5705876210490413354479267746861793442476799294826521514340924438581325830039;
    uint256 constant LIVE_ENC_X = 8415733266590874906051569398859887253801673499116319370506942542327247131378;
    uint256 constant LIVE_ENC_Y = 4303763666990812745724909494561603880133773663501392405214554054831058921986;

    /// hashV2(_sampleTx(), chainId 999, pool 0x...9001)
    uint256 constant HASH_V2_VECTOR = 10287438950420733548199270422711720398136271865018227309152055955606452881044;

    function setUp() public {
        _setUp();
    }

    // ============================== BabyJubJub ==============================

    function test_primeSubgroup_vectors() public pure {
        assertTrue(BabyJubJubLogic.isInPrimeSubgroup(B8_X, B8_Y), "Base8");
        assertTrue(BabyJubJubLogic.isInPrimeSubgroup(LIVE_REVOKER_X, LIVE_REVOKER_Y), "live revoker key");
        assertTrue(BabyJubJubLogic.isInPrimeSubgroup(LIVE_ENC_X, LIVE_ENC_Y), "live encryption key");

        assertFalse(BabyJubJubLogic.isInPrimeSubgroup(G_X, G_Y), "full-group generator");
        assertFalse(BabyJubJubLogic.isInPrimeSubgroup(FIELD_SIZE - B8_X, FIELD_SIZE - B8_Y), "Base8 + order-2 point");
        assertFalse(BabyJubJubLogic.isInPrimeSubgroup(O4_X, 0), "order 4");
        assertFalse(BabyJubJubLogic.isInPrimeSubgroup(O8_X, O8_Y), "order 8");
        assertFalse(BabyJubJubLogic.isInPrimeSubgroup(0, 1), "identity");
        assertFalse(BabyJubJubLogic.isInPrimeSubgroup(0, FIELD_SIZE - 1), "order 2");
        assertFalse(BabyJubJubLogic.isInPrimeSubgroup(B8_X, B8_Y + 1), "off curve");
        assertFalse(BabyJubJubLogic.isInPrimeSubgroup(B8_X + FIELD_SIZE, B8_Y), "non-canonical x");
    }

    function test_registerRevoker_requiresPrimeOrderKeys() public {
        uint256[2] memory good = [B8_X, B8_Y];
        uint256[2][5] memory bad = [
            [G_X, G_Y],
            [FIELD_SIZE - B8_X, FIELD_SIZE - B8_Y],
            [O4_X, uint256(0)],
            [O8_X, O8_Y],
            [B8_X, B8_Y + 1]
        ];
        for (uint256 i; i < bad.length; ++i) {
            vm.expectRevert(abi.encodeWithSelector(IPool.InvalidCurvePoint.selector, bad[i][0], bad[i][1]));
            pool.registerRevoker(bad[i], good, "");
            vm.expectRevert(abi.encodeWithSelector(IPool.InvalidCurvePoint.selector, bad[i][0], bad[i][1]));
            pool.registerRevoker(good, bad[i], "");
        }

        uint256 gasBefore = gasleft();
        pool.registerRevoker([LIVE_REVOKER_X, LIVE_REVOKER_Y], [LIVE_ENC_X, LIVE_ENC_Y], "");
        emit log_named_uint("registerRevoker gas (two subgroup checks)", gasBefore - gasleft());
        assertTrue(pool.getRevokerData(0).isActive);
    }

    // ============================== v2 transaction hash ==============================

    function test_enableTxHashV2_ownerOnlyOneWay() public {
        assertEq(pool.txHashVersion(), 0, "legacy by default");

        vm.prank(address(0xBAD));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0xBAD)));
        pool.enableTxHashV2();

        vm.expectEmit(address(pool));
        emit IPool.TxHashVersionUpdated(2);
        pool.enableTxHashV2();
        assertEq(pool.txHashVersion(), 2);

        // idempotent, and there is no way back
        pool.enableTxHashV2();
        assertEq(pool.txHashVersion(), 2);
    }

    function _sampleTx() internal pure returns (ShieldedTransaction memory s) {
        s.txType = ShieldedTransactionType.WITHDRAW;
        s.revokerId = 0;
        s.addressTreeRoot = 11;
        s.commitmentTreeRoot = 12;
        s.feeData = 13;
        s.refundAddress = 14;
        s.betaUHF = 15;
        s.pubAssets = new uint248[](1);
        s.pubAssets[0] = (uint248(65538) << 224) | 40e6;
        s.nullifiers = new uint256[](2);
        s.nullifiers[0] = 21;
        s.nullifiers[1] = 22;
        s.commitments = new uint256[](1);
        s.commitments[0] = 31;
        s.proof = hex"aa";
        s.assetsMemo = hex"bb";
        s.keysMemo = hex"cc";
        s.notesMemo = hex"dd";
        s.targetData = abi.encodePacked(address(0xA11CE));
    }

    /// The exact formula the SDK must reproduce. The value is pinned so the SDK can use the same
    /// transaction as a test vector (docs/palliora-redeploy-999.md).
    function test_hashV2_matchesSpec() public pure {
        ShieldedTransaction memory s = _sampleTx();
        uint256 expected = uint256(
            keccak256(
                abi.encode(
                    TX_HASH_V2_TAG,
                    uint256(999),
                    address(0x9001),
                    keccak256(abi.encode(uint8(2), uint16(0), uint256(11), uint256(12), uint256(13), uint256(14))),
                    keccak256(abi.encode(s.pubAssets, s.nullifiers, s.commitments)),
                    keccak256(abi.encode(s.assetsMemo, s.keysMemo, s.notesMemo, s.targetData))
                )
            )
        ) % FIELD_SIZE;
        assertEq(ShieldedTransactionLogic.hashV2(s, 999, address(0x9001)), expected);
        assertEq(expected, HASH_V2_VECTOR, "pinned SDK test vector");
    }

    /// Every field the user chooses changes the v2 hash, and so do the chain and the pool. Only
    /// the proof (which carries the signature) and betaUHF (derived from notesMemo) do not.
    function test_hashV2_bindsEveryField() public pure {
        uint256 h = ShieldedTransactionLogic.hashV2(_sampleTx(), 999, address(0x9001));
        assertTrue(h != ShieldedTransactionLogic.hash(_sampleTx()), "differs from legacy");

        assertTrue(h != ShieldedTransactionLogic.hashV2(_sampleTx(), 1, address(0x9001)), "chain id");
        assertTrue(h != ShieldedTransactionLogic.hashV2(_sampleTx(), 999, address(0x9002)), "pool");

        for (uint256 i; i < 13; ++i) {
            ShieldedTransaction memory m = _sampleTx();
            if (i == 0) m.txType = ShieldedTransactionType.TRANSFER;
            if (i == 1) m.revokerId = 1;
            if (i == 2) m.addressTreeRoot += 1;
            if (i == 3) m.commitmentTreeRoot += 1;
            if (i == 4) m.feeData += 1;
            if (i == 5) m.refundAddress += 1;
            if (i == 6) m.pubAssets[0] += 1;
            if (i == 7) m.nullifiers[1] += 1;
            if (i == 8) m.commitments[0] += 1;
            if (i == 9) m.assetsMemo = hex"bc";
            if (i == 10) m.keysMemo = hex"cd";
            if (i == 11) m.notesMemo = hex"de";
            if (i == 12) m.targetData = abi.encodePacked(address(0xBAD));
            assertTrue(ShieldedTransactionLogic.hashV2(m, 999, address(0x9001)) != h, vm.toString(i));
        }

        ShieldedTransaction memory same = _sampleTx();
        same.proof = hex"ff";
        same.betaUHF = 99;
        assertEq(ShieldedTransactionLogic.hashV2(same, 999, address(0x9001)), h, "proof and betaUHF excluded");
    }

    /// The legacy hash leaves out commitments and amounts (finding L-2): two transactions that
    /// differ only there share a signature.
    function test_legacyHash_omitsCommitmentsAndAmounts() public pure {
        ShieldedTransaction memory a = _sampleTx();
        ShieldedTransaction memory b = _sampleTx();
        b.commitments[0] += 1;
        b.pubAssets[0] += 1;
        assertEq(ShieldedTransactionLogic.hash(a), ShieldedTransactionLogic.hash(b));
        assertTrue(
            ShieldedTransactionLogic.hashV2(a, 999, address(0x9001)) !=
                ShieldedTransactionLogic.hashV2(b, 999, address(0x9001))
        );
    }

    // ============================== CALL_ADAPTOR refund address ==============================

    function test_callAdaptor_rejectsZeroRefundAddress() public {
        pool.registerRevoker(fixture.revokerPublicKey, fixture.encryptionPublicKey, "");
        address adaptor = address(0xADA);
        pool.addAdaptorSupport(IAdaptorHandler(adaptor), true);

        ShieldedTransaction memory s;
        s.txType = ShieldedTransactionType.CALL_ADAPTOR;
        s.revokerId = 0;
        (, uint256 addrRoot, , ) = pool.getAddressTreeState();
        (, , uint256 cmRoot, , ) = pool.getCommitmentTreeState();
        s.addressTreeRoot = addrRoot;
        s.commitmentTreeRoot = cmRoot;
        s.targetData = abi.encodePacked(adaptor);
        s.refundAddress = 0;

        vm.expectRevert(IPool.ZeroRefundAddress.selector);
        pool.transact(s);

        // a non-zero refund address gets past the check (and fails later, on the empty proof)
        s.refundAddress = 1;
        vm.expectRevert();
        pool.transact(s);
    }

    // ============================== commitment tree capacity ==============================

    function test_queueCapacity_keepsEveryLeafInsertable() public {
        CapacityHarness h = new CapacityHarness();
        uint32 capacity = uint32(1 << 25);
        uint32 limit = capacity - 9; // queueSize 10: the last update must start at capacity - 10

        h.setQueueEnd(limit - 2);
        h.queue(2); // reaches the limit exactly
        assertEq(h.queueEnd(), limit);

        vm.expectRevert(QueuedMerkleTreeLogic.MerkleTreeFull.selector);
        h.queue(1);

        h.setQueueEnd(limit - 1);
        vm.expectRevert(QueuedMerkleTreeLogic.MerkleTreeFull.selector);
        h.queue(2); // a multi-leaf transaction that would cross the limit is rejected whole
    }

    // ============================== received amount ==============================

    function test_receiveAsset_rejectsFeeOnTransferToken() public {
        AssetHarness h = new AssetHarness();
        FeeOnTransferToken fot = new FeeOnTransferToken();
        StandardToken std = new StandardToken();
        h.add(1, address(fot));
        h.add(2, address(std));

        fot.mint(address(this), 100);
        fot.approve(address(h), type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(AssetLogic.ReceivedAmountMismatch.selector, uint24(1), 100, 99));
        h.receiveAsset(address(this), 1, 100);

        std.mint(address(this), 100);
        std.approve(address(h), type(uint256).max);
        h.receiveAsset(address(this), 2, 100);
        assertEq(std.balanceOf(address(h)), 100);
    }
}

contract CapacityHarness {
    using QueuedMerkleTreeLogic for QueuedMerkleTree;
    QueuedMerkleTree internal tree;

    constructor() {
        tree.capacity = uint32(1 << 25);
        tree.queueSize = 10;
    }

    function setQueueEnd(uint32 end) external {
        tree.queueEndIndex = end;
        tree.queueStartIndex = end;
        tree.nextLeafIndex = end;
    }

    function queueEnd() external view returns (uint32) {
        return tree.queueEndIndex;
    }

    function queue(uint256 n) external {
        uint256[] memory leaves = new uint256[](n);
        for (uint256 i; i < n; ++i) leaves[i] = i + 1;
        this.queueCalldata(leaves);
    }

    function queueCalldata(uint256[] calldata leaves) external {
        tree.queueLeaves(leaves);
    }
}

contract AssetHarness {
    mapping(uint24 => Asset) internal assets;

    function add(uint24 id, address token) external {
        assets[id] = Asset({
            id: id,
            assetType: AssetType.ERC20,
            assetAddress: token,
            isActive: true,
            precision: 18,
            usdPriceFeed: AggregatorV3Interface(address(0)),
            feedDecimals: 0
        });
    }

    function receiveAsset(address from, uint24 id, uint256 value) external {
        AssetLogic.receiveAsset(assets, from, id, value);
    }
}

contract StandardToken is ERC20("Std", "STD") {
    function mint(address to, uint256 v) external {
        _mint(to, v);
    }
}

/// Burns 1% of every transfer.
contract FeeOnTransferToken is ERC20("Fot", "FOT") {
    function mint(address to, uint256 v) external {
        _mint(to, v);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) {
            uint256 fee = value / 100;
            super._update(from, address(0), fee);
            super._update(from, to, value - fee);
        } else {
            super._update(from, to, value);
        }
    }
}
