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
        21561366536823075874225387543593430660136596355630965757353696746054585721635;
    uint256 constant deltax2 =
        20509142182491462688352919118961536570805069647652000185203399366444067780913;
    uint256 constant deltay1 =
        3564508823282883044794539785370250999173389449588865781961291523189953245949;
    uint256 constant deltay2 =
        5497112144839244285890178308816890567929188488514550463475638560997121302636;

    uint256 constant IC0x =
        8822307918991344368047589847751543284113072876489059463188572603406148029238;
    uint256 constant IC0y =
        1738189482882794198068004422757185314591886892362904394286537286130923166943;

    uint256 constant IC1x =
        14786455306622763686188911283868859072349664687627679638197355187884634115741;
    uint256 constant IC1y =
        208177452207255623437663902685075469528081402987618714287076062829064853823;

    uint256 constant IC2x =
        8557988063478529752056042073080898926462650517156541107531349181752602790715;
    uint256 constant IC2y =
        8845514170725083602316077698268193816560351456059832892114592960003754575608;

    uint256 constant IC3x =
        13758480710421489060010827554658598084120809123492407867246730369512666627697;
    uint256 constant IC3y =
        13874164878662841090335648961141620908939461326069645366496659733485649853297;

    uint256 constant IC4x =
        18982967682765484867760348940379225120317938164752667575015032760146684417713;
    uint256 constant IC4y =
        21491135409783648217197205113470022895979434469460365212616436734973722109390;

    uint256 constant IC5x =
        3047852216488568005829465496927612390709550197689382764862459497155355668543;
    uint256 constant IC5y =
        13436190076732268340176249043143965999452551756714790949710614856373743092686;

    uint256 constant IC6x =
        16624311345225279899924325198941784161481716990585280421894169236859461405093;
    uint256 constant IC6y =
        9618715159886945394488737553853660460160310270730177841578737257446396342401;

    uint256 constant IC7x =
        8119977529842423579695174698743045814593455256982041521942325959704212562279;
    uint256 constant IC7y =
        9038800075917663067628085350594657374946503728488048025224156366241330484991;

    uint256 constant IC8x =
        10396774358522192455275037239613557413628942833292994229722661993402112732245;
    uint256 constant IC8y =
        18116761852124944806316575568790261589059151299170836131980804334984690111018;

    uint256 constant IC9x =
        2395890133371815074993593715518517986692740753690649616145568269372842667902;
    uint256 constant IC9y =
        18174565157568486893774879379477480779810382758028730777467441678806986434731;

    uint256 constant IC10x =
        3344340538345158969656602607658260126347038605023881420916545723650496669995;
    uint256 constant IC10y =
        21476713723257441870889712347176619269081237639578648447200644666699317580054;

    uint256 constant IC11x =
        18339970551636557352372533531861511005262234125500902276252666608041621174787;
    uint256 constant IC11y =
        1014443354702932048165523666220227951752557634959782546122789674293237052262;

    uint256 constant IC12x =
        1170147625708097248620793098798834563381075660694250659863626974681969281740;
    uint256 constant IC12y =
        7467657500200584755083921501987790468442404174093145010706494697011020245491;

    uint256 constant IC13x =
        21161038115739946809585037021946332917457395253350487940947416847630581270014;
    uint256 constant IC13y =
        20263502649212499726089659380943373241901727631306599442577700987902165433498;

    uint256 constant IC14x =
        10855746795721969411136168150839748627220123092356338424188456006140215137255;
    uint256 constant IC14y =
        1546992654626195610422628262594577980036003142412294207028951885460503310865;

    uint256 constant IC15x =
        15769789338066337429144749744475260152827659503449907791187938661955615526747;
    uint256 constant IC15y =
        14809765658323064013471896821772461486336843464275121233166259026607639293906;

    uint256 constant IC16x =
        341731572301488773964650103487903015038941051723695383396777266535457910066;
    uint256 constant IC16y =
        19900978216418383734964617946971555260334571912510734355800393029347577992523;

    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[16] calldata _pubSignals
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

                g1_mulAccC(
                    _pVk,
                    IC16x,
                    IC16y,
                    calldataload(add(pubSignals, 480))
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

            checkField(calldataload(add(_pubSignals, 512)))

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
            return(0, 0x20)
        }
    }
}
