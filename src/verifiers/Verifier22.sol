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
        1483623973106813643915368755599934059176490332641410470048185146710194736707;
    uint256 constant deltax2 =
        6680777290070068232016003786582113514304942422903228963705741875124751854557;
    uint256 constant deltay1 =
        17225883478370877953195223576121407877148240508782569301529834257179191396253;
    uint256 constant deltay2 =
        3891177165411998186867060495592340938852125256654885135350341235159390873728;

    uint256 constant IC0x =
        4245093963117308766764215552683512348590916335674867863218055088313103109031;
    uint256 constant IC0y =
        2561777721700087177526667318577847274019283412435478391245317634368644300992;

    uint256 constant IC1x =
        9401195968435412943688079664902151378663331851842775617621194086974653635142;
    uint256 constant IC1y =
        2323558258310773805838147502884173651128977753623251090474620423469611287485;

    uint256 constant IC2x =
        18303193729125090091020760416348482234917162588772641508243890779556699960443;
    uint256 constant IC2y =
        4802488995300140325303224214323696792203781194474823407794273011559970339317;

    uint256 constant IC3x =
        15184620395001771871261243870756673208043729698672934412368975353596007883383;
    uint256 constant IC3y =
        15460182281303989555267090445702855886124044720218992117523561750864774299528;

    uint256 constant IC4x =
        2267551555787171414335402558677968553597967357575023929941555689839139607726;
    uint256 constant IC4y =
        16902952500311718694760643736089125465778805486254192803600158981936193202223;

    uint256 constant IC5x =
        20868929075977505590477819758020870641909304022029379958306902793264258502318;
    uint256 constant IC5y =
        1184757306582839455103983464855507385368461571935091518538643637368416148900;

    uint256 constant IC6x =
        3130348517639444212802748103981725277477465543492645123117588577465010413749;
    uint256 constant IC6y =
        9471472599860498708698503415016206757716173863973554835386106724609103165554;

    uint256 constant IC7x =
        9846655748574734593853381506227600320141279750784065450326512263889537688826;
    uint256 constant IC7y =
        17703160277645208007996989911170002056769260682252922876953144232375455859400;

    uint256 constant IC8x =
        12371566633105299417761158786537106984331353228261977702865014060322255864004;
    uint256 constant IC8y =
        385957137161577773648638172298493651163201988651412090068347682159322614885;

    uint256 constant IC9x =
        2913340887073772233042068518293687331714581216512684649278986665340876588946;
    uint256 constant IC9y =
        165428152507365222460962420211353211625449451837891564048226879847095625082;

    uint256 constant IC10x =
        4876640225662741514511129378240434641403419073902145616992896055325918926696;
    uint256 constant IC10y =
        21684546888888481456958392424735290241760232802260880119720489050003225516542;

    uint256 constant IC11x =
        3525547123926410729267715936210649477920870497465802276673316255928680246020;
    uint256 constant IC11y =
        3474041246650894765106921964483748259324432831743974130578952418765385301344;

    uint256 constant IC12x =
        13333962437497426487131992050400491980846148201387769603948139475154684373783;
    uint256 constant IC12y =
        19585253281986010376244950419767664969624356234437532857805438183915093792634;

    uint256 constant IC13x =
        5797262934870289565682512687542823285966167837689570719650663431483309021886;
    uint256 constant IC13y =
        12358655731574480430580243465454907075418312405061916355959062304278631873821;

    uint256 constant IC14x =
        19710042200820786115130286359641485604108083627430651406186363952982356342037;
    uint256 constant IC14y =
        13393366008168227665568006386361617130442437249515472234652572150196650654444;

    uint256 constant IC15x =
        9087150265491718822267758474974051427136983501024537133224594067245748429489;
    uint256 constant IC15y =
        21024420848536554659674631943713890411573797356926332504386942916022138304676;

    uint256 constant IC16x =
        370665170106093969512331876739513548974673716352369096879824236160199977048;
    uint256 constant IC16y =
        9401280987895496715480621788604087491808752209927624293223626736218214838022;

    uint256 constant IC17x =
        4786130004610024390296436142615277913155967397774849543358726403122146157979;
    uint256 constant IC17y =
        3918195249881803438353121437361610020612121916851555664525188495990454683935;

    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[17] calldata _pubSignals
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

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
            return(0, 0x20)
        }
    }
}
