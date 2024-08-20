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

contract VerifierTreeUpdate {
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
        18613587571973262587448404297451608516607883923322494106977098642224346010847;
    uint256 constant deltax2 =
        9579545557612996316326229488112805349327093830758927682910091548666688952161;
    uint256 constant deltay1 =
        21678873293342687965387172548802353065384669581694997338996117207969686436737;
    uint256 constant deltay2 =
        3459660675219520684805495905446369598124095305703611801765801411778340061595;

    uint256 constant IC0x =
        15366384062377867969710978008884587978423799932905408915068123710200235115590;
    uint256 constant IC0y =
        17629762826199220890249510177810068571999996573222106148142115669008707722541;

    uint256 constant IC1x =
        7794109008609439856615362559080300401531888976848278743189551313666630965462;
    uint256 constant IC1y =
        4389910391935962095637642981534806422244490495226237326240451292821920247442;

    uint256 constant IC2x =
        3520007140632649954420431708520803215009900270886481787879127167589290220934;
    uint256 constant IC2y =
        6896230040846925159030670907340473963221689327613128007512688574653454867685;

    uint256 constant IC3x =
        3740335682866248614682591629145680745294721991887466988925309058024591856262;
    uint256 constant IC3y =
        8070652844236010377682395027793599248663888355764284742683292743803663504295;

    uint256 constant IC4x =
        13607797629277861492673114145784981008595559965192606061326152913570139411661;
    uint256 constant IC4y =
        6950656614717419824668405993019347636933592780042413858313503546365791768754;

    uint256 constant IC5x =
        14638960741095533128949460815173074966668659791025222777538361202071204633476;
    uint256 constant IC5y =
        13282969690490676663096096945005575073256726853843273546641970857575930484628;

    uint256 constant IC6x =
        14188360759710771515095318881379346597915824195456417928595673548820255688974;
    uint256 constant IC6y =
        15462840102643477047603008657586807557018672592234799754493684037004748066236;

    uint256 constant IC7x =
        10307428079610866606770817029923013554988554384334927174275221061343603538366;
    uint256 constant IC7y =
        4553954736561164488821212253656740588173663775933425012361348240243901839728;

    uint256 constant IC8x =
        4783099797482988910510878660184144644967502701145464802920182854382373545475;
    uint256 constant IC8y =
        18178734967068213432061302783368794651943172092792955897346047889418571651423;

    uint256 constant IC9x =
        2284886195171464878628599393821265428656411357641668643608698417158846572234;
    uint256 constant IC9y =
        6968970530408336835961479294255563010872402752950449792658704934305069149224;

    uint256 constant IC10x =
        14870352191737643453458814168502871306828331437152498691875235458955229527764;
    uint256 constant IC10y =
        13117109900039032415199844085347093474157316787029338295400842075514062774652;

    uint256 constant IC11x =
        13494788197610556874621748645047758616595681768730390273199709656615040935442;
    uint256 constant IC11y =
        12896553610931550975651130731152374090353744376848840330077401879014668777740;

    uint256 constant IC12x =
        18792577743254479537012083979270326536994368614250166344798551225205222674283;
    uint256 constant IC12y =
        18015526840100358637715624268616628881266924275832158752356380355650946601534;

    uint256 constant IC13x =
        17542233148099655565614968924904383830052151563770870816218519274543260178497;
    uint256 constant IC13y =
        15694972569419089574775530862683853640608724533583569284804416887238947472884;

    uint256 constant IC14x =
        13681899483496761018757603843875092607175891586783823192101301451592641308001;
    uint256 constant IC14y =
        19106908071590595292766147014663527506154102508220178893038176145432629316773;

    uint256 constant IC15x =
        18832570311534628375458556094636225547683339560299673061561817809058646655166;
    uint256 constant IC15y =
        17226403896917728771850598026644678676782610216144565171576087738367755366283;

    uint256 constant IC16x =
        3151364113528141615715676977893383319555093437165813697070129366281832150482;
    uint256 constant IC16y =
        16106507206933567389026546843087580597816247406185680243287941066975085765216;

    uint256 constant IC17x =
        17241883154855862622636030269268827918344562190464198231955349508572792449742;
    uint256 constant IC17y =
        1011284007544305935276335926646903056480548441354668182024688686652017338618;

    uint256 constant IC18x =
        12570716789324384056335375728905754169929171958955903295621165120779445039591;
    uint256 constant IC18y =
        14629533098220357712466383887796435277798930614592536503162756396200690044796;

    uint256 constant IC19x =
        19598007732715698721570912233163390588571537240521378903221245853176493543440;
    uint256 constant IC19y =
        21167983533768075165686724308228244441488695458904034925192142424141955871996;

    uint256 constant IC20x =
        9419695440382609171919350326547972709749261341605659560648246721254693151615;
    uint256 constant IC20y =
        10388712084301337654871853011105705261616006952757601481906380949706882134025;

    uint256 constant IC21x =
        11700500597809717418167067534672105467019911464754526105411438076964380562437;
    uint256 constant IC21y =
        20905165922215258769074399601936438941978762166191957448160590286327138462810;

    uint256 constant IC22x =
        4777557251028237270952505965822195169364694974016048125412948236644364270979;
    uint256 constant IC22y =
        16665565709757054531727349575408980807552411877475187168997693230008462289492;

    uint256 constant IC23x =
        9299089127272304632564995179772709709910288880835807555813790290472306853594;
    uint256 constant IC23y =
        4993316960330787954974012772741719427535027490763111607080537738088635046634;

    uint256 constant IC24x =
        1448387930132474914760447085903521443493698171670851844864846196171155496803;
    uint256 constant IC24y =
        5150906294416550241939222620356572048805667190123519050577838536473215780579;

    uint256 constant IC25x =
        7483680711206115301690619340892752148747623772993384497068287346834661849126;
    uint256 constant IC25y =
        136863141178664561194749523938552385267547368444368778849562183094913678200;

    uint256 constant IC26x =
        15061703717192878614458785146367771987345874627744976116350979422191673064661;
    uint256 constant IC26y =
        13344853519600596595466348772258647956639763916603980779285538996742323454720;

    uint256 constant IC27x =
        13359293334804038661282500989864752047111224340523240687868576063743929272722;
    uint256 constant IC27y =
        2565731580852088674123003217454450694950449073930140481356859615971478449141;

    uint256 constant IC28x =
        21305456860822523395569877233455862945262937360202795036464254468264770754968;
    uint256 constant IC28y =
        3646737752694771761550512708107842569974279627818742365634162000791600645081;

    uint256 constant IC29x =
        1669386788697352700872922488395907016076369904422296411448206107899708440497;
    uint256 constant IC29y =
        10308123772395538252068989884821298496511178779257614706141505761868306826644;

    uint256 constant IC30x =
        1830004914613656330945372666576867751052648788101825264228227184415618814518;
    uint256 constant IC30y =
        4752982034403041895690152234249919498868159246438826906377945762238921940802;

    uint256 constant IC31x =
        14878658207714080965320327610406579056301989840693905701488064417831841517378;
    uint256 constant IC31y =
        17901642563693252765965981812599594523523355205338946573446787794213598895759;

    uint256 constant IC32x =
        194624395261087249480049637860466113309094640848130384493386366598222719566;
    uint256 constant IC32y =
        17509746253450795749171569744113608176938723526148288206452799095061911146622;

    uint256 constant IC33x =
        21567706440055461687557253433314444362716083838575226864531441186539235525439;
    uint256 constant IC33y =
        16970645091083779026831215538449283636063792397493868495456005618709642600033;

    uint256 constant IC34x =
        17986504246284444199772510689882320869226873104918342506002470448919465394116;
    uint256 constant IC34y =
        21413424700264437992626655138862247531079245370670548041431613592807585892010;

    uint256 constant IC35x =
        17117276500146781238255384702370356979348304562236651300678998363469243830145;
    uint256 constant IC35y =
        20136113699956284165485214930410587565095354586057935452298255834767906536191;

    uint256 constant IC36x =
        18039964675718612351731851526624404772369827908225686086808255750798525825408;
    uint256 constant IC36y =
        14252841330672506343360039378623585771302892346454153321665793555993584481445;

    uint256 constant IC37x =
        11108094573405025051795636810340959922568727559865608641441550602328518969962;
    uint256 constant IC37y =
        7091194176083627491056375522486594855352943277557018522188005293288053029384;

    uint256 constant IC38x =
        19092311698271076248979865473304300596283537022663411729733037218815462807454;
    uint256 constant IC38y =
        13539077609555069077163029543004618775269076925086933249361265752448399244017;

    uint256 constant IC39x =
        17539166113280236550217678917070898312037607168315505448194865263540698297261;
    uint256 constant IC39y =
        15923751937029524180118350737344145714893426538076387451882220809800269501164;

    uint256 constant IC40x =
        16472945560686070844314775613095513672125530982044488852678448179996121118509;
    uint256 constant IC40y =
        15511426862909540000580327697723233043401893454121162087686804984770445540925;

    uint256 constant IC41x =
        5591541414824071045433753417692330135099851670083580348099132709030657269175;
    uint256 constant IC41y =
        15006707915334683137814016784153289622137547663217503919307333783543636062573;

    uint256 constant IC42x =
        1257201102426543833971044063635114577469311929334642531721061427339072413478;
    uint256 constant IC42y =
        1095978457734792215035402755638420374158140521448871746793829493848606759806;

    uint256 constant IC43x =
        15967943263124535593576573883765028367751677346275128171894777022675591208360;
    uint256 constant IC43y =
        13432810350928924483450369642387799955570535238231224270609702495256015565173;

    uint256 constant IC44x =
        576595810518384969583873676083867181343149491902931086417921244917212375607;
    uint256 constant IC44y =
        15963381988085512917323167723701018479464578184807466813419807369246548634792;

    uint256 constant IC45x =
        14774940359555582807865574211169722070541655498467000991424548075056111434134;
    uint256 constant IC45y =
        5909631180227805801055440980927916394072606314030770379874601876920468332495;

    uint256 constant IC46x =
        4379118081309721803500965269588177858131230463659904557326097221108942047930;
    uint256 constant IC46y =
        7451603306489168869885602798346945543246153846741920013999296607552960418690;

    uint256 constant IC47x =
        15995661113627938043197909375462386663714570667973193454291992082685876585215;
    uint256 constant IC47y =
        19004366526629354125696227628470181978366507224390090353926387584484943442487;

    uint256 constant IC48x =
        2069731765682901438824766067469989166333422179125240662920737682991185031236;
    uint256 constant IC48y =
        19848384300841519773518877428582388059871773663916009162482689791786137678402;

    uint256 constant IC49x =
        20551721929108161252636822477930004476406916073254883463694747931358308790446;
    uint256 constant IC49y =
        10252873136005299840208437025644425361219317369972132841070393686542902885273;

    uint256 constant IC50x =
        18070063253933748374135775678928104859537750762612285767895279643126759752275;
    uint256 constant IC50y =
        14950227930918617712834851274107901501907959080150506557716670181185699997271;

    uint256 constant IC51x =
        12653395220050577655742277166804809280724992361339601025457289796635135034775;
    uint256 constant IC51y =
        7063754206845569044996019870374613158231640380337022735347529109555088460084;

    uint256 constant IC52x =
        20005501534366099504140917640378310894412475841833679199302733489403713721716;
    uint256 constant IC52y =
        21058616418271210517152701758385580640064575190665161947648089784948113457954;

    uint256 constant IC53x =
        17919081475436042538333600315793614487770838636548715629064379323059833943389;
    uint256 constant IC53y =
        6908435953361878015398144433389480783631027926641646730417869802293111534355;

    uint256 constant IC54x =
        13592099309342252997863175886540739967876507062072580829919650293078417455655;
    uint256 constant IC54y =
        15278698507553584414034593727223514384518546206732482967426083062528171232963;

    uint256 constant IC55x =
        9099290326032847772515493758970926974858457935974364152552788156182329849421;
    uint256 constant IC55y =
        15967115323003568587226818469977139127002202760911942465599167837166169866570;

    uint256 constant IC56x =
        17119684736301782825190351482165605677621110193273124387427814363266971913908;
    uint256 constant IC56y =
        11508753285098087768001011380029171055817891612213873823926899354724487168402;

    uint256 constant IC57x =
        14048040195817624815920968538416887705273643166983750418093050917619769441538;
    uint256 constant IC57y =
        4898859812885525403405513185965518656019797274380490128004583126156981071546;

    uint256 constant IC58x =
        10746349496846334225719212792376786757242398571301826137240761031055488462791;
    uint256 constant IC58y =
        11445511940716298329279308259042943221578167587219420894796698433582699528441;

    uint256 constant IC59x =
        11958612814933815585991433950987287441672639453229253662620364559757785963457;
    uint256 constant IC59y =
        17448881589810765541211397957269241141049011608652461571262291311918117774455;

    uint256 constant IC60x =
        4666784686139219322761489393804400538236954465102232093500392537689055162648;
    uint256 constant IC60y =
        9883444318434617620904159094324096165528484791210906248391867453886047131978;

    uint256 constant IC61x =
        4136091256306346652981715990937435719775509334914762462321315009739851243610;
    uint256 constant IC61y =
        258084467311974653894035221035907100261470904656965281350585331832860047346;

    uint256 constant IC62x =
        21697917901897201572346153049049997332538696676113753658335340037767960231401;
    uint256 constant IC62y =
        589960384099247715263639602081324982797684465188597954246892710824164996536;

    uint256 constant IC63x =
        10170747664781140930562362689420671312952973541530649638285544212393391094962;
    uint256 constant IC63y =
        13419182106042872785703088113271068703277467030538587373299865501926404731131;

    uint256 constant IC64x =
        18601580383251132599893258247476391054543057269694162770795820699877242557904;
    uint256 constant IC64y =
        9804347507558794250232316635634473209909552400700434011495379366065366269482;

    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[64] calldata _pubSignals
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

                g1_mulAccC(
                    _pVk,
                    IC42x,
                    IC42y,
                    calldataload(add(pubSignals, 1312))
                )

                g1_mulAccC(
                    _pVk,
                    IC43x,
                    IC43y,
                    calldataload(add(pubSignals, 1344))
                )

                g1_mulAccC(
                    _pVk,
                    IC44x,
                    IC44y,
                    calldataload(add(pubSignals, 1376))
                )

                g1_mulAccC(
                    _pVk,
                    IC45x,
                    IC45y,
                    calldataload(add(pubSignals, 1408))
                )

                g1_mulAccC(
                    _pVk,
                    IC46x,
                    IC46y,
                    calldataload(add(pubSignals, 1440))
                )

                g1_mulAccC(
                    _pVk,
                    IC47x,
                    IC47y,
                    calldataload(add(pubSignals, 1472))
                )

                g1_mulAccC(
                    _pVk,
                    IC48x,
                    IC48y,
                    calldataload(add(pubSignals, 1504))
                )

                g1_mulAccC(
                    _pVk,
                    IC49x,
                    IC49y,
                    calldataload(add(pubSignals, 1536))
                )

                g1_mulAccC(
                    _pVk,
                    IC50x,
                    IC50y,
                    calldataload(add(pubSignals, 1568))
                )

                g1_mulAccC(
                    _pVk,
                    IC51x,
                    IC51y,
                    calldataload(add(pubSignals, 1600))
                )

                g1_mulAccC(
                    _pVk,
                    IC52x,
                    IC52y,
                    calldataload(add(pubSignals, 1632))
                )

                g1_mulAccC(
                    _pVk,
                    IC53x,
                    IC53y,
                    calldataload(add(pubSignals, 1664))
                )

                g1_mulAccC(
                    _pVk,
                    IC54x,
                    IC54y,
                    calldataload(add(pubSignals, 1696))
                )

                g1_mulAccC(
                    _pVk,
                    IC55x,
                    IC55y,
                    calldataload(add(pubSignals, 1728))
                )

                g1_mulAccC(
                    _pVk,
                    IC56x,
                    IC56y,
                    calldataload(add(pubSignals, 1760))
                )

                g1_mulAccC(
                    _pVk,
                    IC57x,
                    IC57y,
                    calldataload(add(pubSignals, 1792))
                )

                g1_mulAccC(
                    _pVk,
                    IC58x,
                    IC58y,
                    calldataload(add(pubSignals, 1824))
                )

                g1_mulAccC(
                    _pVk,
                    IC59x,
                    IC59y,
                    calldataload(add(pubSignals, 1856))
                )

                g1_mulAccC(
                    _pVk,
                    IC60x,
                    IC60y,
                    calldataload(add(pubSignals, 1888))
                )

                g1_mulAccC(
                    _pVk,
                    IC61x,
                    IC61y,
                    calldataload(add(pubSignals, 1920))
                )

                g1_mulAccC(
                    _pVk,
                    IC62x,
                    IC62y,
                    calldataload(add(pubSignals, 1952))
                )

                g1_mulAccC(
                    _pVk,
                    IC63x,
                    IC63y,
                    calldataload(add(pubSignals, 1984))
                )

                g1_mulAccC(
                    _pVk,
                    IC64x,
                    IC64y,
                    calldataload(add(pubSignals, 2016))
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

            checkField(calldataload(add(_pubSignals, 1344)))

            checkField(calldataload(add(_pubSignals, 1376)))

            checkField(calldataload(add(_pubSignals, 1408)))

            checkField(calldataload(add(_pubSignals, 1440)))

            checkField(calldataload(add(_pubSignals, 1472)))

            checkField(calldataload(add(_pubSignals, 1504)))

            checkField(calldataload(add(_pubSignals, 1536)))

            checkField(calldataload(add(_pubSignals, 1568)))

            checkField(calldataload(add(_pubSignals, 1600)))

            checkField(calldataload(add(_pubSignals, 1632)))

            checkField(calldataload(add(_pubSignals, 1664)))

            checkField(calldataload(add(_pubSignals, 1696)))

            checkField(calldataload(add(_pubSignals, 1728)))

            checkField(calldataload(add(_pubSignals, 1760)))

            checkField(calldataload(add(_pubSignals, 1792)))

            checkField(calldataload(add(_pubSignals, 1824)))

            checkField(calldataload(add(_pubSignals, 1856)))

            checkField(calldataload(add(_pubSignals, 1888)))

            checkField(calldataload(add(_pubSignals, 1920)))

            checkField(calldataload(add(_pubSignals, 1952)))

            checkField(calldataload(add(_pubSignals, 1984)))

            checkField(calldataload(add(_pubSignals, 2016)))

            checkField(calldataload(add(_pubSignals, 2048)))

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
            return(0, 0x20)
        }
    }
}
