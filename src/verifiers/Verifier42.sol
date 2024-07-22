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

contract Verifier42 {
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
        18330619731144731345304331921086766737700951607164704027799568932921483249726;
    uint256 constant deltax2 =
        19312193564279439819979697459316554498525551299719348396845428316780103220042;
    uint256 constant deltay1 =
        6967713127636045641709155899897053017535978311316103040401386052885468241491;
    uint256 constant deltay2 =
        13161688874918779130977999503742242613738971742761324896261177954102408430450;

    uint256 constant IC0x =
        16599446953200300697817637121850430941949057866920635154478780012546377831410;
    uint256 constant IC0y =
        13907296692955299127266000427237095446845065711872804687166144549312136906112;

    uint256 constant IC1x =
        19128107998807316309202063165155428274790251773766565034880517946671159051360;
    uint256 constant IC1y =
        10843794317431390441203525442463852654614963595737909230936152669312411930956;

    uint256 constant IC2x =
        3664785035317022174686083312513095371091456625522789947578861401116594570106;
    uint256 constant IC2y =
        7297270572228063483791732769361228495747488560583700874740587367406707404157;

    uint256 constant IC3x =
        4681137612532143810347213011116274997577678497527595695855375037223049871353;
    uint256 constant IC3y =
        3089549121800342608114362611217147454217091719537940694588683397397135594770;

    uint256 constant IC4x =
        6542848136427063820994012445856678210360614783224192674297997899849923692952;
    uint256 constant IC4y =
        3611943558989787439785435561825273522135890643453113537164508735843998607637;

    uint256 constant IC5x =
        15862289854456755428105892855686201731976402446672187222105068811763925228271;
    uint256 constant IC5y =
        19036387018325170211552833777214280431874221651642826366033437276160435060823;

    uint256 constant IC6x =
        10342765515340656793259607554698090763169933794579895667835570811981394376424;
    uint256 constant IC6y =
        12841691219866276439541945446446445030246370775106891199461602817445040512433;

    uint256 constant IC7x =
        9568387094063430623749720949505287134678683652165110669863770062683587179114;
    uint256 constant IC7y =
        6643040023687608712888368807932280476021217666960067069633994288965323726309;

    uint256 constant IC8x =
        18915598251716981663869782811761347409293915431137654025178560125453877913498;
    uint256 constant IC8y =
        11812489877219126941709706918469907539305515959620908636516237394611648489419;

    uint256 constant IC9x =
        8142764392823504101057323207196368183396909872915874753371229122839480394030;
    uint256 constant IC9y =
        9080997204732239530632386221279529270358893126255431147766722561982161360541;

    uint256 constant IC10x =
        14204924872950334983960299055958495711468922566971221789240683033181537012800;
    uint256 constant IC10y =
        9130346934373413031748979072267320122147723294375978834361438244394233049022;

    uint256 constant IC11x =
        11759937846341119984382025817094138743701443566980777558224244650380405496563;
    uint256 constant IC11y =
        11135075424400583826619554489922419553014808573092538628140840846627528196990;

    uint256 constant IC12x =
        20276459407296113843690165877404007124292628629348719681093083120863853730060;
    uint256 constant IC12y =
        21435507726899006895181284279886570060601872607956073524851666454797893557721;

    uint256 constant IC13x =
        9783010123739480780492950098274576306676857496656412944154094449697211080673;
    uint256 constant IC13y =
        16323603547949235964065941579029051240480360401210282800424391560806529736150;

    uint256 constant IC14x =
        2302618202142615689010889627334548012529416703155025612647283735959264234447;
    uint256 constant IC14y =
        13566662652403577815008259484840797070897529163612718585663373532568385852413;

    uint256 constant IC15x =
        6924824875182176727880271702459636137922157704123408798198748585862898713339;
    uint256 constant IC15y =
        16559365354914710204623409358310267940902475835353066776233515091612979002838;

    uint256 constant IC16x =
        5225645695188046973547426419979936078540906277226105034893419494829433509021;
    uint256 constant IC16y =
        7609228618436251453804263944043906067997921433092910242037934659276778943524;

    uint256 constant IC17x =
        8094263355005651781133167198140235772423233972294844872603517931644115172042;
    uint256 constant IC17y =
        9928219777359468178000343565337954635029105572057210082577950288920123265999;

    uint256 constant IC18x =
        1501977528022511529442265684581436558969351914033057281769029886220076549557;
    uint256 constant IC18y =
        18152877656008782518601068325250042439490341426647860216363236535610368702923;

    uint256 constant IC19x =
        15545564110547629161146274159078174018338725702521500000694958287193961071284;
    uint256 constant IC19y =
        6506525508045766147623111300283118574074946496157540611515869428654627280778;

    uint256 constant IC20x =
        7341929848796544753790120706976217708301224902159655297647562005106994580994;
    uint256 constant IC20y =
        13316026537915436139758657114040817746458560207761572683535770251874157430731;

    uint256 constant IC21x =
        17558197394272501139135797775620714449158328112230405850579985987348203370588;
    uint256 constant IC21y =
        5710255536296898422600823504682997775720568047036866256484383966320306405496;

    uint256 constant IC22x =
        5876850329967557434904512237276384929475862247375472943595965165033346791581;
    uint256 constant IC22y =
        20177306637062396788428312117101772095344628617563122608581895740655657255818;

    uint256 constant IC23x =
        10304423407834274311031329044636861168797749093606475095199572688671901314626;
    uint256 constant IC23y =
        10487537489865928543285671317049546183108105131135958553274404141250866823143;

    uint256 constant IC24x =
        3364040746070018687220421460775688714517775117730587819112495987552062485636;
    uint256 constant IC24y =
        16408616880721583560838265706417130726166055540854251679341830158026360153454;

    uint256 constant IC25x =
        18566384929228235872835758404903617443270104440566122210386935325849976537503;
    uint256 constant IC25y =
        7761492286181282595477588959953961986868664776413625257813769529324058826166;

    uint256 constant IC26x =
        11505905924177079910910358351248954508022901200702817930185882285112425188869;
    uint256 constant IC26y =
        225674079445228786704480866908645471414180165818296619149686407343797431515;

    uint256 constant IC27x =
        3864931710548141069196764687865987795797799895377007094277715195415233789659;
    uint256 constant IC27y =
        18420397229410328475799183826441543487262386978794104703304610257424179614561;

    uint256 constant IC28x =
        17872733325454600815723475956886899150583914738702032830047122603599906996062;
    uint256 constant IC28y =
        16769555522827488654447487049253127274562253317217140030017849275484383951663;

    uint256 constant IC29x =
        11073066791004277621652515654926915255356613013185110953538806176710788928078;
    uint256 constant IC29y =
        3811186041090064218145499575296242968014927513005639399023092325772085432671;

    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[29] calldata _pubSignals
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

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
            return(0, 0x20)
        }
    }
}
