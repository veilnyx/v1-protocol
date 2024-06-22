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
        11425883966504525850816167257353012729888068036459414230924434621194513948360;
    uint256 constant deltax2 =
        9842961948056091662436222924801327119999183589752460068613227511272989603356;
    uint256 constant deltay1 =
        2175955614900566782465915559511473641065996884983589032335321101329342048125;
    uint256 constant deltay2 =
        12185948059772206902849651771093496086246379949868032457719134759794103207741;

    uint256 constant IC0x =
        16310636060628792555680396927255072395290321243944200568996937944931699305663;
    uint256 constant IC0y =
        17204037003273970697983578057883195560881443384810393607978790845411022868661;

    uint256 constant IC1x =
        21521138196152506250093252552270199386577445364741971347437659153005918165970;
    uint256 constant IC1y =
        10719356993492176801544661683462277002404463690427487295763096425340766212858;

    uint256 constant IC2x =
        10324542356643708672669541242316028585947112296066008906564244514678899074104;
    uint256 constant IC2y =
        1705054546694242282152974537518239388337678101591293467137021232960712863246;

    uint256 constant IC3x =
        21541697174363366066667841562215644796694926490941145131935326358326473701260;
    uint256 constant IC3y =
        18961267438749041085553331582755538941559810145868774053183528815446016744590;

    uint256 constant IC4x =
        16687530516343187256590692530099759224105953389531895861156417299803839256201;
    uint256 constant IC4y =
        11514022955985745272309619061812177057793301144985288852009364498530201006861;

    uint256 constant IC5x =
        12485206174629086069373086463016795003384636982831448736925048031677585037160;
    uint256 constant IC5y =
        5720594575749106905069618195007015432357313046326114888010878454072645434813;

    uint256 constant IC6x =
        17231122778737386334564416029717165938637497548017263650675018077762860691800;
    uint256 constant IC6y =
        2141729015442667315325734618143376225494175084255971413031314521000241190081;

    uint256 constant IC7x =
        637011459829591525610295796164755713932237836737292497568508085678687221273;
    uint256 constant IC7y =
        11057318738129979585737901593777368799465515255738636562543519988610895935325;

    uint256 constant IC8x =
        12249066205123171292301965767425276830378463474212326575848280370357515768369;
    uint256 constant IC8y =
        16662799740765001451541276046674917908324776405203222262083204154948502888346;

    uint256 constant IC9x =
        16347470199765514732185757356569581559686688366562305015078056434027814823577;
    uint256 constant IC9y =
        6111481500335356118240181309030198452936959500790614619687882485712962789280;

    uint256 constant IC10x =
        16152235017740289820148971058420033887211627537129930953000474124099602940977;
    uint256 constant IC10y =
        18448737563203607173824514675733766005402180604273583958093011427959160639294;

    uint256 constant IC11x =
        12180707415625067405074654672180156494551497394618542094161251398526477550620;
    uint256 constant IC11y =
        11520794150374925613887800484077401584939874638291793069726303008537917148742;

    uint256 constant IC12x =
        4725774575232842742471475804276922239293970636185007917969947833953089797158;
    uint256 constant IC12y =
        14648748227665148162048238318224688145314143199019492716670827130516033797780;

    uint256 constant IC13x =
        11247436983655504763785587952709258048211001231005616346440507605115029473976;
    uint256 constant IC13y =
        6245525771482129095192021967856349449801868269784849588462580027062886256159;

    uint256 constant IC14x =
        10576025591747659231798176805293433240618411313401920274998549400686817432694;
    uint256 constant IC14y =
        10839999217316323864172497360590920657525641123829463172493502294751880883491;

    uint256 constant IC15x =
        12831930148686945160647575657152853538559838703126179099994365088645814023023;
    uint256 constant IC15y =
        1679993247309132162380714939679417715236203230001463985648091296511654535114;

    uint256 constant IC16x =
        5230635084059930244377239257236306111539442489168974278544705117350721475742;
    uint256 constant IC16y =
        759654750417464448074921817821773814818556679946302636733019621588042645805;

    uint256 constant IC17x =
        15225633256079368622751097203879823673627796714872288175742095043418413435758;
    uint256 constant IC17y =
        5118318391622186283082769865678988623115236024275284687549750023486171984679;

    uint256 constant IC18x =
        8745636172966363314981776386390223696104643936672707720965842310518256221303;
    uint256 constant IC18y =
        1929092253718092030085267981552143295826243709408345264376830813505190924907;

    uint256 constant IC19x =
        16413808145518512545346414944962314193241083336553343955144367697776341776287;
    uint256 constant IC19y =
        3051409955688727713688393340632604625734410593599455362739626313728874648367;

    uint256 constant IC20x =
        13791333375316324990299917830652079412662586045042780171099659960712449595161;
    uint256 constant IC20y =
        12245959009675666269374004517934427522251181554695830309892404973404341216398;

    uint256 constant IC21x =
        9015230565257076346776615230790463109321322564244387322045465758501055486520;
    uint256 constant IC21y =
        11522292341916160316886800513832650140454324756083808732213787209332329288798;

    uint256 constant IC22x =
        1017723957582391363417683138027598548982673018763909765162344347436787711304;
    uint256 constant IC22y =
        14467521044542580975799228328883067538152172652285931275689442045399453035711;

    uint256 constant IC23x =
        4258108217815375827580322801953737311928333234910390962507409839780869407255;
    uint256 constant IC23y =
        13888483116163627132326844453476443496599587437374480050181934047182337717023;

    uint256 constant IC24x =
        17531906017716672304265530718943497764079020831104590675923927352000078967880;
    uint256 constant IC24y =
        3617874619880616974787914343887849979149898052772945568429967641636659276624;

    uint256 constant IC25x =
        7334088347661070826309968002038018452247662074993441234018839414979586635624;
    uint256 constant IC25y =
        18773218716883637089123712315180950896822171845010461652529153980766455845205;

    uint256 constant IC26x =
        4523147165541933467612680779298987425371630383061368907708291485837620994396;
    uint256 constant IC26y =
        6287288963200574503095243524126979989311275738402885776535078048031673458525;

    uint256 constant IC27x =
        3504264524617202984085020674687634844288811335016757091682389339972403173769;
    uint256 constant IC27y =
        16255148765523517108444872933452543362581472346689914634085257976107576182608;

    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[27] calldata _pubSignals
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

                g1_mulAccC(
                    _pVk,
                    IC26x,
                    IC26y,
                    calldataload(add(pubSignals, 800))
                )

                g1_mulAccC(
                    _pVk,
                    IC27x,
                    IC27y,
                    calldataload(add(pubSignals, 832))
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

            checkField(calldataload(add(_pubSignals, 832)))

            checkField(calldataload(add(_pubSignals, 864)))

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
            return(0, 0x20)
        }
    }
}
