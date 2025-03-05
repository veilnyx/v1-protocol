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
        20491192805390485299153009773594534940189261866228447918068658471970481763042;
    uint256 constant alphay =
        9383485363053290200918347156157836566562967994039712273449902621266178545958;
    uint256 constant betax1 =
        4252822878758300859123897981450591353533073413197771768651442665752259397132;
    uint256 constant betax2 =
        6375614351688725206403948262868962793625744043794305715222011528459656738731;
    uint256 constant betay1 =
        21847035105528745403288232691147584728191162732299865338377159692350059136679;
    uint256 constant betay2 =
        10505242626370262277552901082094356697409835680220590971873171140371331206856;
    uint256 constant gammax1 =
        11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant gammax2 =
        10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant gammay1 =
        4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant gammay2 =
        8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant deltax1 =
        19890648652185482598515082266940693699803610292343388113921745510901694543783;
    uint256 constant deltax2 =
        10772389103431410291928252930696487512808955592783261670555819597226247693536;
    uint256 constant deltay1 =
        215923635730898440489794895828426786317133808872120083190689581022106996644;
    uint256 constant deltay2 =
        5285724091785063407028458876540104625898193090426882265638968720828130672780;

    uint256 constant IC0x =
        2680511349276221934374069730210323128207808767712245678430451881249246809536;
    uint256 constant IC0y =
        7030756283541303618565149203899571472285115876703223647525273635214980334173;

    uint256 constant IC1x =
        21094414824079669488806853049376108352128454537216331307407973992779454065772;
    uint256 constant IC1y =
        7595750886485950122686628344467615555936919828724431162937354532286865779599;

    uint256 constant IC2x =
        4692934436865316865310116447190197615967318250988906171398365959421633569065;
    uint256 constant IC2y =
        1025815450824782155779275360681677799928461245681603915684409129843357015304;

    uint256 constant IC3x =
        7696038553669249723261332824204555151680472733895676043695991784912936372762;
    uint256 constant IC3y =
        18564840265775636369583139823711408525963344951708836680024814585782523195710;

    uint256 constant IC4x =
        17716150720464945361060529937686010005861528354534263976250956626531634900398;
    uint256 constant IC4y =
        10720813252482857956408581435045735939275854808058038032176347454754724382572;

    uint256 constant IC5x =
        18203921675933394485435511892280466786389223804719064154879855768667742900634;
    uint256 constant IC5y =
        11625779969330631041467257185812234505834906715666499096564193971553491918198;

    uint256 constant IC6x =
        13890290029640450919108138456368581560863576977346300389980315625161177341717;
    uint256 constant IC6y =
        17147298481376418869182451052642422210071143286088198903547395169980982926580;

    uint256 constant IC7x =
        17428638789729298796630372497003270333152765515127422706257982245963457010640;
    uint256 constant IC7y =
        4142457613350056820433732247351540674091900989835049943804866814176706666885;

    uint256 constant IC8x =
        8008405499069913306977083691902494212500709771797031448808856783978119736634;
    uint256 constant IC8y =
        170390362586925224782306319152486790219767088658236915621142169146748081763;

    uint256 constant IC9x =
        11147440152646097275010530676808009752657347595508949438708534500840436977371;
    uint256 constant IC9y =
        21174725788287783217128451694151128102285119564919598402733502401214082614350;

    uint256 constant IC10x =
        3928947129884650211324285046764983041784690842452319370903921177115506024994;
    uint256 constant IC10y =
        20253339548042703458581847705787274284721894449025601564523057223811651311683;

    uint256 constant IC11x =
        21060437079021527489475966446246900378185608300901779376443946268840348094196;
    uint256 constant IC11y =
        10370313330331946069888873131986668261459951330357030446916915735795941521479;

    uint256 constant IC12x =
        925229911080675710929160961639092885130505027571076133855040279608035905376;
    uint256 constant IC12y =
        12351197816540028927839998713792361778685837882249492575713165369626053156877;

    uint256 constant IC13x =
        9145544420333047312812629547608872160559397377300895196949122594758685014715;
    uint256 constant IC13y =
        19005389163950041552413814716166739698503718422234074457835610995350596998945;

    uint256 constant IC14x =
        6928496005789987740840927556490753025669293258502647617079689556006864864066;
    uint256 constant IC14y =
        3441007388861682268671575420840223381335382036338348372156486958856117727474;

    uint256 constant IC15x =
        6483907032026065233074152555926870664306471883793962952364264374772228920108;
    uint256 constant IC15y =
        16134560233100434295126412347099185623789024288533777290082747466674069509841;

    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[15] calldata _pubSignals
    ) public view returns (bool) {
        assembly {
            function checkField(v) {
                if iszero(lt(v, q)) {
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

                success := staticcall(not(0), 7, mIn, 96, mIn, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }

                mstore(add(mIn, 64), mload(pR))
                mstore(add(mIn, 96), mload(add(pR, 32)))

                success := staticcall(not(0), 6, mIn, 128, pR, 64)

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

                g1_mulAccC(
                    _pVk,
                    IC13x,
                    IC13y,
                    calldataload(add(pubSignals, 384))
                )

                g1_mulAccC(
                    _pVk,
                    IC14x,
                    IC14y,
                    calldataload(add(pubSignals, 416))
                )

                g1_mulAccC(
                    _pVk,
                    IC15x,
                    IC15y,
                    calldataload(add(pubSignals, 448))
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
                    not(0),
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

            checkField(calldataload(add(_pubSignals, 416)))

            checkField(calldataload(add(_pubSignals, 448)))

            checkField(calldataload(add(_pubSignals, 480)))

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
            return(0, 0x20)
        }
    }
}
