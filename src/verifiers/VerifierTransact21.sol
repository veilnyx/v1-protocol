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
        6383387624257071255101909681458325123573292456676024113199875405216517410482;
    uint256 constant deltax2 =
        1930623923612113351656592550669371479614858606635264723721207292879502955274;
    uint256 constant deltay1 =
        17684264902453100182813929283631931684784768847709300813604127971609929643926;
    uint256 constant deltay2 =
        10014758929530091523417613804297458499735672030342957131966110583351708279692;

    uint256 constant IC0x =
        1920064305128344875511550448205372884461500379375747998360822853602770855869;
    uint256 constant IC0y =
        2754632263066117722649212745601601214579509642843985312839447051229815958489;

    uint256 constant IC1x =
        3080858142299962832076173193663515376973876628779221011863638564811478434509;
    uint256 constant IC1y =
        20505829881942554894254045691035940547228388376758333662319680033744096231600;

    uint256 constant IC2x =
        14666780025836664266777930068983968663624852778531302454807286573979523389588;
    uint256 constant IC2y =
        14817915074966941326713695937719022561503444570710500045302897861031931555030;

    uint256 constant IC3x =
        6425669346557053543348543866014999974822811090943071618404918714133880026407;
    uint256 constant IC3y =
        16346862994935712841025152474913853701308590421178219917306671829236619684840;

    uint256 constant IC4x =
        19811724025733599116150871206658421320963567167917866166873425261779055773061;
    uint256 constant IC4y =
        16951498852612668609538197864617388405271146572910984105172365724465645257040;

    uint256 constant IC5x =
        12027247260835008679128412173105133720271346359108230451908980652332109759840;
    uint256 constant IC5y =
        19750005325300361664295364575779759332583724956287960011104420436459197306517;

    uint256 constant IC6x =
        13104605855532713141445841643763078148096544842818997909076361305443567073551;
    uint256 constant IC6y =
        2799174736384524963282901582721765353590762602258925714734567047936131429959;

    uint256 constant IC7x =
        21159342918609901428785977819668146057782082910799692538844895709317153308186;
    uint256 constant IC7y =
        11999742924699281660918966416832510858845666028911104202062332229059365709111;

    uint256 constant IC8x =
        5927545210022148999194828367240403967438375615723245505497168736485190825177;
    uint256 constant IC8y =
        6122227296286703128860774968148983323343826754489131204568640490915361961569;

    uint256 constant IC9x =
        299563382805593631714833431065607439138969894661861931421881610731376260426;
    uint256 constant IC9y =
        19743021789703754499371778997371329174821528974917524127004903174809194888465;

    uint256 constant IC10x =
        8720404040493674336305535353214077119038902665069529592699705334137421336269;
    uint256 constant IC10y =
        14706450756612212698765063041570374025504390831782278109057383805371616779348;

    uint256 constant IC11x =
        11245616087825976512661593053516554210551652417719862695232900161455248238082;
    uint256 constant IC11y =
        1156185832852870353627674992839060130725890120291886999457829039746959658683;

    uint256 constant IC12x =
        7252235426242748198932264023390537093248410258657676086858693850394248033318;
    uint256 constant IC12y =
        16456120911901844833779918831313504741603767032905816596654610682610236766593;

    uint256 constant IC13x =
        3409584707395838589544792871922700500681004579405126934026795154225066085939;
    uint256 constant IC13y =
        11721153599031735944911946199044308961501128011130290419908507122884943997408;

    uint256 constant IC14x =
        13361992728300347775956133288730315147630870177367865773354068217227214187872;
    uint256 constant IC14y =
        9167525136930345276429798303512239560324891708522354889558834945697777898260;

    uint256 constant IC15x =
        5186783246139788436235480123794338942156322079823410340309689262409691621884;
    uint256 constant IC15y =
        17789367053486523355173892469646330235265127199633343981858812301051154049120;

    uint256 constant IC16x =
        1984157760661390049792927360995608649163907485447139299902433103964967955797;
    uint256 constant IC16y =
        2978480760536830600194151640958327391560068908860809474672803247929469273563;

    uint256 constant IC17x =
        1056380611290890092328051352794337403188706396728982204494065604489328268905;
    uint256 constant IC17y =
        8246363333224457283131626043698694416200939535466295690193724330987169444817;

    uint256 constant IC18x =
        3008594645900847193741515984751689913272858149361082853942511001573351739730;
    uint256 constant IC18y =
        20196198732202110653932474310681631283368795672764474073263191021489807562088;

    uint256 constant IC19x =
        5454669912399938952152843834645149171998743978936024076545074184830680274247;
    uint256 constant IC19y =
        1669110909576101698059522610475165096813812450279480065428494934812399401384;

    uint256 constant IC20x =
        16259572926384611517595876437620677611025930758015347377301026370607260040925;
    uint256 constant IC20y =
        1093656033769500977876615463178441818859768285498636678163965000754780748034;

    uint256 constant IC21x =
        16282685022441141908000586674458685235884032206438875951788364021320730297980;
    uint256 constant IC21y =
        17223516265825510803875348399928260784448132285222664294711416161774043370618;

    uint256 constant IC22x =
        4916959875399332681521245786317282593575398976852278287981700468566701833403;
    uint256 constant IC22y =
        14864295652759517740727834852264064507328260819834898626870838622198332215764;

    uint256 constant IC23x =
        9722643798321498944240246414815640631606812515066526306287850727654777362970;
    uint256 constant IC23y =
        731668803190514221052359665596376844919832199384643126986558605415877988782;

    uint256 constant IC24x =
        19484223295149621926699417969692434682286332508346145836544818681791077563916;
    uint256 constant IC24y =
        4837871105738904195294084407719962999142093369553778717728193234739542190976;

    uint256 constant IC25x =
        7241498789460911586147943198936099708572442742918621768525534484590736410995;
    uint256 constant IC25y =
        2327374151214422721734580052494242032328558020470190675202437925251618541709;

    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[25] calldata _pubSignals
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

                g1_mulAccC(
                    _pVk,
                    IC25x,
                    IC25y,
                    calldataload(add(pubSignals, 768))
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

            checkField(calldataload(add(_pubSignals, 800)))

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
            return(0, 0x20)
        }
    }
}
