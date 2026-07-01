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

contract VerifierTransact42 {
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
        19007275781899364515815712904706484942743185929137021148114643347831526445224;
    uint256 constant deltax2 =
        28770690914211291874830194708765328712207815354716972861231672562790360005;
    uint256 constant deltay1 =
        5470620246072572081643158557715277575575474981490504462210708438992466937303;
    uint256 constant deltay2 =
        4195498664104832545589387681564837600306125191240701403409362299822659670805;

    uint256 constant IC0x =
        1791208969265618801306262800499630373990718500901877582213495472008547300094;
    uint256 constant IC0y =
        12191821726880093138038357398053666499961813750351193594142261035945005946610;

    uint256 constant IC1x =
        7682017649299525253068909854447830275368529951233491025159587443768742002187;
    uint256 constant IC1y =
        13772382608515701010567403412585296478659139034795620294801607104137995673122;

    uint256 constant IC2x =
        19340585940910248780621756400599776281897203725669587206397668438326036310847;
    uint256 constant IC2y =
        3514792640729590400232247642046897168186683924374910755888351933297018606643;

    uint256 constant IC3x =
        9145476444634377490444548713775819508121940674665008282696860399796251608947;
    uint256 constant IC3y =
        13717985049498128587828460552469567763617433475134101836649568533708114272868;

    uint256 constant IC4x =
        16356804342702592052436009253206936108221965110941720031415362791427291467752;
    uint256 constant IC4y =
        16671227318770154116450559495910189398790169417333885479491835298253435748005;

    uint256 constant IC5x =
        3506387563123026822959235232315323108305522541022715636450657459255454605832;
    uint256 constant IC5y =
        12736936161933031410946591951328044951034833113670654918983629061857428727065;

    uint256 constant IC6x =
        10180161388490558024558785430269479786068816882946697344347498353133915755128;
    uint256 constant IC6y =
        9697628022920699662355181404791912519304967224423795109087639170079427449212;

    uint256 constant IC7x =
        17626372714925981056033733664252165170019705338606982297636402781837524687437;
    uint256 constant IC7y =
        13394430998537406972954882422384458643135442166672590114948394535618887315485;

    uint256 constant IC8x =
        21669300813220383933538973761243273500371558050475120271116969582310264929715;
    uint256 constant IC8y =
        11694524439251585497290704303225352889207447610205704721088352569818498398694;

    uint256 constant IC9x =
        11648165171563891343182781958648186811895206587254614984990856360711017464728;
    uint256 constant IC9y =
        4662650790861141098086249770885298341469946921576231243541254789685882335770;

    uint256 constant IC10x =
        4934052319767400197661700416376310836810104739146627601240809631250415760020;
    uint256 constant IC10y =
        648287870674962500865277501591745291349217410872930948151604250124740974778;

    uint256 constant IC11x =
        1398069707724960575959724823411795361565115485102907783684610408053156342310;
    uint256 constant IC11y =
        11541869944428647638169327968377417993800443044825346268458738942192379119888;

    uint256 constant IC12x =
        11948024769473424454755941605151863326721348126612200865661043307817075730638;
    uint256 constant IC12y =
        5891683833780645759141554840632460673891007441919944836951483311005860656470;

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
