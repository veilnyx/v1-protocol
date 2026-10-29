// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

import {FIELD_SIZE, BABYJUBJUB_A, BABYJUBJUB_D, BABYJUBJUB_SUBGROUP_ORDER} from "../base/Constants.sol";

/// @title BabyJubJubLogic
/// @notice Point checks on the BabyJubJub twisted Edwards curve a*x^2 + y^2 = 1 + d*x^2*y^2.
/// @dev The circuits' ValidatePoint only rejects low-order points, so a point P + T, where P is in
///      the prime-order subgroup and T is a non-zero low-order point (a "mixed-order" point), passes
///      it. Keys the circuits use as scalar-multiplication bases are therefore checked here before
///      the pool accepts them.
library BabyJubJubLogic {
    /// @notice True when (x, y) is a canonical point on the curve.
    function isOnCurve(uint256 x, uint256 y) internal pure returns (bool) {
        if (x >= FIELD_SIZE || y >= FIELD_SIZE) return false;
        uint256 x2 = mulmod(x, x, FIELD_SIZE);
        uint256 y2 = mulmod(y, y, FIELD_SIZE);
        uint256 lhs = addmod(mulmod(BABYJUBJUB_A, x2, FIELD_SIZE), y2, FIELD_SIZE);
        uint256 rhs = addmod(
            1,
            mulmod(BABYJUBJUB_D, mulmod(x2, y2, FIELD_SIZE), FIELD_SIZE),
            FIELD_SIZE
        );
        return lhs == rhs;
    }

    /// @notice True when (x, y) is on the curve, is not the identity, and lies in the prime-order
    ///         subgroup, i.e. [l]P == O for the subgroup order l. This rejects every low-order and
    ///         every mixed-order point.
    /// @dev External so the scalar multiplication is not inlined into callers' bytecode. Costs
    ///      roughly 0.2M gas; only called on owner-only revoker registration.
    function isInPrimeSubgroup(uint256 x, uint256 y) external pure returns (bool) {
        if (!isOnCurve(x, y)) return false;
        // The identity is (0, 1); (0, -1) has order 2. Neither can be a key.
        if (x == 0) return false;

        uint256[4] memory point = [x, y, mulmod(x, y, FIELD_SIZE), 1];
        uint256[4] memory acc = [uint256(0), 1, 0, 1]; // identity in extended coordinates

        uint256 k = BABYJUBJUB_SUBGROUP_ORDER;
        for (uint256 i = 252; i > 0; ) {
            unchecked {
                --i;
            }
            _addInPlace(acc, acc);
            if ((k >> i) & 1 == 1) {
                _addInPlace(acc, point);
            }
        }

        // acc == identity  <=>  X == 0 and Y == Z (Z is never 0 with the complete formulas)
        return acc[0] == 0 && acc[1] == acc[3];
    }

    /// @dev r := r + p in extended twisted Edwards coordinates (X:Y:T:Z), x = X/Z, y = Y/Z,
    ///      x*y = T/Z. Unified addition, Hisil-Wong-Carter-Dawson 2008 (add-2008-hwcd):
    ///        A = X1X2, B = Y1Y2, C = d*T1T2, D = Z1Z2, E = (X1+Y1)(X2+Y2) - A - B,
    ///        F = D - C, G = D + C, H = B - a*A,  X3 = EF, Y3 = GH, T3 = EH, Z3 = FG.
    ///      The law is complete on BabyJubJub (a square, d non-square), so it also doubles
    ///      (r and p may be the same array: every input is read before anything is written)
    ///      and handles the identity.
    function _addInPlace(uint256[4] memory r, uint256[4] memory p) private pure {
        // Literals equal to FIELD_SIZE, BABYJUBJUB_A and BABYJUBJUB_D (asserted below).
        assert(
            FIELD_SIZE == 21888242871839275222246405745257275088548364400416034343698204186575808495617 &&
                BABYJUBJUB_A == 168700 &&
                BABYJUBJUB_D == 168696
        );
        assembly ("memory-safe") {
            let q := 21888242871839275222246405745257275088548364400416034343698204186575808495617
            // every input is read before the first mstore, so r and p may alias
            let a := mulmod(mload(r), mload(p), q)
            let b := mulmod(mload(add(r, 0x20)), mload(add(p, 0x20)), q)
            // all values are < q, so q - v is in [1, q] and addmod reduces it
            let e := addmod(
                mulmod(
                    addmod(mload(r), mload(add(r, 0x20)), q),
                    addmod(mload(p), mload(add(p, 0x20)), q),
                    q
                ),
                sub(q, addmod(a, b, q)),
                q
            )
            let c := mulmod(mulmod(mload(add(r, 0x40)), mload(add(p, 0x40)), q), 168696, q)
            let d := mulmod(mload(add(r, 0x60)), mload(add(p, 0x60)), q)
            let f := addmod(d, sub(q, c), q)
            let g := addmod(d, c, q)
            let h := addmod(b, sub(q, mulmod(168700, a, q)), q)

            mstore(r, mulmod(e, f, q))
            mstore(add(r, 0x20), mulmod(g, h, q))
            mstore(add(r, 0x40), mulmod(e, h, q))
            mstore(add(r, 0x60), mulmod(f, g, q))
        }
    }
}
