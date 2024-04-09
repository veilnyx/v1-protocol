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
        1275165882132173939127306345451966237777255013291093752737220607762892322491;
    uint256 constant deltax2 =
        21125487800180724874815952301584517944354166598831308882847511236804412185899;
    uint256 constant deltay1 =
        13888629656269756317071986863532324244679122230174631812601976517623531885377;
    uint256 constant deltay2 =
        16726129660553239512010823634436169947027895674733838109088471403785136953505;

    uint256 constant IC0x =
        12759353418070406111735841397157415858202164143943778802110119999781245952835;
    uint256 constant IC0y =
        9670188171608227110094602521537813298224225242438350196928939783974607855134;

    uint256 constant IC1x =
        21039729173843624998099712499608000985339571048977175003002822331789909248868;
    uint256 constant IC1y =
        20774978165883495382234332265872188380918130728139874790335857257060170969863;

    uint256 constant IC2x =
        18885399376499020607767879140046349061152305111363203529006073975081904246733;
    uint256 constant IC2y =
        2388257117139566585436629437416700855897127609947989604637667610920781988966;

    uint256 constant IC3x =
        9317049174424531252664249362086155582681052499346531558450439217478188408681;
    uint256 constant IC3y =
        10536828740888610986060559180185254246154661225242669565783627169184505634174;

    uint256 constant IC4x =
        931257633644361070888884117846026647779396465150658547801234927503061278652;
    uint256 constant IC4y =
        11700933189353447125591221325686166973118743192914152174576262392096232960291;

    uint256 constant IC5x =
        1413399139333324687306733161888547076979652972002645099763198272645200794424;
    uint256 constant IC5y =
        8662265500364124139173800264947347779763302416509397176657796503980094147581;

    uint256 constant IC6x =
        14732989647838130040786250728239090276946267221346843156768030270827400975966;
    uint256 constant IC6y =
        946493575295287367571474427492109125863961954857918960872236135193710593031;

    uint256 constant IC7x =
        7562424929694348730271944732657076348228931792194161557718036259452395026996;
    uint256 constant IC7y =
        5321643835150886773973175281651302225671542462105960329469274148959084176044;

    uint256 constant IC8x =
        13027472026358813274934915930458828630318065695760580068520290090869565462796;
    uint256 constant IC8y =
        6715072722029597898795980447395945987822188872674127984413038896178121028188;

    uint256 constant IC9x =
        5660399149401608655454783435674123760628771720448101900534153940596597770259;
    uint256 constant IC9y =
        2278843221144402362588910225929980963995444045310879759921124763849679386692;

    uint256 constant IC10x =
        11087212023933173777732231426226976203832855210954333721612908349311948256997;
    uint256 constant IC10y =
        9843387723928202351134591438643472889839928778218365762330898194806145714404;

    uint256 constant IC11x =
        5189235370204578628966690469179840777219646803715112805486336756984689492831;
    uint256 constant IC11y =
        3878743718349812263103795527136143797969543896613479163520020791111453937242;

    uint256 constant IC12x =
        19313460175327534439352728719066995532279874704486025030878938549980965509610;
    uint256 constant IC12y =
        19347479739002754849896144675462177156075654624231126843698076704079493706937;

    uint256 constant IC13x =
        11578336740605834122540891009289139263831643305086916437661537244860810223192;
    uint256 constant IC13y =
        13359248929552921510454792728738982764424298609670322704841616594234524618904;

    uint256 constant IC14x =
        19262267666638760842848389953386212685407977468658548858407049541548226857237;
    uint256 constant IC14y =
        12344670200364634592608326142437828301948102208919643724633957958668971274938;

    uint256 constant IC15x =
        6488790413895230368684734917547858125203611121411877445903833049512989197497;
    uint256 constant IC15y =
        16775065064533937677275191515042571378642987252374176365714321656294214406811;

    uint256 constant IC16x =
        1323692164403925840254063758081253084974425319245111578010828726462227949806;
    uint256 constant IC16y =
        8913244059352882722903104005337728812117762861811337477575354128926197955529;

    uint256 constant IC17x =
        18354512179288412467926880343652754098253615607039368820467335976078055526581;
    uint256 constant IC17y =
        1373962555960140115114469014405997435735867606545483917691583985971649185100;

    uint256 constant IC18x =
        3181442806032100597619216915019748551573653804554223342134075675826637260940;
    uint256 constant IC18y =
        18929553220161880330191538045695037547107842217254371835555996187635200940074;

    uint256 constant IC19x =
        2232394062129169365827133690267596457211001461680198574553577112089428553873;
    uint256 constant IC19y =
        947225121665308810045531032648462490277752007662444128306653784072745247189;

    uint256 constant IC20x =
        6018014706771457285761674345313013551834801710674466905685997827460548111955;
    uint256 constant IC20y =
        16596770102719218692858992924416772172223676425918562749054807776569618488435;

    uint256 constant IC21x =
        6311575936851210225814578342825474758073557945345787471858163926343353974490;
    uint256 constant IC21y =
        18614929150012532625596502356511873833102151552342606525649020789341283768516;

    uint256 constant IC22x =
        9298359328115434796061831769594446911496415249156114968295408760515359604264;
    uint256 constant IC22y =
        3239596412612230133509798345513010665455913937790562841996360218677975113678;

    uint256 constant IC23x =
        19434132282923507844791185538231355395038391542573614716989761550961520748726;
    uint256 constant IC23y =
        721833883915305222729904125536985907178895661887232021722261614359146152192;

    uint256 constant IC24x =
        12418241980626213883263267285042418392755272511067304242014608527507754648183;
    uint256 constant IC24y =
        1724065817876447065473081963400558562970906632730814492258297354050416324653;

    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[24] calldata _pubSignals
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

                g1_mulAccC(
                    _pVk,
                    IC22x,
                    IC22y,
                    calldataload(add(pubSignals, 672))
                )

                g1_mulAccC(
                    _pVk,
                    IC23x,
                    IC23y,
                    calldataload(add(pubSignals, 704))
                )

                g1_mulAccC(
                    _pVk,
                    IC24x,
                    IC24y,
                    calldataload(add(pubSignals, 736))
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

            checkField(calldataload(add(_pubSignals, 704)))

            checkField(calldataload(add(_pubSignals, 736)))

            checkField(calldataload(add(_pubSignals, 768)))

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
            return(0, 0x20)
        }
    }
}
