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
        2239528276270704368847288377132515727203311950516466624549887135045227222007;
    uint256 constant deltax2 =
        14952871980722527348632504166849845663528325171178130669006813264202386519019;
    uint256 constant deltay1 =
        6110614301389298415341813114541915292373906733882557320399374156234079624592;
    uint256 constant deltay2 =
        6568283031802235241315643673404545982032811878369317676546937298524692192267;

    uint256 constant IC0x =
        9751505159459836352554095085386873367878457390431864752334498362344224497840;
    uint256 constant IC0y =
        9437559835364408284591808780503360087944386435130037219140563016669487780252;

    uint256 constant IC1x =
        14746282903987609746933164913434628413509044098610763924036192208701629180480;
    uint256 constant IC1y =
        1358088326248056046478991051386196244857781490249365568706032919554945003248;

    uint256 constant IC2x =
        3436815122518451913314498676727742952258727519269306701104978483937567222238;
    uint256 constant IC2y =
        7125410019191294369073804055669600654515420898471574380134298696569158359378;

    uint256 constant IC3x =
        19195840064997945206946224987938609786896081868882386430389828866047000927322;
    uint256 constant IC3y =
        20064614432258555941970390111182810021725776319956208571096182507603372761541;

    uint256 constant IC4x =
        7918979205218951668604365957952606017185715651039257173089007976739035708615;
    uint256 constant IC4y =
        10629393700471209639141321847648203541786469335555389508509982687887314771825;

    uint256 constant IC5x =
        15990073130681106138622219236447089978915633346710330660459918209829860872610;
    uint256 constant IC5y =
        11006856905548956164605654069852430738851538777658780173036270715225105851367;

    uint256 constant IC6x =
        21398809015275983133641920392689864118188217226652487341377520131363829836538;
    uint256 constant IC6y =
        10143522199530960980535924638342580892592537073116988990481014932287417581248;

    uint256 constant IC7x =
        5933210676771951140944911333571264028980184544314050880869582753990161698072;
    uint256 constant IC7y =
        12917952658878078236668219596149834160510933118814900337340445282567819896968;

    uint256 constant IC8x =
        671011320762246971738238694992444950540190991354200922406599620295188218124;
    uint256 constant IC8y =
        9312727321965692575488598373419044561556260835624259049390682888384913044699;

    uint256 constant IC9x =
        13561945748487412448806874920655899799688372434400287135101097588752231836569;
    uint256 constant IC9y =
        19710378056810526022018385711602808666563450208015918603055011236803002635046;

    uint256 constant IC10x =
        19382717884380704088179811888688744719658271829282526516257080134164452126095;
    uint256 constant IC10y =
        6884168988979484150181011616648902002132049535503013093651925723129032337936;

    uint256 constant IC11x =
        9991726386556309507712450310543528513552503854143145607837509722156483196099;
    uint256 constant IC11y =
        1857011572047197927204422093612149033030674964522123651849973155892631097730;

    uint256 constant IC12x =
        12640907064733813986457981371056545427129580991562824520896717311289724923513;
    uint256 constant IC12y =
        6872639584079869831113419136893847644948945923834832086314374104141957980042;

    uint256 constant IC13x =
        12031596636084500542441126358157010238135012177005393277362120240268889401115;
    uint256 constant IC13y =
        20454803547045881020246645425639489815325770105715187666387391954405550821341;

    uint256 constant IC14x =
        6934381666389901376008335542937373401792739774655318063652659713386780661556;
    uint256 constant IC14y =
        3019851526355217205174849142574856932247670979018267630324272190556851417464;

    uint256 constant IC15x =
        20839366428726766679121093676524733665654121156387257711108818197029164966544;
    uint256 constant IC15y =
        11815810687074244935497062661570097683323500674604689284063564085786591944915;

    uint256 constant IC16x =
        14597459594032295503438087155428400508946246164756003496135618947935526392593;
    uint256 constant IC16y =
        1138663355143104310259196992056844339786933586693568874600501775364499635534;

    uint256 constant IC17x =
        20818898360189247455478620067528542674133333369483892324726205599448936720954;
    uint256 constant IC17y =
        4581196322001479529050484196334649591931308468761036150084492232666449020220;

    uint256 constant IC18x =
        5890318765968660667926662652661182687906948530477256735109734705966887416089;
    uint256 constant IC18y =
        7483614259454817801978177511840695690701974829594610050240301845425555859577;

    uint256 constant IC19x =
        2923436835595962209182488009192014175093950105318916914595546547558164132548;
    uint256 constant IC19y =
        6541663412310022011362802630637998049219707997429679170549385898597948447080;

    uint256 constant IC20x =
        13945207561353954197239198962825613470617473946061347405717133798487122207532;
    uint256 constant IC20y =
        20738341756875017605305237724390416200504791043264076136485433887840247237639;

    uint256 constant IC21x =
        20360023323139537691987354270088797362865685297564218180820875759389047892464;
    uint256 constant IC21y =
        1849425109998144443818200490006462152757521191208378828893834961355924177922;

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
