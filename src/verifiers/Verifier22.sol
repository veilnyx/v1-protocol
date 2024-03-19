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
        7020694894444356172827550317420009827647874788956931837772360630381051355703;
    uint256 constant deltax2 =
        8957785741902739755324930157275598425165021016896901253919817990614476401026;
    uint256 constant deltay1 =
        11626350407253568166061763890404694885902093814356757154838145596841918803221;
    uint256 constant deltay2 =
        17136128982767188856596409730531833842220474414184041536571697088922707926207;

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
        15018061174636514685937304464381081108256158203994110034631057482668665435132;
    uint256 constant IC12y =
        18197153718221931110520224992864335863893963218104239808920087111936282048238;

    uint256 constant IC13x =
        16864516306704950040141670764417072549908113966017584758651585932682326850429;
    uint256 constant IC13y =
        6714073479255793680078975255546208694004337208884400322131244815293320287486;

    uint256 constant IC14x =
        17324332866847036180980635012363160556387756129193687675837204820072751975221;
    uint256 constant IC14y =
        15783541948491878070571743933980595407187761763501119146876487745630679472951;

    uint256 constant IC15x =
        8606937276860965417095008610429518002529529427052804057098128478893508924881;
    uint256 constant IC15y =
        13968683940102467757244122195828977070089738689376791253757791692880649331362;

    uint256 constant IC16x =
        9056766794399315149047625103955436198825743419687969497612337137871278389816;
    uint256 constant IC16y =
        13019574155178674468189590587997536051272970241908862949127960129038668778228;

    uint256 constant IC17x =
        20818898360189247455478620067528542674133333369483892324726205599448936720954;
    uint256 constant IC17y =
        4581196322001479529050484196334649591931308468761036150084492232666449020220;

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
