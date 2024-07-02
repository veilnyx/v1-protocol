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

contract Verifier44 {
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
        15041330094940463636035186547382116665107028110625708649311807705939178909116;
    uint256 constant deltax2 =
        13881481062937482870425575029465881631570972524575197690558561519818048992108;
    uint256 constant deltay1 =
        19805111297742856912031985226761007764849545051528908596666319801714599214276;
    uint256 constant deltay2 =
        13499949312373052549415065454926744139652220766624232383445714076812051936072;

    uint256 constant IC0x =
        11756076703429797667355904349835673879132742980973386391440641502522445402747;
    uint256 constant IC0y =
        7427424824132921875864288752043208839880053930417568885322044563939456296219;

    uint256 constant IC1x =
        21226060458650898528434733832515814389192613054571677890709827438377178515939;
    uint256 constant IC1y =
        10291954931696723913951316238178940461290738653807196312279322968500707116891;

    uint256 constant IC2x =
        16218643817633447265071550608067590127348472644954724129013111863470864675297;
    uint256 constant IC2y =
        389205299387959911382761848219103296425806179886518592387696460883356786540;

    uint256 constant IC3x =
        21292656419853632285750480007344612770219742032295907670133999465387165068444;
    uint256 constant IC3y =
        3962357111566463272693333520432365335173976968587729894124898250174457208350;

    uint256 constant IC4x =
        11994412119108140505580196101947495603505270756158499829164648846540808120565;
    uint256 constant IC4y =
        12626085351207072071057204433350038613887193765681212108153347822440957028221;

    uint256 constant IC5x =
        14206281528666757979792946268850965722673462121283173671715431698559468492377;
    uint256 constant IC5y =
        24702644891980159659561769359149980516192342899404392924907039168123596637;

    uint256 constant IC6x =
        3955901906384721885560872884576105795392563789769859205311149477039561033035;
    uint256 constant IC6y =
        16273650897388560561481081464778995682249525397442101296531580152686767702026;

    uint256 constant IC7x =
        17230140885861721640129881914964115682617511676761799342877986521678466765565;
    uint256 constant IC7y =
        5774720749558089568405604499696131754731624499849890503266084736594474669061;

    uint256 constant IC8x =
        9698227221504040791759635841680615521973579694628370163609869699288468150630;
    uint256 constant IC8y =
        19717196367155872396187478552081511070089881392173050661800212137590622465903;

    uint256 constant IC9x =
        19565562129272221361006214682293531889766484447867080570038252348923658811257;
    uint256 constant IC9y =
        10796376842977846327802809375939755992351565798777668691626216036920859337014;

    uint256 constant IC10x =
        10261870474385524156334712544709921391687594136250432289256694636287175081992;
    uint256 constant IC10y =
        20564992887822087905266378866046962059463946235588567459704270426998429547048;

    uint256 constant IC11x =
        12122204241437765109297140789299236579398652758223193166625853214689359467901;
    uint256 constant IC11y =
        8108782365418103757387391409632916985696413340854370963663530574288648004551;

    uint256 constant IC12x =
        7591349439667291823646388289956405732099937548344008013180726849618097200652;
    uint256 constant IC12y =
        13560191166327791571459302967191078068760515058041111474792365885428534134021;

    uint256 constant IC13x =
        9287598013185741121346832906198311734161781242768503212613149580855055686374;
    uint256 constant IC13y =
        8782686230072809356817249837910371396693973787169198121543510893605825103161;

    uint256 constant IC14x =
        17311192919850948795408090345614727851690290901293139469374648551646686995825;
    uint256 constant IC14y =
        16835676277231190248163476297436677631379517763822491330552893306476377553970;

    uint256 constant IC15x =
        12314073736005612789984619233433619742222258193863435172726311225242413035258;
    uint256 constant IC15y =
        9400512711152181051341173040475127501746790604984851945395721412553138434070;

    uint256 constant IC16x =
        20492217929347268871652424515466290038419172448603035033248120297581271402084;
    uint256 constant IC16y =
        21047560417472845852830646165470035401039707584757960549089103300606205618320;

    uint256 constant IC17x =
        9416808155980138034992679163449212312161606441578521320472804379031894476376;
    uint256 constant IC17y =
        20731972538171991287866240217125221489433053157637271552981841264890379341242;

    uint256 constant IC18x =
        18247389633997334369753057621213570599280430813700627409868072909707506406664;
    uint256 constant IC18y =
        13307028426998408382724121430491051358061046343177389285462186133948530115763;

    uint256 constant IC19x =
        13606185772650013365916027325622614873400333534257461717067406494976089678624;
    uint256 constant IC19y =
        8165085956417888998271938129246739718881056455719261486001060131955901886377;

    uint256 constant IC20x =
        15556103697124018063768881326226122574299365206592121566862890856481997809764;
    uint256 constant IC20y =
        16987329875562543409773000509265585443398391282990496802234835619048358385181;

    uint256 constant IC21x =
        14883251496999084538835444943546603681889084014197741645129775256872019707248;
    uint256 constant IC21y =
        8368027046577766796049809826454185781002830853444634350099992131896731481243;

    uint256 constant IC22x =
        17500552802494268080417770206054220264601048282900285945572678233847311670429;
    uint256 constant IC22y =
        10544263724932233491266823415269514015118537775697582356838952792232861712560;

    uint256 constant IC23x =
        11088779523271215416060770208026373586886408532082679841560409153357875699358;
    uint256 constant IC23y =
        2924400978552626424563651723803824699784564953223674567657217089253620374445;

    uint256 constant IC24x =
        11567417229130072243777890364145517867374105140551296134170853937200775623578;
    uint256 constant IC24y =
        17168957756976980773523398953944785140678917851569516567960169378119988053310;

    uint256 constant IC25x =
        6657881006506593541110747384303034350071383279009508582626653429585372290051;
    uint256 constant IC25y =
        6933801729318627645939050589430564207455619671224849000637448942526542996236;

    uint256 constant IC26x =
        5543963044235976152408368788552035291314325320414720480764669875036850587045;
    uint256 constant IC26y =
        15983406410446066180646881154256307209931057472243039976161468636676442133811;

    uint256 constant IC27x =
        9326991824428094850791335189366426340963337223381982042724306554753436931311;
    uint256 constant IC27y =
        21726803072181391129066925770865359536950386077153918766364710648547749539400;

    uint256 constant IC28x =
        2786709144240340581972794045557031599462676035143745888357069084048492692014;
    uint256 constant IC28y =
        2557228185026970795412088233353032616491615610837905667113478051999310611138;

    uint256 constant IC29x =
        5985207074416076409902968652941405541780038966252164922993355237688631388024;
    uint256 constant IC29y =
        12165330001590355843781770998313221491071441105649093653236238605352827785623;

    uint256 constant IC30x =
        15660977976647856491424770794438830684698305996142493850739934788959795033855;
    uint256 constant IC30y =
        20084086459220354187415481557771495869243310319431104423692272593611837296699;

    uint256 constant IC31x =
        14594890774785126573328619266834399394000217433094974548583097950554835694366;
    uint256 constant IC31y =
        17455607052013732674983486010923766359875864704256469528284142100694932828024;

    uint256 constant IC32x =
        21339874177803925871641812508686141438677141986636764355558905418822651337213;
    uint256 constant IC32y =
        15772830533539099281037403014743842197883959775377462466593984535924870530334;

    uint256 constant IC33x =
        2775546578846175922245271419796827295176644465004743978129071745814371728106;
    uint256 constant IC33y =
        13027275292675469694186827739042769333175488227559598188238252083421498775071;

    uint256 constant IC34x =
        16461647451976441841558400404643518247514741158976124600025870720541034961844;
    uint256 constant IC34y =
        7251929953892220865956934608198446637345498546411778530197974748197283729033;

    uint256 constant IC35x =
        20602737314061553597456223971867356886048266930984366367675194726542896963071;
    uint256 constant IC35y =
        5243424751768046941568276184869680440679745494351964522859652936119593367631;

    uint256 constant IC36x =
        14566082677241269975169877950595074830818805891148538650194534174492419638598;
    uint256 constant IC36y =
        9236996077390804204674315194201295689034877106659549354172495033866888770045;

    uint256 constant IC37x =
        21077921697184369487371482944422887284387866803879700970284900071989242223961;
    uint256 constant IC37y =
        3649606549371794085703224108286977646689992192917699945917416583174414738895;

    uint256 constant IC38x =
        17057181334503320224022786135335316298499747154805854816820762720619357455438;
    uint256 constant IC38y =
        1558951327125055506603418774147069879232871097777309612695478969495792722015;

    uint256 constant IC39x =
        4483783988339283519979419847442377170265409743314586418890878033768067083575;
    uint256 constant IC39y =
        16044703795814100037291831733798119968830913751414949716910348898310282092355;

    uint256 constant IC40x =
        20106937947267824077324238111645553046137212725632672947949089688836809085156;
    uint256 constant IC40y =
        6990030514630484818025958803135627040437449402905658329927713311310105441393;

    uint256 constant IC41x =
        20707934074126340331466997242556090784511491159810822167580770447431375282520;
    uint256 constant IC41y =
        4142173084772992565314757269346958371162014920432321807783690995670900316513;

    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[41] calldata _pubSignals
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

                g1_mulAccC(
                    _pVk,
                    IC34x,
                    IC34y,
                    calldataload(add(pubSignals, 1056))
                )

                g1_mulAccC(
                    _pVk,
                    IC35x,
                    IC35y,
                    calldataload(add(pubSignals, 1088))
                )

                g1_mulAccC(
                    _pVk,
                    IC36x,
                    IC36y,
                    calldataload(add(pubSignals, 1120))
                )

                g1_mulAccC(
                    _pVk,
                    IC37x,
                    IC37y,
                    calldataload(add(pubSignals, 1152))
                )

                g1_mulAccC(
                    _pVk,
                    IC38x,
                    IC38y,
                    calldataload(add(pubSignals, 1184))
                )

                g1_mulAccC(
                    _pVk,
                    IC39x,
                    IC39y,
                    calldataload(add(pubSignals, 1216))
                )

                g1_mulAccC(
                    _pVk,
                    IC40x,
                    IC40y,
                    calldataload(add(pubSignals, 1248))
                )

                g1_mulAccC(
                    _pVk,
                    IC41x,
                    IC41y,
                    calldataload(add(pubSignals, 1280))
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

            checkField(calldataload(add(_pubSignals, 1088)))

            checkField(calldataload(add(_pubSignals, 1120)))

            checkField(calldataload(add(_pubSignals, 1152)))

            checkField(calldataload(add(_pubSignals, 1184)))

            checkField(calldataload(add(_pubSignals, 1216)))

            checkField(calldataload(add(_pubSignals, 1248)))

            checkField(calldataload(add(_pubSignals, 1280)))

            checkField(calldataload(add(_pubSignals, 1312)))

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
            return(0, 0x20)
        }
    }
}
