// SPDX-License-Identifier: GPL-3.0
/*
    Copyright 2021 0KIMS association.

    This file is generated with [snarkJS](https://github.com/iden3/snarkjs).

    snarkJS is a free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    snarkJS is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
    License for more details.

    You should have received a copy of the GNU General Public License
    along with snarkJS. If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity >=0.7.0 <0.9.0;

contract VerifierTransact21 {
    // Scalar field size
    uint256 constant r =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // Base field size
    uint256 constant q =
        21888242871839275222246405745257275088696311157297823662689037894645226208583;

    // Verification Key data
    uint256 constant alphax =
        16428432848801857252194528405604668803277877773566238944394625302971855135431;
    uint256 constant alphay =
        16846502678714586896801519656441059708016666274385668027902869494772365009666;
    uint256 constant betax1 =
        3182164110458002340215786955198810119980427837186618912744689678939861918171;
    uint256 constant betax2 =
        16348171800823588416173124589066524623406261996681292662100840445103873053252;
    uint256 constant betay1 =
        4920802715848186258981584729175884379674325733638798907835771393452862684714;
    uint256 constant betay2 =
        19687132236965066906216944365591810874384658708175106803089633851114028275753;
    uint256 constant gammax1 =
        11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant gammax2 =
        10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant gammay1 =
        4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant gammay2 =
        8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant deltax1 =
        18615695626827416596276798058998516195501009823342176774766113811786389182347;
    uint256 constant deltax2 =
        10650925805078571277194617617768313540852882502350249388658132458092311880317;
    uint256 constant deltay1 =
        18507067960642776108974148757645061489755657090487889265100362578324511320059;
    uint256 constant deltay2 =
        6201989969403169254013183207491806904303757625882230115464606115807574805522;

    uint256 constant IC0x =
        11308328127290836219930528240368596078612117197657544932543317296729119240488;
    uint256 constant IC0y =
        1062666398781595150903198262625638655774795284798265263627927623332595296119;

    uint256 constant IC1x =
        13953822760786205435538505407698874546014556523113600565642306556611111911405;
    uint256 constant IC1y =
        8032908382621425369825600188502052951033883946813946206844170670031947188064;

    uint256 constant IC2x =
        3102174677843130552023433987519771286864082491387233833313146429895173774678;
    uint256 constant IC2y =
        16700165556712067670780203415611191416131181389282692663195562589278568659839;

    uint256 constant IC3x =
        13532234089237675757613594647948935134599696723632499369271723871969373059894;
    uint256 constant IC3y =
        11894072051025823821761980002597607007948690992334463234748136465383482169659;

    uint256 constant IC4x =
        13031182029395076084682928692753428169068682384640387615262679854748998296805;
    uint256 constant IC4y =
        20255124312924699720104109917345547071694749914730999049093834569524996965488;

    uint256 constant IC5x =
        3221977602387223279674547575446437803679339700809141348859650517931519425185;
    uint256 constant IC5y =
        17618662055980215554654723025019330989874747784925493176061432844785944171781;

    uint256 constant IC6x =
        9920344559648230137645208432414604418710342013930344308140506546182012955877;
    uint256 constant IC6y =
        15152437200092145606190393662423936999200439687537929868602643103583262556027;

    uint256 constant IC7x =
        9174775503520619800599009744426726868559500314634803974087749479230368648440;
    uint256 constant IC7y =
        17626720050209678838498638028172355281675789781608033180766742529395581071897;

    uint256 constant IC8x =
        19303227995119272302680264029616771024128958426930894967101621591238339956485;
    uint256 constant IC8y =
        5286351889306034430061659790666296622177496565951595371222679803905521817969;

    uint256 constant IC9x =
        789271987857869657047731347524157360362055645575982078325240215147786590413;
    uint256 constant IC9y =
        21671511391919911127134260828184796670115411621672138111812669880766070726358;

    uint256 constant IC10x =
        20229511790513142550795250775331819996173304409870874749666006117699005175946;
    uint256 constant IC10y =
        18952513613862353429524991365967655784088670043135808216614878130256800947551;

    uint256 constant IC11x =
        12503863965815561659996498536563248624334913693778584114758828066068294191837;
    uint256 constant IC11y =
        17580502652683323606191139739920233929995764784711271188406560636828698253799;

    uint256 constant IC12x =
        11063477856086837068663253212137937552394584085385555784121024564489158076711;
    uint256 constant IC12y =
        15490734912750848919149707037024626524232178431403120784547282597293452926007;

    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[12] calldata _pubSignals
    ) public view returns (bool) {
        assembly {
            function checkField(v) {
                if iszero(lt(v, r)) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }

            // G1 function to multiply a G1 value(x,y) to value in an address
            function g1_mulAccC(pR, x, y, s) {
                let success
                let mIn := mload(0x40)
                mstore(mIn, x)
                mstore(add(mIn, 32), y)
                mstore(add(mIn, 64), s)

                success := staticcall(sub(gas(), 2000), 7, mIn, 96, mIn, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }

                mstore(add(mIn, 64), mload(pR))
                mstore(add(mIn, 96), mload(add(pR, 32)))

                success := staticcall(sub(gas(), 2000), 6, mIn, 128, pR, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }

            function checkPairing(pA, pB, pC, pubSignals, pMem) -> isOk {
                let _pPairing := add(pMem, pPairing)
                let _pVk := add(pMem, pVk)

                mstore(_pVk, IC0x)
                mstore(add(_pVk, 32), IC0y)

                // Compute the linear combination vk_x

                g1_mulAccC(_pVk, IC1x, IC1y, calldataload(add(pubSignals, 0)))

                g1_mulAccC(_pVk, IC2x, IC2y, calldataload(add(pubSignals, 32)))

                g1_mulAccC(_pVk, IC3x, IC3y, calldataload(add(pubSignals, 64)))

                g1_mulAccC(_pVk, IC4x, IC4y, calldataload(add(pubSignals, 96)))

                g1_mulAccC(_pVk, IC5x, IC5y, calldataload(add(pubSignals, 128)))

                g1_mulAccC(_pVk, IC6x, IC6y, calldataload(add(pubSignals, 160)))

                g1_mulAccC(_pVk, IC7x, IC7y, calldataload(add(pubSignals, 192)))

                g1_mulAccC(_pVk, IC8x, IC8y, calldataload(add(pubSignals, 224)))

                g1_mulAccC(_pVk, IC9x, IC9y, calldataload(add(pubSignals, 256)))

                g1_mulAccC(
                    _pVk,
                    IC10x,
                    IC10y,
                    calldataload(add(pubSignals, 288))
                )

                g1_mulAccC(
                    _pVk,
                    IC11x,
                    IC11y,
                    calldataload(add(pubSignals, 320))
                )

                g1_mulAccC(
                    _pVk,
                    IC12x,
                    IC12y,
                    calldataload(add(pubSignals, 352))
                )

                // -A
                mstore(_pPairing, calldataload(pA))
                mstore(
                    add(_pPairing, 32),
                    mod(sub(q, calldataload(add(pA, 32))), q)
                )

                // B
                mstore(add(_pPairing, 64), calldataload(pB))
                mstore(add(_pPairing, 96), calldataload(add(pB, 32)))
                mstore(add(_pPairing, 128), calldataload(add(pB, 64)))
                mstore(add(_pPairing, 160), calldataload(add(pB, 96)))

                // alpha1
                mstore(add(_pPairing, 192), alphax)
                mstore(add(_pPairing, 224), alphay)

                // beta2
                mstore(add(_pPairing, 256), betax1)
                mstore(add(_pPairing, 288), betax2)
                mstore(add(_pPairing, 320), betay1)
                mstore(add(_pPairing, 352), betay2)

                // vk_x
                mstore(add(_pPairing, 384), mload(add(pMem, pVk)))
                mstore(add(_pPairing, 416), mload(add(pMem, add(pVk, 32))))

                // gamma2
                mstore(add(_pPairing, 448), gammax1)
                mstore(add(_pPairing, 480), gammax2)
                mstore(add(_pPairing, 512), gammay1)
                mstore(add(_pPairing, 544), gammay2)

                // C
                mstore(add(_pPairing, 576), calldataload(pC))
                mstore(add(_pPairing, 608), calldataload(add(pC, 32)))

                // delta2
                mstore(add(_pPairing, 640), deltax1)
                mstore(add(_pPairing, 672), deltax2)
                mstore(add(_pPairing, 704), deltay1)
                mstore(add(_pPairing, 736), deltay2)

                let success := staticcall(
                    sub(gas(), 2000),
                    8,
                    _pPairing,
                    768,
                    _pPairing,
                    0x20
                )

                isOk := and(success, mload(_pPairing))
            }

            let pMem := mload(0x40)
            mstore(0x40, add(pMem, pLastMem))

            // Validate that all evaluations ∈ F

            checkField(calldataload(add(_pubSignals, 0)))

            checkField(calldataload(add(_pubSignals, 32)))

            checkField(calldataload(add(_pubSignals, 64)))

            checkField(calldataload(add(_pubSignals, 96)))

            checkField(calldataload(add(_pubSignals, 128)))

            checkField(calldataload(add(_pubSignals, 160)))

            checkField(calldataload(add(_pubSignals, 192)))

            checkField(calldataload(add(_pubSignals, 224)))

            checkField(calldataload(add(_pubSignals, 256)))

            checkField(calldataload(add(_pubSignals, 288)))

            checkField(calldataload(add(_pubSignals, 320)))

            checkField(calldataload(add(_pubSignals, 352)))

            checkField(calldataload(add(_pubSignals, 384)))

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
            return(0, 0x20)
        }
    }
}
