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

contract Verifier22 {
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
        2624230588627749813549362327096457207182995899722583241138760263943487215550;
    uint256 constant deltax2 =
        14050904979848236589012516355400472919068432319461563536004007958614132018489;
    uint256 constant deltay1 =
        83199094259709942877437455616158388692046263802939373858547241768270540347;
    uint256 constant deltay2 =
        650631201694207894154374010312065329655709352839439012655494991947866624310;

    uint256 constant IC0x =
        1182701817830485358701993765563175177954260952826124122338878176743429671628;
    uint256 constant IC0y =
        14674662590609551928670325018801723986024976253864195521420145477743145443177;

    uint256 constant IC1x =
        17634768801570376406799197706108712943613615603773873314228200560383772993155;
    uint256 constant IC1y =
        6992883908853309223148212773713134555431920455676629474077368187108021759190;

    uint256 constant IC2x =
        8960582982941159398499342073599641028598118305801845182770741241132073155046;
    uint256 constant IC2y =
        9153978397086882720534131928274523090879129336359421217052007738990709339425;

    uint256 constant IC3x =
        1359057573242147891367871360873283296608135926032624031392098182070321695695;
    uint256 constant IC3y =
        21712719096935895391729213430704444793715154482899790785550537327364936544962;

    uint256 constant IC4x =
        11960512346571240620053381005717234736882731473417354062231482882321699056901;
    uint256 constant IC4y =
        10818556592789007448674479018198887086708805411639539701396948611274566106474;

    uint256 constant IC5x =
        12014713148592394476627763306091254092215818626999636134778519657116075006842;
    uint256 constant IC5y =
        5981762459508819290311027312741799829669474667298249299286304598709621499336;

    uint256 constant IC6x =
        13076206324557937416062481942492007375746878185889902543616031164160835353352;
    uint256 constant IC6y =
        2627439510819923261527753478409054079229282500382397118222704333361894037177;

    uint256 constant IC7x =
        9860124321215694945737528463310358863530213964124716697510924688350064265827;
    uint256 constant IC7y =
        20614820283003692623779377840878637550258498388532777318958402811564115078620;

    uint256 constant IC8x =
        15808852490456714852059887573491333948431685149476400113310309459882428006201;
    uint256 constant IC8y =
        5100370119762291230977648045504642502395567205981067090547188195728688778575;

    uint256 constant IC9x =
        9986285190549177171534494273773043463325970199237670335877724500893981637610;
    uint256 constant IC9y =
        21228588811333127547685690250386885295747689600202442841480883651438164739901;

    uint256 constant IC10x =
        12040238073885439396872066860237655931415238742586596889338471862470228088670;
    uint256 constant IC10y =
        563020417743845748580674610004207628523490411613335597109780720978981908568;

    uint256 constant IC11x =
        14771569324485734384756169005831710970779344618011456137153984312380790401715;
    uint256 constant IC11y =
        9738312427332130789610845212691733955710796633975253865239328811372550497411;

    uint256 constant IC12x =
        4721087119841076743905327468319317187669745856396601628750453456621118756950;
    uint256 constant IC12y =
        14419575275226425754394011070996240010074032886719519805507105915400449753991;

    uint256 constant IC13x =
        8995549412240476112753241203050025062128460754878058944642390400569341669026;
    uint256 constant IC13y =
        13073169840068020524840280750646954777614201266113347185971733569266252215653;

    uint256 constant IC14x =
        17742913933689351220419199419224873886403275649511786353305715430343288284546;
    uint256 constant IC14y =
        19444060418774130191151157043226214297636127621049824431768711473928466866963;

    uint256 constant IC15x =
        2219376496181259157248870094095624998792820924265535343075728862335125082637;
    uint256 constant IC15y =
        19001826585089691007498966587954548456626659904643185141975972372393816623794;

    uint256 constant IC16x =
        5866635806764157683551247175334637406116440408547714611656500650086978067626;
    uint256 constant IC16y =
        10997737121403891252969742068936312956375999939363473278213270232297462599420;

    uint256 constant IC17x =
        13784594051749323642763049065359395552469681169275469219873329788072090616962;
    uint256 constant IC17y =
        18657770658487360853770513812583775535212778672829180125607092911091035880116;

    uint256 constant IC18x =
        18727565856466587072378421906825221363205185155439899200784034432788133970659;
    uint256 constant IC18y =
        11999380397183096147094025067748421708518612887664740322695940256268805945205;

    uint256 constant IC19x =
        10510551563690162688342850365635207944942712733638035384121456740739442806120;
    uint256 constant IC19y =
        7032118678658210312997748436822119305013593483564847537199715922594588201924;

    uint256 constant IC20x =
        481373101962798578355446622289684877649947596715120914509629328676213983741;
    uint256 constant IC20y =
        15424264149771961332508676794924663497854671185608159342176868864025528761119;

    uint256 constant IC21x =
        10902651480083635424699836253630899083818494829578442547944504221386046818602;
    uint256 constant IC21y =
        173732752292169398609253369305098471287412203596066971308611518544989830971;

    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[21] calldata _pubSignals
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

                g1_mulAccC(
                    _pVk,
                    IC17x,
                    IC17y,
                    calldataload(add(pubSignals, 512))
                )

                g1_mulAccC(
                    _pVk,
                    IC18x,
                    IC18y,
                    calldataload(add(pubSignals, 544))
                )

                g1_mulAccC(
                    _pVk,
                    IC19x,
                    IC19y,
                    calldataload(add(pubSignals, 576))
                )

                g1_mulAccC(
                    _pVk,
                    IC20x,
                    IC20y,
                    calldataload(add(pubSignals, 608))
                )

                g1_mulAccC(
                    _pVk,
                    IC21x,
                    IC21y,
                    calldataload(add(pubSignals, 640))
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

            checkField(calldataload(add(_pubSignals, 544)))

            checkField(calldataload(add(_pubSignals, 576)))

            checkField(calldataload(add(_pubSignals, 608)))

            checkField(calldataload(add(_pubSignals, 640)))

            checkField(calldataload(add(_pubSignals, 672)))

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
            return(0, 0x20)
        }
    }
}
