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
        6577290911681799658805626377273685439675288726199861787908099488992733610039;
    uint256 constant deltax2 =
        11505692996823459492365003130134431337656428778371395498909352184824990308718;
    uint256 constant deltay1 =
        6856537446733006273183149454992802460456842489439069790236495383405197617515;
    uint256 constant deltay2 =
        1028163294008058309818577417158911086268823474416565251635608413614719118777;

    uint256 constant IC0x =
        13477760142942039613051514141932140013028761082923093055686546169374667578935;
    uint256 constant IC0y =
        14864533502559586853839588211659093543349187167429561773134382648427079080921;

    uint256 constant IC1x =
        17730495355249551962277447844239921535327602796598289638265539883786863467167;
    uint256 constant IC1y =
        20539679167929308095980192572043441919657414093579090422634257236651019093176;

    uint256 constant IC2x =
        4732148252626388018209479673084405715774725446087464732985852904598557151016;
    uint256 constant IC2y =
        17202197943398105128599286315413978093907297433265869445520589227947010439603;

    uint256 constant IC3x =
        644396390685275120739712562053845075679719262305014420473759377349510946873;
    uint256 constant IC3y =
        5495866783556728983529567565277890524955444212426682827941461487937901313553;

    uint256 constant IC4x =
        12337142947651019304658515736040842802653864921565403491690156471623304765916;
    uint256 constant IC4y =
        4774689193985681548215524560635403996588170965964003876502242260761034644272;

    uint256 constant IC5x =
        1800178797252926429261800279481878282209613105668318407531436812352463073626;
    uint256 constant IC5y =
        5942359680319805300718288527460039551928617097328457552363835139319871147906;

    uint256 constant IC6x =
        16198669984542585372705519943968309100144164108787950360717110119571709975372;
    uint256 constant IC6y =
        5008320040899281517322773822886659060450610621704909427663874659576459853460;

    uint256 constant IC7x =
        1303350249845368513044264989714027252357823435332334062579153308333366849373;
    uint256 constant IC7y =
        9201790241634298343547887974601193034024941450999703015919073404873398661041;

    uint256 constant IC8x =
        10043931197635219960830279192117897306627402455980573949271995344475037499936;
    uint256 constant IC8y =
        16419349998396544247594614140526663889504396288622263936747066961486131139577;

    uint256 constant IC9x =
        16165164394932102791491459057044203535822183067969006803312141196347448372997;
    uint256 constant IC9y =
        11099164013707941709062188511021835669851871046683709625347264551492847023784;

    uint256 constant IC10x =
        5744298967421554400887090962301081595639534328619686032439104049207827811925;
    uint256 constant IC10y =
        12947137724003929675977912657184801584847704995567395260753823296259293472327;

    uint256 constant IC11x =
        6728282435093931594040958023456126266988280922559240253173861742774965005571;
    uint256 constant IC11y =
        7177430183034064049019368245285055824802400525130112431899469708477806346179;

    uint256 constant IC12x =
        18232904780524197792413941019973734786973508270264284293508033739141494430063;
    uint256 constant IC12y =
        5207496632597639982090932446370382775194286024552044127367679812124170407716;

    uint256 constant IC13x =
        14926249892698366158884696029778412624629089126684374855121378625908271091791;
    uint256 constant IC13y =
        11306700882333515525307333516933839173171177731866537418402246461031439065895;

    uint256 constant IC14x =
        19008372237592571255038333325832508970663774875543331839546985698731212792656;
    uint256 constant IC14y =
        21567456320193399935943961279769811333588976006669642072153497599234720385240;

    uint256 constant IC15x =
        18334311805032760843436660279756107275749917355576971300969080978514190437010;
    uint256 constant IC15y =
        9710567291111957842315965173190685099016309200704147995501759531954491154238;

    uint256 constant IC16x =
        19773216089340821102457337404282168817093119950450405547583752986815060218493;
    uint256 constant IC16y =
        10568636359215235166992333216397567680244501686862288476986675782664963859457;

    uint256 constant IC17x =
        14356613290357402787207087076134273218348454214539104440440298371724050235519;
    uint256 constant IC17y =
        1003939770995080552578459468496001173518439032386660002021148996552447467185;

    uint256 constant IC18x =
        10599978497483514619197515715041763999868561308087052511536290411314355309094;
    uint256 constant IC18y =
        19835723301652461837930380144472154134927079662433126349271658617011402760439;

    uint256 constant IC19x =
        13268255102937581398703700549028894932323895236542149853936170681576754461188;
    uint256 constant IC19y =
        3438505895318017793339599861115575112624317285122447353122779461880711829590;

    uint256 constant IC20x =
        3015478596933075692805129725834322747220060697081840098183743058421429058545;
    uint256 constant IC20y =
        12148673560600614462101568937982395168600478047441741886471304350176606886325;

    uint256 constant IC21x =
        21817185666654567707546619306316558276043808792556063742482754305964009721260;
    uint256 constant IC21y =
        5033818460387649978221280514954269982175318245925751741691141667506659761817;

    uint256 constant IC22x =
        21264566886115500057230028545568534319311744975701941030327264956467929910183;
    uint256 constant IC22y =
        390158197057865970708929447752806268410870336432546934782217254198979869082;

    uint256 constant IC23x =
        6388935858464091458691103230213748623905579195981729720386953600576001234001;
    uint256 constant IC23y =
        11513365104997652288614743358796937068693433365673594114125417605463302159075;

    uint256 constant IC24x =
        2182632214076801879730193193429697460995272934246323152336195211569338743400;
    uint256 constant IC24y =
        21333192231348001662156348171864339583898494193131985030897025953679598473837;

    uint256 constant IC25x =
        16372625031400909064388121244583253376331918753247188234150502188931997859711;
    uint256 constant IC25y =
        3593711406574642047393348074729871845513623121511897684192170035730289684092;

    uint256 constant IC26x =
        14284210897218020060268577456047861927810665056879202184409717703988730517684;
    uint256 constant IC26y =
        9306402700942000213612434220651990200022785956861457834650587137130434826282;

    uint256 constant IC27x =
        12440362005751663749250644207338116751348870028218246134418747635039465040244;
    uint256 constant IC27y =
        15403990217677741505968208101365113061702754646792137106496284612951695666375;

    uint256 constant IC28x =
        9107148041911269949192417249270985867042967361529554503559959960666773334621;
    uint256 constant IC28y =
        18467277579957770809391887587347834715132558485124723078757161438894637459875;

    uint256 constant IC29x =
        11462699280023301245514021989380770976643202379189945920830092460452278559939;
    uint256 constant IC29y =
        20734702977274638137070296068984960843466026548992208234017606917785140725795;

    uint256 constant IC30x =
        3080873828326355509048543644581468111156499788286708724505355614404051408265;
    uint256 constant IC30y =
        12316227210981155978305404754182907963522304509469121049529268259766315405799;

    uint256 constant IC31x =
        21246669101032761135257832835213835796264473159099066311198548055234583153766;
    uint256 constant IC31y =
        15092991776647775996736175111165682040615083463415591730722600124777380450995;

    uint256 constant IC32x =
        19985001022500326372365547319066375651745924318203133391832461566362017200751;
    uint256 constant IC32y =
        14745935531907900330217267176130879999925420691473057445379160071091536321515;

    uint256 constant IC33x =
        8674132766555040625872290529057348581710420148186644473980773315318991436134;
    uint256 constant IC33y =
        13722962433812624147442263456089322111392340466525617202361005276611759605313;

    uint256 constant IC34x =
        4023959394045498016171470814218046453377785394743639085136385414635573493552;
    uint256 constant IC34y =
        8530546704817068104148346090667807379889690249265331926199574238087748005203;

    uint256 constant IC35x =
        10034542513659213140685174824146639456174678178256046759910220653828152419101;
    uint256 constant IC35y =
        9075748768950590855031438092389825548713440658478118862437451710153126317094;

    uint256 constant IC36x =
        15643654685658921326907232422352354783131429291032202951214708683724409818029;
    uint256 constant IC36y =
        17995381488827435772932941439894333041977547904593825101895012699701039205818;

    uint256 constant IC37x =
        18876084075959285508882797240666816468165967827462595801512347330738443470191;
    uint256 constant IC37y =
        4689757159153311194333212542555081266295480798005522169395170157343798700963;

    uint256 constant IC38x =
        4862902259701270574651876961817605823201163297748047086077450088394244450000;
    uint256 constant IC38y =
        5230709418214538754202740348462458537311788237472675526840525673326947060360;

    uint256 constant IC39x =
        16391715131078689584586426677493832020841520146785591488408354940715371825711;
    uint256 constant IC39y =
        7816088322782790150252400853876250733558708714521799254042510019084257584119;

    uint256 constant IC40x =
        19799323653968333327005937714499244571154082153239459720377184979165683263091;
    uint256 constant IC40y =
        19271380907861794011299246436396825176672468421342214752600732488168992407810;

    uint256 constant IC41x =
        11335565012378421456973456710334099463659870825942579093949931953772767193119;
    uint256 constant IC41y =
        17183678418693344604667147470179858044028910744395573590416695204774429504311;

    uint256 constant IC42x =
        5616803790002557097458532411187337151812071021509703795993302217702189725833;
    uint256 constant IC42y =
        9462677829498346511249042505639556109260457449569116506117145227540879565134;

    uint256 constant IC43x =
        5931608170452487894736885943350269315729527775679006081290646172487685023671;
    uint256 constant IC43y =
        10192945591335017291246425042888047147077941127228576723910570489964222078899;

    uint256 constant IC44x =
        12668945493397243662474959791892910724308154988662265471875693392859453034870;
    uint256 constant IC44y =
        1124948191020663162001515743956158722866939417940144368792285336682460249236;

    uint256 constant IC45x =
        11745449868763710115541216992085666329981920004325653502139308739888085151304;
    uint256 constant IC45y =
        14958436215469069304355655657535307095734873265174672897619884842490839905726;

    uint256 constant IC46x =
        10639277631011393585089922743835615052518483431089931933469244186226475885725;
    uint256 constant IC46y =
        18791761371680506536712218589269077351035431144724725887229401007964838240189;

    uint256 constant IC47x =
        5086886840001192751399498889481821332676890223053859807967099726955248695360;
    uint256 constant IC47y =
        19591019428349048177464761294282519835265451064011025681773068333953957651009;

    uint256 constant IC48x =
        5704165856568116668153062521815575897647869119184969094814202459352182323535;
    uint256 constant IC48y =
        8419159904864863253567275993507485790155789179770977765688582748197804028152;

    uint256 constant IC49x =
        1777287433393525891310116205726965306575850479532660484718972880491243749685;
    uint256 constant IC49y =
        15471573602527045621078258105838071128827761647346438564891957091510101898007;

    uint256 constant IC50x =
        21721328339543120517795282855314738840682183037948595792184688486304362144921;
    uint256 constant IC50y =
        2543543471518313028042960063767210139949992168451845578530090424552489644668;

    uint256 constant IC51x =
        17112299552767619269922590580329222477589475936474822260672039392581576674502;
    uint256 constant IC51y =
        15342706753723782110452982268593556626936477951646706431497804353686916897882;

    uint256 constant IC52x =
        16695981845446303518395996281829115715236785393786765514148505516732569344420;
    uint256 constant IC52y =
        18098304640842238211159944551218016858673102613788727413072346946930203337003;

    uint256 constant IC53x =
        18331258421073283380126139099630899206148880732389252510666173729677327792358;
    uint256 constant IC53y =
        21747596786318316131749705255219546100722776751657395373276042927421424710934;

    uint256 constant IC54x =
        11834799950117908100135690165890816487956240664723320122964933520183023375537;
    uint256 constant IC54y =
        4703755729695865544966892149399889017352975084373971667895384612479148153050;

    uint256 constant IC55x =
        254714002739513775963933466940591614508791580128325040464004249229487365548;
    uint256 constant IC55y =
        5748983735646721080379949667897949095897323426468328975657415633431393901662;

    uint256 constant IC56x =
        5053229617405801233493266868060838776384486115135669005868638140962691103197;
    uint256 constant IC56y =
        1351487835923446686986053014530233176563106362998071620843416081345430835130;

    uint256 constant IC57x =
        19978146343566545157391312593846079402403680607467044964086780660084775269586;
    uint256 constant IC57y =
        7895093310178933155758830123845121673384920503789491071737243717502394811264;

    uint256 constant IC58x =
        3057888937178034903782540440409531113035566082315972038112517880761881190722;
    uint256 constant IC58y =
        13351515691375405348626415031238036141671457131861636516186150042545130169084;

    uint256 constant IC59x =
        2447409131173799017300496480408702969656100146427663897675854214927096052549;
    uint256 constant IC59y =
        16181173415266185180193991364092446999635051616353107187727182688788769014548;

    uint256 constant IC60x =
        19312878943622634924750776985710389038647212427527189968146594422213164145456;
    uint256 constant IC60y =
        18077145365717739996276334969453253918288511094017904028580211155059854154517;

    uint256 constant IC61x =
        6347390844978763732522284117879143353263606560985616785986536651076978243420;
    uint256 constant IC61y =
        9619270103341357379801007336876814882528090704348161408256845476168301426706;

    uint256 constant IC62x =
        11181264856925935622127786983415216945031529691016052637878162436660426583352;
    uint256 constant IC62y =
        12743905459712113151508466371348694103219103189883779847436511836692412261607;

    uint256 constant IC63x =
        17656477434924794373488332640920528837415863325477854530059743450082165772812;
    uint256 constant IC63y =
        13165737892483468069304512044635968149538309082841429743670432238996289694445;

    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[63] calldata _pubSignals
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

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
            return(0, 0x20)
        }
    }
}
