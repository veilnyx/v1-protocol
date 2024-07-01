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

contract Verifier82 {
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
        19245558984288886587838608844166562487690792095328525325529734974406726176194;
    uint256 constant deltax2 =
        3339036162905816964822054119119980294395925040286029762220337343104551613647;
    uint256 constant deltay1 =
        12284242410034274705619911304371766699309553048966827289476528480542225064780;
    uint256 constant deltay2 =
        9053776006761745185711177657826326525178092492558045361002115148269734795697;

    uint256 constant IC0x =
        3152148878826725418135418489797403392624555666785467535823661997169841884952;
    uint256 constant IC0y =
        9058552639919514617678770389875860258545860958997627198745999979004607544347;

    uint256 constant IC1x =
        3158616748927630804754872396869078141930421047399304123998035873825324352553;
    uint256 constant IC1y =
        18168827340439192207376768217227411062900792699102006969065030610954365404593;

    uint256 constant IC2x =
        15062807132340766059931868365494964093181446896976292661311910111964882979796;
    uint256 constant IC2y =
        4922442565729802565723922633418902650611042228913247846447643411083985217678;

    uint256 constant IC3x =
        4437419627663899048373299021682434877687009532595068430923978654784812152809;
    uint256 constant IC3y =
        8890659928003733143662307079777492055065960620913825196898994919902747394751;

    uint256 constant IC4x =
        10716220238998382053354091846862840340865009428423671022387070011656188497628;
    uint256 constant IC4y =
        14487356876547352220617837834660710916957735027852009626925708663127307791201;

    uint256 constant IC5x =
        11707240258492856014687435207607733961211939079577194542477284506021249654456;
    uint256 constant IC5y =
        12830129542672187684477799240074173309155806161927651364682354153401249835531;

    uint256 constant IC6x =
        4762057793991189574777411931778527918676872547738595230942452043372553444728;
    uint256 constant IC6y =
        12677285838405488586980670276495782491167629691026781713199542074316583679204;

    uint256 constant IC7x =
        6374638124704166179294538464755078292614417914273479922612346706846646882399;
    uint256 constant IC7y =
        21100144506829010074383474983479280199751185992454747022589945665756437753185;

    uint256 constant IC8x =
        5923079654116484398670242941260596673946289853437087977631019813560219918137;
    uint256 constant IC8y =
        8994065064340659978258326475194292621867332920073788725517448678845168530026;

    uint256 constant IC9x =
        14133899553415826308708075797706735020453133810567138651557227833510336556848;
    uint256 constant IC9y =
        1481265338255295291970141169271055335681147606296092191893271265291675666188;

    uint256 constant IC10x =
        21517396232952325319252818113980389014550940703883883077785278393176775557718;
    uint256 constant IC10y =
        14392969291813057204086012007273224464015371704629225237309278378672634719450;

    uint256 constant IC11x =
        2756866493431273240477223978058478796847402626386916684558846013707786269424;
    uint256 constant IC11y =
        14500471929932604048369444201122113578720566249911970067472607223626167822529;

    uint256 constant IC12x =
        4499212294963711368028771918408494054738686225386962839869836847604588359926;
    uint256 constant IC12y =
        18271235563537032279721050758111304944678001148546441786650915342903675964575;

    uint256 constant IC13x =
        8441257763370438403764204967084901312358503220349391453163525445359757565262;
    uint256 constant IC13y =
        8724487154816107221113341667530469201955351014053048905137866531213214103864;

    uint256 constant IC14x =
        20328277112238492966603958700720564212343538485768558764085839657649781288457;
    uint256 constant IC14y =
        17127838508142992978139136473643801458041654361380620454619096242111120318843;

    uint256 constant IC15x =
        12225927678226242016144916793669368087642492424419812521007137242995941572566;
    uint256 constant IC15y =
        16518909964466210975132006581443214122381821091240758938855888054014168308993;

    uint256 constant IC16x =
        6206716237822090125751120708397595826814805077984245057796998992151334353638;
    uint256 constant IC16y =
        18767630747513564684710083310273602174253247998726581054410841748376380465227;

    uint256 constant IC17x =
        2919680009307919193302528899943271641766485978037932852495380030097820190246;
    uint256 constant IC17y =
        12765268138377783020098177784894234733090643368268257221978805736607155483674;

    uint256 constant IC18x =
        10984402395667088395606781287110706685103341993739716861838283308055589986640;
    uint256 constant IC18y =
        7913675163385186308679247982801990003243825704926407147385505739974405560224;

    uint256 constant IC19x =
        13836945672885206788783561524627422008135693845972503695714960499004223121487;
    uint256 constant IC19y =
        9194836764907898511678816790682773809382664807117858583818091451032352514890;

    uint256 constant IC20x =
        7550110484136949990285330263242314330915456737121424926412607853225788141664;
    uint256 constant IC20y =
        13584490777945820756836064424622908612335752920505465364890816959874296720350;

    uint256 constant IC21x =
        2538047912250941897511644561170722989079356931596295808404092603780835254232;
    uint256 constant IC21y =
        3139739292599527565152238527365491332974286348794377503948981008974108651955;

    uint256 constant IC22x =
        15337955136662338783382509084670801826454279809989865057342759058413824794948;
    uint256 constant IC22y =
        15579364165885501702140205983397646288993419525596877412161830656981614627187;

    uint256 constant IC23x =
        12956941682184638761040993256604511417116871824642191718844468782723092669983;
    uint256 constant IC23y =
        11765471994555279345023345274045027048889581821784582543716014230010519065691;

    uint256 constant IC24x =
        21246817951659250432141872425259882239626313646161050751013156350540347912780;
    uint256 constant IC24y =
        11006074435131096562680047858069949200221242621641724369101630034922388889080;

    uint256 constant IC25x =
        2242673031765190114883800346222634362870651600755722124089208609950741026261;
    uint256 constant IC25y =
        11222374111152240660068149685258767124068696047281314339928532912769815983027;

    uint256 constant IC26x =
        4249128336926186391890653320260688446405792928814215288815193047605328017788;
    uint256 constant IC26y =
        1483791405506559906073265270287724415834592367570778582738176930205531706895;

    uint256 constant IC27x =
        18674623552873699334859940924632457124041872557256388395161772504803654382796;
    uint256 constant IC27y =
        17766941727821554789101551324489746308496787910025136114014859360426072755827;

    uint256 constant IC28x =
        18395969135218157491518474932116473460236181184298906281687454464269272544644;
    uint256 constant IC28y =
        849948952548375768845990863773582014040965664513265573542560057750884594998;

    uint256 constant IC29x =
        21496031637901532294453193008706872196807632108932421740722929867011865427459;
    uint256 constant IC29y =
        16231213810973620321220759562406245246608391636932619991725922568129347065498;

    uint256 constant IC30x =
        19723933090491130299142103922389557095834218962356249523843986799333696119230;
    uint256 constant IC30y =
        17045065285310149779201838340930222928338078039181872428643705385332648115607;

    uint256 constant IC31x =
        9478621137976023265162832675751744516824390499894799070956504344737818409029;
    uint256 constant IC31y =
        3288439876484070543126882321672613055083484077160516256142498475115220344102;

    uint256 constant IC32x =
        21335106943372543748625969813249373692761683629477002797461047010840426099129;
    uint256 constant IC32y =
        12531977966378783078870684481530476087025070706599561417418093620428772514507;

    uint256 constant IC33x =
        9424321033294096510326850937579060202143160597070862901762213503976152892184;
    uint256 constant IC33y =
        633379109446245670771688093569556370138162374760244556062352207517077149049;

    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[33] calldata _pubSignals
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

                g1_mulAccC(
                    _pVk,
                    IC28x,
                    IC28y,
                    calldataload(add(pubSignals, 864))
                )

                g1_mulAccC(
                    _pVk,
                    IC29x,
                    IC29y,
                    calldataload(add(pubSignals, 896))
                )

                g1_mulAccC(
                    _pVk,
                    IC30x,
                    IC30y,
                    calldataload(add(pubSignals, 928))
                )

                g1_mulAccC(
                    _pVk,
                    IC31x,
                    IC31y,
                    calldataload(add(pubSignals, 960))
                )

                g1_mulAccC(
                    _pVk,
                    IC32x,
                    IC32y,
                    calldataload(add(pubSignals, 992))
                )

                g1_mulAccC(
                    _pVk,
                    IC33x,
                    IC33y,
                    calldataload(add(pubSignals, 1024))
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

            checkField(calldataload(add(_pubSignals, 896)))

            checkField(calldataload(add(_pubSignals, 928)))

            checkField(calldataload(add(_pubSignals, 960)))

            checkField(calldataload(add(_pubSignals, 992)))

            checkField(calldataload(add(_pubSignals, 1024)))

            checkField(calldataload(add(_pubSignals, 1056)))

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
            return(0, 0x20)
        }
    }
}
