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
        16428432848801857252194528405604668803277877773566238944394625302971855135431;
    uint256 constant alphay =
        16846502678714586896801519656441059708016666274385668027902869494772365009666;
    uint256 constant betax1 =
        3182164110458002340215786955198810119980427837186618912744689678939861918171;
    uint256 constant betax2 =
        16348171800823588416173124589066524623406261996681292662100840445103873053252;
    uint256 constant betay1 =
        4920802715848186258981584729175884379674325733638798907835771393452862684714;
    uint256 constant betay2 =
        19687132236965066906216944365591810874384658708175106803089633851114028275753;
    uint256 constant gammax1 =
        11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant gammax2 =
        10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant gammay1 =
        4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant gammay2 =
        8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant deltax1 =
        20101309267135357709172304486124306645324068797822515400361450186755211341087;
    uint256 constant deltax2 =
        15889783402244857240196174061088389842336694629428782154880092698157490839140;
    uint256 constant deltay1 =
        11548284806856448438433391931225800721488063845701501046083250536711448737028;
    uint256 constant deltay2 =
        21407274447201100456114110563092240880926113507432952047580006404394133711762;

    uint256 constant IC0x =
        789607414321062181553919163461971751169052729220364066165535423515076861825;
    uint256 constant IC0y =
        11838767898744799830738207529500726385735219759217369055227752468548452175495;

    uint256 constant IC1x =
        8007294849817842439640740893607214001335265159613961643444034580722875462831;
    uint256 constant IC1y =
        3091368875735944960882180740796537919307348390352889611776279026314053389674;

    uint256 constant IC2x =
        12604588621143236825627919031606983803640400918841961008339831565821339438614;
    uint256 constant IC2y =
        5147608708495130666951221674826389921532883028641388462369033806665078370558;

    uint256 constant IC3x =
        16584696091952593367572709057685309194338782752100047938520598930899141507222;
    uint256 constant IC3y =
        19430175942270463907531075165681123722431063779057468989985099442392707756836;

    uint256 constant IC4x =
        7712981049939841845236872171113298661592044334761985240479860870978467727599;
    uint256 constant IC4y =
        8613236171894847628868428317660313835883198928201032747033946755350843393775;

    uint256 constant IC5x =
        16952014464841223991425689796652486253176706364084820363615074798015195235580;
    uint256 constant IC5y =
        14948884819274048028722760389186867778812267528932198477223191749515187621051;

    uint256 constant IC6x =
        15206830764482660012747093472577046232540047236213706391693872233650325268157;
    uint256 constant IC6y =
        16570288631209522600820952877527412439491507126341052868916248422000869792864;

    uint256 constant IC7x =
        10743255843134093111673017237711002062887330235431507019828251237402084595289;
    uint256 constant IC7y =
        9624207709672074802332969571707789958421048121869891000100282818699437655482;

    uint256 constant IC8x =
        12525847018572365666530412343377347410557211653685069246840038892014628011401;
    uint256 constant IC8y =
        1517705778892666136861684184489701117502021028283328651313278423940426841487;

    uint256 constant IC9x =
        5095239707119954006852739143073626787079108045359632860921491175637351568149;
    uint256 constant IC9y =
        20548316607601628685547585091593918145002599655046483890758196553322651278851;

    uint256 constant IC10x =
        11235789422833392735621559662695132147043801518450516015692248742407432393762;
    uint256 constant IC10y =
        14606063638316113961554925785824186238846264598480751918641035517865908754219;

    uint256 constant IC11x =
        14671367777879200094355862926355658857859083952103085699559603822132606682771;
    uint256 constant IC11y =
        15053680671150696059088129537084155977755529053700645458440758706555699993597;

    uint256 constant IC12x =
        1986532772912202251504106560105683005376436636844409523043050773969234240066;
    uint256 constant IC12y =
        12624673664284766613855622471389558929329915837614162545661687122547672535960;

    uint256 constant IC13x =
        4455366553551265646443083726908523813941360331162322943833246979325510698238;
    uint256 constant IC13y =
        20054314346645857703714914409576128754471784789642088049860397939296698154192;

    uint256 constant IC14x =
        446747258825003624131579538627933254480008720167542503852374389788355887213;
    uint256 constant IC14y =
        6519961294033828598067582249000749428100914878966853571848613284658754537401;

    uint256 constant IC15x =
        10079815446082785954769661330632199518250537502219112283646905042693560326262;
    uint256 constant IC15y =
        2742747795518698100423166036924653863691182578081828456239472339285345225276;

    uint256 constant IC16x =
        9631231327170462544346229224494861922043649503378846255185000795901261694984;
    uint256 constant IC16y =
        12455922523532528054514305603925545886132430251854466766639856300626166216707;

    uint256 constant IC17x =
        14508592889995360305386819771052282997049512566505662653587990960311064295952;
    uint256 constant IC17y =
        2604689250591609423700367856364448346484968172571681134773380518037428991227;

    uint256 constant IC18x =
        8152642126271018495692827436954941497421222201683769162931226341539928170347;
    uint256 constant IC18y =
        94903016734069347797904915427576846577798765221161044305721267217587122124;

    uint256 constant IC19x =
        11124194723095342231573009366396961493497104063863825255878108381378613114813;
    uint256 constant IC19y =
        4593370797092129071458573979696758983552380337286260706961369612562705812714;

    uint256 constant IC20x =
        4009630137674686416530955283088402951766643979729622628167403697676990151079;
    uint256 constant IC20y =
        6915687937732374824448300863490853716046758952097178864971410808310918472799;

    uint256 constant IC21x =
        6094922006474999551560282516963846477975500509277049260979956830605132664398;
    uint256 constant IC21y =
        5605441719398526014236375049005428285140334612353887438140973911621325989766;

    uint256 constant IC22x =
        15729678871028402802167576825124597014433431057293301754935173584462316212621;
    uint256 constant IC22y =
        15352917542890369444721990127418247062727245222217118319454859829423495486888;

    uint256 constant IC23x =
        11037961740587773523378190616986256497746105083187215758506253868753992501882;
    uint256 constant IC23y =
        524342527878065427571161437746320522189588138867282060452983761874081601312;

    uint256 constant IC24x =
        3862761899023389604851008209072873256820721629420945924755917306199054551207;
    uint256 constant IC24y =
        1209661617533129159072721709830722586673496313085325992943689730838112194096;

    uint256 constant IC25x =
        1159287086239674780208997333485051068647890343523672696737157057403380773209;
    uint256 constant IC25y =
        13916312100377144693248809380225534402833376802687107757172934265979926737922;

    uint256 constant IC26x =
        11682323387936667213732249183711706163044137126536137554983973122473014749662;
    uint256 constant IC26y =
        12403055833111397219666139590265062335376475574152944672686925780768419729929;

    uint256 constant IC27x =
        12903803478606258687376611791333505328098952359851621158422270687535348574791;
    uint256 constant IC27y =
        18880254921100453909080502808186315633948467956242166008483355206678769202148;

    uint256 constant IC28x =
        10583567797214525328021157774174863798633985304642113874222696840521055768710;
    uint256 constant IC28y =
        11084013126904313365227154535654163139592474725589243881781567891001068776305;

    uint256 constant IC29x =
        17104488773385268452829355557562833139973672085516089329414589862203340013194;
    uint256 constant IC29y =
        20527445509810280636584352257497875082828754126026339961885900138676869439605;

    uint256 constant IC30x =
        20578292592650440648627035466317412494041128750954168390997217385219595062351;
    uint256 constant IC30y =
        20529974932430685830153409577422491139949664074737215128268961157273288222479;

    uint256 constant IC31x =
        4748872732964987941940026963896522844278789201501727821695873723588905246627;
    uint256 constant IC31y =
        5327956758654777893400191047462912211690365542197408193880660762952326201494;

    uint256 constant IC32x =
        10141403347873686648574992324040582264889208935104968451077093375716674966605;
    uint256 constant IC32y =
        11149527490946837961727922877998837106891441093407093815873509540356478127775;

    uint256 constant IC33x =
        10084191029988908766908467226501909020084924207699436618692260912524237322407;
    uint256 constant IC33y =
        3629573848193779099201792838523631289394125653486948341255581295500181450671;

    uint256 constant IC34x =
        20806056949011425147621031765152272391671378564784233112194583334083499837934;
    uint256 constant IC34y =
        439560263617125434029811849224529519315145607527424297695489404782051129146;

    uint256 constant IC35x =
        13388419957552367155173731837687663515329195273841669005223414091848093856319;
    uint256 constant IC35y =
        8534842149206845667547636163860132461778079740973298108434238132684919233816;

    uint256 constant IC36x =
        10700322940208720740276813435575418737574088396971840490197160125900091497528;
    uint256 constant IC36y =
        17775947230895238529783383663192664630331223396498540268379111286818830409316;

    uint256 constant IC37x =
        7554572228964165227440659997423871859062001724139995342089305539568218439874;
    uint256 constant IC37y =
        16049547191716392095001441547660665745512443985460757916643842627547465835719;

    uint256 constant IC38x =
        19914287942281695749936569519680947865552661835932918106765123711520734590827;
    uint256 constant IC38y =
        19517463858016657938127207579152364430458563454162115220063337850261551958813;

    uint256 constant IC39x =
        17095575563471482407005097700822161718312340402829073025738118794544930435229;
    uint256 constant IC39y =
        5706392064069219128060573573670894173668828081334692610848151008766000971916;

    uint256 constant IC40x =
        3651185820356712243812075574224546702453898923673816876653338911323682924248;
    uint256 constant IC40y =
        20923203752664528366173598371905371818620647421187505199186652191761513472382;

    uint256 constant IC41x =
        1410509430695349743197337884662844885691100760897805959573499926946624535881;
    uint256 constant IC41y =
        2452125089830848131120321759815152902953988470973212843281328680087593053389;

    uint256 constant IC42x =
        11554005071165120375590592843257767661573329992909309062585303782390335549050;
    uint256 constant IC42y =
        16058939515744804558361918930440033770440893458298333641782414647734825016858;

    uint256 constant IC43x =
        5362100208627328838086518628101381727505409791363609929783129102254602840027;
    uint256 constant IC43y =
        16342826776891561149503577877014202336989449988315113429791447302897745992192;

    uint256 constant IC44x =
        13426597084065046078050867115174119667399719429768206117211961740636327273987;
    uint256 constant IC44y =
        21627368292478498223700315000183744582331164787687955826750786217919175759938;

    uint256 constant IC45x =
        5397574511412417874411825390273678315342030914112841019673388649090387860878;
    uint256 constant IC45y =
        4526546147410360916653586419361540049927528868425754774797068197874057571597;

    uint256 constant IC46x =
        21343483119776978675641146013279448132460262073312054952006915161160460860430;
    uint256 constant IC46y =
        12483389484597722480627610672725037121535411878916566721278351744052862040794;

    uint256 constant IC47x =
        19276688346308439105125764363367716185983430166022956424163401357085724625858;
    uint256 constant IC47y =
        2970212227284658304731383068952662546909666753681156132218834923911832828745;

    uint256 constant IC48x =
        11506868425840931242667698479140704391158650698399570736911790067747824947603;
    uint256 constant IC48y =
        16375979230310101343397271828480961431120663977738039209091311746899147252612;

    uint256 constant IC49x =
        4693180002021924625869645764793502033666751848625768817780151106061024601728;
    uint256 constant IC49y =
        6007190399828400799434303827921505362153742384638044068466731244798104288650;

    uint256 constant IC50x =
        3839626133675294808442960850749727346205256359681783274738828506055008994341;
    uint256 constant IC50y =
        1387037941626725808240542329275879831818891446961910778379237615835723950929;

    uint256 constant IC51x =
        12388079331882967162364330789077199871910606645865407031228787095222577328480;
    uint256 constant IC51y =
        6035609285400274245916742924657162204663014372805167145634549640619814601971;

    uint256 constant IC52x =
        15977704805714544169418713677371584194774856053313426036079214462816436503830;
    uint256 constant IC52y =
        921275815079602760266836046916020183703470711852216739086338552560852986738;

    uint256 constant IC53x =
        13735941494374288175976718633725939056731527972192668406997821463551218510067;
    uint256 constant IC53y =
        20838745285521549788761812030886185663468822201036653735046395463029066796856;

    uint256 constant IC54x =
        2502045067420093117614346302318837512163482141575193566967422233261877935416;
    uint256 constant IC54y =
        13165560341924762906821511689166561783576366885612076747865964393012347488214;

    uint256 constant IC55x =
        12448800002167497631266806544615984579594730493685934229662832626689460627880;
    uint256 constant IC55y =
        2338976099074076230817509847177548963497183619500899434289599027116185262070;

    uint256 constant IC56x =
        2024879359759247500926829740269514686579207157323393188213586160608721224601;
    uint256 constant IC56y =
        9167242215199691302909130775648663853643641530201187414618309048859987435627;

    uint256 constant IC57x =
        20843108563371387298519266313227015571293733886600891889494924111918718418164;
    uint256 constant IC57y =
        13278545524387219742259232495615695175906322496125195129047115657989915208830;

    uint256 constant IC58x =
        4815324823774154970020873643252191653182838792973815917308311455572348878417;
    uint256 constant IC58y =
        374736633614759070996935059646884704951528735102970870103116868425967613231;

    uint256 constant IC59x =
        4179767352163876183619808915442713862705834167233698531966909218641811289326;
    uint256 constant IC59y =
        2456521675225558024140593022965945130690419316404796816671573663785294968059;

    uint256 constant IC60x =
        17886824706193905660374198179353999920420148267830602075348293532331982973313;
    uint256 constant IC60y =
        12545302970767297674798141134430093206666886991054413982864408523742660828996;

    uint256 constant IC61x =
        14002174568509871904754377236566659872392811426743732420046316055710645530495;
    uint256 constant IC61y =
        10945762031752078444289094331173723731419785829294499077899468244134047901947;

    uint256 constant IC62x =
        10924030615044746875128966272905699221940042580234010938045442032798962018139;
    uint256 constant IC62y =
        3797867307882564944113054666086995625057067168486220209090436403569860155090;

    uint256 constant IC63x =
        18931105925337939679653879056379316843802246658503219943888741965978782053300;
    uint256 constant IC63y =
        18767728540038039065954730448125775462278032421825668930619240872801155666365;

    uint256 constant IC64x =
        14496714388028362162713988652631448581021409843607063911035519285523670902773;
    uint256 constant IC64y =
        13216374784970681603707851673079702680959714205525233173519078748546215130697;

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

                success := staticcall(sub(gas(), 2000), 7, mIn, 96, mIn, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }

                mstore(add(mIn, 64), mload(pR))
                mstore(add(mIn, 96), mload(add(pR, 32)))

                success := staticcall(sub(gas(), 2000), 6, mIn, 128, pR, 64)

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
                    sub(gas(), 2000),
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
