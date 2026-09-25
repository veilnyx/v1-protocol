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

contract VerifierAnonymityScore {
    // Scalar field size
    uint256 constant r = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // Base field size
    uint256 constant q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    // Verification Key data
    uint256 constant alphax = 20491192805390485299153009773594534940189261866228447918068658471970481763042;
    uint256 constant alphay = 9383485363053290200918347156157836566562967994039712273449902621266178545958;
    uint256 constant betax1 = 4252822878758300859123897981450591353533073413197771768651442665752259397132;
    uint256 constant betax2 = 6375614351688725206403948262868962793625744043794305715222011528459656738731;
    uint256 constant betay1 = 21847035105528745403288232691147584728191162732299865338377159692350059136679;
    uint256 constant betay2 = 10505242626370262277552901082094356697409835680220590971873171140371331206856;
    uint256 constant gammax1 = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant gammax2 = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant gammay1 = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant gammay2 = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant deltax1 = 713887526274156105522651128191473854518191267588520203843011077955175188986;
    uint256 constant deltax2 = 4884194802121917729051678610517469794094218570253483617005672988504185897357;
    uint256 constant deltay1 = 6671978322401771563034824489928778960609332776122348630826372099331678493271;
    uint256 constant deltay2 = 1840963183056950250026914458870573568827730376221434653402346961261732855857;

    uint256 constant IC0x = 21519409441725949505408489718662871410570814649291493926625784934031130402047;
    uint256 constant IC0y = 10166481457736778356118970294647984466090730047457782969327139806530168712975;

    uint256 constant IC1x = 410402860055987025560489781076053795932747330862892272460947091124341735440;
    uint256 constant IC1y = 15174983561849577384836729218856412083139243457807398586785583190272559098697;

    uint256 constant IC2x = 11271861362910082905694097751815846373062547269522834634267169142332785702707;
    uint256 constant IC2y = 8729301788064198434063727660018621701864408180302818205314720876301643501885;

    uint256 constant IC3x = 981268411081286665705887591090649146723127643508141838329032509176456976755;
    uint256 constant IC3y = 332057700828462590336538165914150108636910343846649979178944074114315864572;

    uint256 constant IC4x = 11419071121792397351354582147550227475594395820216582191046931824858660586280;
    uint256 constant IC4y = 12777946601094956501260149707693173571180859230443058131476757146720708975177;

    uint256 constant IC5x = 11272722555850940759599916388758540317168023882756065081102354776988975271179;
    uint256 constant IC5y = 13043529045270078985187137798855450254905229730745406600799187684795512371558;

    uint256 constant IC6x = 7614282627407882928271047060666473346469954323238411975405651810856377485516;
    uint256 constant IC6y = 17817945932713878962871769913636039929989858289922822204344699645896844976431;

    uint256 constant IC7x = 20192827492591101531762754627722739494853334100691577137703890763200114058364;
    uint256 constant IC7y = 11885044269351660312476603015813667843542186672765036832524481157615909966068;

    uint256 constant IC8x = 9446086920483555889418696116305041521327283591088498005842091387725714008687;
    uint256 constant IC8y = 17740424116569361940894646237682638999836514879297064135751195083686802272192;

    uint256 constant IC9x = 15350398206624526122344865718793217998029232709366896028232642535720601590568;
    uint256 constant IC9y = 18876026539557181901627613386736704046780674813544034294586915305426260101039;

    uint256 constant IC10x = 17195006316908370171314974934045907787239288303253217250241676335711712239460;
    uint256 constant IC10y = 5438764686055060001913079562661506497570666195536248260806020023223897854757;

    uint256 constant IC11x = 19315996010821944140210689204888514037172692915790444577974183954432449524634;
    uint256 constant IC11y = 21486366534374449423660972046374185181116643135103477645810564270962054413228;

    uint256 constant IC12x = 21790546745550040061855181422811156811533427571325598669416321448104171224876;
    uint256 constant IC12y = 4088752309351481890960346571892762533506484880977234068758008067700399859979;

    uint256 constant IC13x = 5566991290607566930263364697178781819608918565528981360428535945072931165919;
    uint256 constant IC13y = 18498120681419839588194299921053504900491897963300474600196309094565541518827;

    uint256 constant IC14x = 8891508397812700665790497494336190423490945879847313041017581219655255388365;
    uint256 constant IC14y = 1371420368045201772609692977140394610920750515008712062764525853661419632923;

    uint256 constant IC15x = 16149875921839581202501346139020738389332314645792363186322851786541624281392;
    uint256 constant IC15y = 14731783288714995109906719860770277375874890525106379009436241537815087396594;

    uint256 constant IC16x = 8846799404756759617940073782434050255746157920288245806225960709424574175940;
    uint256 constant IC16y = 5253332933121127717722438338989767850618580889490569931204745053137583038874;

    uint256 constant IC17x = 3534040665611457741422392291038744481836201276965353435538661614412324604545;
    uint256 constant IC17y = 487555006163010670824636977232671887604876194621876375918696640457036625843;

    uint256 constant IC18x = 19464337439164568364284297668797354035875984495310149771646190761376818643459;
    uint256 constant IC18y = 19904548565102829443282177135081694895542064845178634147175128979049739598921;

    uint256 constant IC19x = 3861414427194053261469101171625190705878904043374553410364959201765651833198;
    uint256 constant IC19y = 14995720294207113955233681368321949657258405007781320393064477337695360674180;

    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(
        uint256[2] calldata _pA,
        uint256[2][2] calldata _pB,
        uint256[2] calldata _pC,
        uint256[19] calldata _pubSignals
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

                g1_mulAccC(_pVk, IC10x, IC10y, calldataload(add(pubSignals, 288)))

                g1_mulAccC(_pVk, IC11x, IC11y, calldataload(add(pubSignals, 320)))

                g1_mulAccC(_pVk, IC12x, IC12y, calldataload(add(pubSignals, 352)))

                g1_mulAccC(_pVk, IC13x, IC13y, calldataload(add(pubSignals, 384)))

                g1_mulAccC(_pVk, IC14x, IC14y, calldataload(add(pubSignals, 416)))

                g1_mulAccC(_pVk, IC15x, IC15y, calldataload(add(pubSignals, 448)))

                g1_mulAccC(_pVk, IC16x, IC16y, calldataload(add(pubSignals, 480)))

                g1_mulAccC(_pVk, IC17x, IC17y, calldataload(add(pubSignals, 512)))

                g1_mulAccC(_pVk, IC18x, IC18y, calldataload(add(pubSignals, 544)))

                g1_mulAccC(_pVk, IC19x, IC19y, calldataload(add(pubSignals, 576)))

                // -A
                mstore(_pPairing, calldataload(pA))
                mstore(add(_pPairing, 32), mod(sub(q, calldataload(add(pA, 32))), q))

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

                let success := staticcall(not(0), 8, _pPairing, 768, _pPairing, 0x20)

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

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
            return(0, 0x20)
        }
    }
}
