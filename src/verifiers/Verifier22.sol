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
        10545181881618273644990748714215245175877217237265406126666851718913643405741;
    uint256 constant deltax2 =
        11849684884931955323203502340549824153668346206954006459463546542130220391595;
    uint256 constant deltay1 =
        13794330335534954368226122113298119369563630900581644167598469455080053032235;
    uint256 constant deltay2 =
        16758076380114030366931930427080321934864501206484207797646469518190560704813;

    uint256 constant IC0x =
        18219911748905320372631993270103937412474369359588742130101562973656993395464;
    uint256 constant IC0y =
        1248103818568693557318549221338559275661647360931666341797356817506463011597;

    uint256 constant IC1x =
        980664067169383229597301697560447266478223996387177417543236141830268220898;
    uint256 constant IC1y =
        6179584272378907700574730503337681462679018612787789772243878975638582451002;

    uint256 constant IC2x =
        12120840931200207211187808713873790461831750684001677226066368018113562150653;
    uint256 constant IC2y =
        16293114803109276490458365000699110022499081959761374397940455847999502343375;

    uint256 constant IC3x =
        8789114718942072910288311822814235620973085443926368039788863396904388041878;
    uint256 constant IC3y =
        10768929936393696675271795008304971276397746220828318683832156626319501021156;

    uint256 constant IC4x =
        6540364639117201911714966874139073094212564171069709127750370704557180884912;
    uint256 constant IC4y =
        15920432666629996059412919769808684707968552826137609676246420048510278252664;

    uint256 constant IC5x =
        2352686005844150584690730213625437034592287342537230934599648256828164908166;
    uint256 constant IC5y =
        5233505827552289513165424483877537377186287163742954572861623961710003117374;

    uint256 constant IC6x =
        21812918585286091190987283358967757375435239477575706141335474778723705139919;
    uint256 constant IC6y =
        15614611923459024995310382113184181359163122688586549618154437801347243248258;

    uint256 constant IC7x =
        14657987907443251378143065122586700951953873617734235015610085058933411033603;
    uint256 constant IC7y =
        4617814153775280429464523130276255412024587730724813581895491677292491638400;

    uint256 constant IC8x =
        19460444551749380929745057847476999813469838046724493670407293466306209450054;
    uint256 constant IC8y =
        4578244234956598452706568441860072955312774740105827257910005004411063724984;

    uint256 constant IC9x =
        6304352043460742030047982778605117655935974938990555615067704192461570078275;
    uint256 constant IC9y =
        17134681094168822442021787647202891963269361282719653569981788210651210301927;

    uint256 constant IC10x =
        2303310101391117077555642893696043638249473660342121310173160929433381410459;
    uint256 constant IC10y =
        4683086678687154705113072649912665127355319893357618471861095293381315225319;

    uint256 constant IC11x =
        13552299922972981843678865763866207717292243817645771181800268707007067211314;
    uint256 constant IC11y =
        16530075122731832872581536736065256316010830289834220615523255018012922544028;

    uint256 constant IC12x =
        5821920256969755217642404778886671707654039554531556279541423270992532930032;
    uint256 constant IC12y =
        13662233881174681002879780261567632811275755010201249051382367872712878185499;

    uint256 constant IC13x =
        16963381001079883482897231558490023687076546794609915073123010923379143426351;
    uint256 constant IC13y =
        10273728342768443885990879314451991224806668617181136879552298389069678742883;

    uint256 constant IC14x =
        13663801529625698695403783504648663552172355932297123459107824684186405381987;
    uint256 constant IC14y =
        383129315261252177459898753113753119397464966757458185371746884321302555769;

    uint256 constant IC15x =
        20197030322647015091428655830780117188383273282978989698981367812526925532872;
    uint256 constant IC15y =
        6837290822778650765435741425160752908200019254773258641539310894077933121015;

    uint256 constant IC16x =
        10382758278767101469203060814570139349056946889001210572585737687026679763194;
    uint256 constant IC16y =
        6799192988597300670304455146323408029493396946670202620059935305406845694854;

    uint256 constant IC17x =
        3786265667313466482781277617334864540425927202392592230329490248088380575013;
    uint256 constant IC17y =
        14140878944782213660603884402730621864664326108414725095010225230672872301546;

    uint256 constant IC18x =
        6773539176081335958101131282905615864118070982893550323736883179353012986140;
    uint256 constant IC18y =
        10666528865727240079630172334271423559214789434742230220369328925173972800403;

    uint256 constant IC19x =
        15185307587222219695862484069376656295072170871479527193271468889267843475384;
    uint256 constant IC19y =
        2974283578706100550442871822148001532694327660754720377884115525133720867754;

    uint256 constant IC20x =
        17859018220770317917959644325749987226902944233825338671042416208918878052735;
    uint256 constant IC20y =
        13718561362484288987949222827348495654437107048537969251477060876230404344939;

    uint256 constant IC21x =
        613072276461113842152956397461666583914625968369830785047578572970182927581;
    uint256 constant IC21y =
        17421844743643938911805656765982265119378065177933419495432519328636046210497;

    uint256 constant IC22x =
        10298136942867178912892891520686623669460269421079033540042132747820117413900;
    uint256 constant IC22y =
        6495464544690462836582319733683481234436872863229306177003909047113962244367;

    uint256 constant IC23x =
        18203345839683569702744901191328812990514887814307610553722280026008487357905;
    uint256 constant IC23y =
        18876660294423849478770583771363364373632844465383085116725252991639113422572;

    uint256 constant IC24x =
        18529387423252363439535271004019172419683923026313039287364126875903094020882;
    uint256 constant IC24y =
        18921293940680842760461274526645193624964286400562050536629032174181253278671;

    uint256 constant IC25x =
        12968926103628144575875099883498951488871891736271858622349321970494793095680;
    uint256 constant IC25y =
        21538973384772863695177682710461997572355457271342502788219366275986276150430;

    uint256 constant IC26x =
        1367134246472186420808629801259143997788127307555097771362586815489611205759;
    uint256 constant IC26y =
        3548006933036846854330900939962413631776086514673103843490553131036489715026;

    uint256 constant IC27x =
        19023435009390100283939417065198974196160590764619268241159362549980796044533;
    uint256 constant IC27y =
        2764203702014013272229366225833659106742344366852720985334207422773119154691;

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
