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
    uint256 constant r    = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // Base field size
    uint256 constant q   = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    // Verification Key data
    uint256 constant alphax  = 20491192805390485299153009773594534940189261866228447918068658471970481763042;
    uint256 constant alphay  = 9383485363053290200918347156157836566562967994039712273449902621266178545958;
    uint256 constant betax1  = 4252822878758300859123897981450591353533073413197771768651442665752259397132;
    uint256 constant betax2  = 6375614351688725206403948262868962793625744043794305715222011528459656738731;
    uint256 constant betay1  = 21847035105528745403288232691147584728191162732299865338377159692350059136679;
    uint256 constant betay2  = 10505242626370262277552901082094356697409835680220590971873171140371331206856;
    uint256 constant gammax1 = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant gammax2 = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant gammay1 = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant gammay2 = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant deltax1 = 15294996281261769665267098053148985418125699690151755816524583816568815011637;
    uint256 constant deltax2 = 6314548079529465413888598899533046469009475618243303623717617547455968590244;
    uint256 constant deltay1 = 11497739953800497210025848368896131512650951990682745767174840266056052220103;
    uint256 constant deltay2 = 20657787522469670142930456712462185002119845065730132153422222251809473739394;

    
    uint256 constant IC0x = 5078466546719231312255336521243051842746834484889683811635708815865199344701;
    uint256 constant IC0y = 6586060071073332712107196327169726630221151211876017164177441620102036422249;
    
    uint256 constant IC1x = 18652839741777677530505123769446562590757859381490881099625268464437145735163;
    uint256 constant IC1y = 13741619038399508181505462719312381091771652264714789644759149698418631975575;
    
    uint256 constant IC2x = 12529730304599846539390334169908916252500744752415353458275246612767909856241;
    uint256 constant IC2y = 8730659757767842612105797828510963960765165262100835801753802761158308233909;
    
    uint256 constant IC3x = 9081509554381775494061506476349306260526615990246170592123724351356727454178;
    uint256 constant IC3y = 6955501981652826772773998493749348974285182922982437103253808420072499748159;
    
    uint256 constant IC4x = 17943433645493462503623413513557341177059325169345670886110899550389917040118;
    uint256 constant IC4y = 13323045870651450149442757532941295457530874992373004129305241481574198898175;
    
    uint256 constant IC5x = 5975737485475785065995522124964091476796016722732035058895010229362118894027;
    uint256 constant IC5y = 10933805282877144798771715762711345031501008694856159941014263262878397365007;
    
    uint256 constant IC6x = 7515711011739989043571268057463452066956710783585983026175500741616597422227;
    uint256 constant IC6y = 4520559164508709539478773007610868943626392611576192035940856142826882187299;
    
    uint256 constant IC7x = 12276557105524314291953590411336163877968478211845266579738616706812856373445;
    uint256 constant IC7y = 12630678666397483886716301037740568606354410164363320150090367210886946491127;
    
    uint256 constant IC8x = 4495357638279226422396657480219120997945343513050515453804121197122372593691;
    uint256 constant IC8y = 413878842897797769386134014458617815293722992040606187052796330760043174918;
    
    uint256 constant IC9x = 8630965391501036018579412320816213265765484808090456816781263001007211157902;
    uint256 constant IC9y = 10581474825354476800998882624060479576196942057816238895043624253271566912727;
    
    uint256 constant IC10x = 5146151521736772291982403676618714039827906872551737746728204219515582210428;
    uint256 constant IC10y = 3515475737948376409189567036470920931607475415346782916664018005445260677825;
    
    uint256 constant IC11x = 6628759548878187746368697201010122867819109298788332251921560789928726943162;
    uint256 constant IC11y = 21036585056979884030950271875338367465545458156517684577893869687634157736829;
    
    uint256 constant IC12x = 1182117690221602951218329702493448770050048154179863347579008756865503870057;
    uint256 constant IC12y = 19257970798738485944041364783666903487226109505082288627826261369727330820464;
    
    uint256 constant IC13x = 10143492571566923015436210191651839767385389403322743306242929755387180704368;
    uint256 constant IC13y = 9945172412344072925826961869318768176009449720634673082489282685785735672391;
    
    uint256 constant IC14x = 7146126746998161681365898203221121964877149977759731692018726687973776997465;
    uint256 constant IC14y = 9107672814262635921630620096972193850778454101260264061120192889222141756204;
    
    uint256 constant IC15x = 15535424307289514986409672750034779080047514234970390898609738834464534522771;
    uint256 constant IC15y = 18279535354529988630666356145778370156763213212587655351324758835051457174943;
    
    uint256 constant IC16x = 7753570333328281693643785529441757750031574298961253419413286659525726928608;
    uint256 constant IC16y = 3414435714856888581602444859079829142852461374201975640024703315139660847553;
    
    uint256 constant IC17x = 3455626648016669859158259453980893427266481249986397463888747821877812868417;
    uint256 constant IC17y = 3463087416316282080630155483144581032805482931952763443475057217165129049311;
    
    uint256 constant IC18x = 4566730424168175253176047638742005257543375760313363536700310839240218039888;
    uint256 constant IC18y = 15947087540007794520247164138187903141379396977937191446467102861322473657760;
    
    uint256 constant IC19x = 2331697364376661566794910267855942529048579543769284382321372827567633466454;
    uint256 constant IC19y = 7560186302897148005446375145439098475850659046923490142331940461023202939540;
    
    uint256 constant IC20x = 3857516762214538799212621618113675944783920895979247061345856539373964612058;
    uint256 constant IC20y = 10939575146414238226009556787317243195748360031033895453123466788275247936545;
    
    uint256 constant IC21x = 2322303320356535906329822139244968268628540623287730901380625547419518520735;
    uint256 constant IC21y = 15719545759478075709758947194122441125352804443223759969523486270413439026145;
    
    uint256 constant IC22x = 12420708110819252880396308554273381144573732903705863121030273147130265990089;
    uint256 constant IC22y = 5075425350459651448712895590681615415642238970399505753743383633319155391386;
    
    uint256 constant IC23x = 2472049331140784091552954827802532996499230752598112335456902761968420239356;
    uint256 constant IC23y = 710381135919914262753524161732964383580918188426916055972249200938062709104;
    
    uint256 constant IC24x = 20456516399015653496403145754879515217617590377309347612044822351450157441382;
    uint256 constant IC24y = 3565920224447205751766803171145407314836671289508075425151337983554813564719;
    
    uint256 constant IC25x = 20797229888740655753949606731893823125143160683313912383672446972329915148702;
    uint256 constant IC25y = 21735342721761329518809656503372781010307769937395768736974661836839234811561;
    
    uint256 constant IC26x = 5110784014520622789744748449030416123697895047815016289445832467698115397565;
    uint256 constant IC26y = 21662534963821765015479427014908787232635956066737732552776396002461315625093;
    
    uint256 constant IC27x = 905378216847572819399972902333251455764542110447566490448749578069152809348;
    uint256 constant IC27y = 4763659727508232768827674738277207063269985585613582430914721961320931253136;
    
    uint256 constant IC28x = 7276725596772270618602214971624189995483056609488300588434103014010500146001;
    uint256 constant IC28y = 3121745723863291283350728645508522592349045198800242846430647676538971464871;
    
    uint256 constant IC29x = 6790046744127795920951445407224000552401279258982717296406154558030234227445;
    uint256 constant IC29y = 19207973751417005421018747554217956187326281520271739103002538481592563133748;
    
    uint256 constant IC30x = 631482204784881273531667994027428166311914537612077529352430825451883678333;
    uint256 constant IC30y = 10817083744093784255993839954979974915198080425329870298433040789971423875963;
    
    uint256 constant IC31x = 12500897329804432794671204570058771388338436468737480176376311744215543763467;
    uint256 constant IC31y = 18712676558395617300251700982203500527240185260753107015139362254532183305792;
    
    uint256 constant IC32x = 18367481277643671566639353496618647248202642788944819736790795733560326082110;
    uint256 constant IC32y = 20581153215955269876416174122431994857204259458886827516851925944171457916053;
    
    uint256 constant IC33x = 19826989693073577659426849705117060474303355578226162286541170288208819111449;
    uint256 constant IC33y = 17263428455002779454149007590544664635275030825369109009180716076579860643661;
    
    uint256 constant IC34x = 9422069685367174125419635985788807060171463823813638211030897603174785110181;
    uint256 constant IC34y = 2423932608489348999004049456194353354497594799080925931469541827732151154666;
    
    uint256 constant IC35x = 6375359988383625608432989489285749938879877569107136244796061749818865287218;
    uint256 constant IC35y = 380977605497285947598273653657867196877829643949348236286223533764419161404;
    
    uint256 constant IC36x = 19190376721380180491484874440332613116710221843076352232068879707016223159307;
    uint256 constant IC36y = 1303300853355613542854875319575050188034776900256923158736117213558349605173;
    
    uint256 constant IC37x = 3701871021121763521032052306479139295932611832232042831149225366193334709855;
    uint256 constant IC37y = 11300711128782617189409521407825985516510461343235139280466867542157521163871;
    
    uint256 constant IC38x = 17931255708298718950625423568227630678388923907608930372300611157672795038939;
    uint256 constant IC38y = 5434056407105678031268646633788203075668294563373520562020861860263843178515;
    
    uint256 constant IC39x = 12648139124449267761888885767142913441194623209033368975253594260169169470205;
    uint256 constant IC39y = 1135122614807459566132409997825468162528975220305033785302164648675408923758;
    
    uint256 constant IC40x = 16209245752555043355512291181563945583039742939620835531262395187176043123884;
    uint256 constant IC40y = 3446909398191516737354949301811579956686053946134493864521738241234971724347;
    
    uint256 constant IC41x = 18576381452657134281465717841113764200514651964544831255681316817349846164552;
    uint256 constant IC41y = 9176941959592964511442277078800782648056824761366059748451847957449110505614;
    
    uint256 constant IC42x = 7914974861819455482349875525805830672456840721863454850033162767214582401463;
    uint256 constant IC42y = 8647428574665182288636064677094531126134207230223221816405350457820829465118;
    
    uint256 constant IC43x = 14329922127675337320509810862381217161867135499106211591854724316683471710213;
    uint256 constant IC43y = 17369085020160583824853533101071375599018179488839929222354536980398469418889;
    
    uint256 constant IC44x = 2319353125860138105777300278266369568714519934795163945702975531401968256997;
    uint256 constant IC44y = 2950848554370116647767113767654471769123313551875406681212746324262575408964;
    
    uint256 constant IC45x = 14462036672247737862259770328576845730938260179444558885386157429896278740482;
    uint256 constant IC45y = 20585246005305841725281185995507392158986577795958946321332763685055609902278;
    
    uint256 constant IC46x = 10368126173560127179283389413575520835308783471501068876930001187455347799724;
    uint256 constant IC46y = 13090937395120876070190223952453448344430515890578991696593313232532042138178;
    
    uint256 constant IC47x = 3487116631678773454416016746947408529339982016751618462498485062058877076124;
    uint256 constant IC47y = 16028740889243904496653995172047928721244811963543868318438589484472882279073;
    
    uint256 constant IC48x = 17382356024780167396612726609765568973823772197413985060576412006587240533895;
    uint256 constant IC48y = 17672807615354935664057177047693084957881189311410972185471803868791614054834;
    
    uint256 constant IC49x = 9458971915898257934928498530023462419034579861785042382342093770488463056568;
    uint256 constant IC49y = 19542092141692745850847320838852924216768093821343769504627248691163191311150;
    
    uint256 constant IC50x = 6149070459554244967611250296134680177402565666767967774318689989253904997100;
    uint256 constant IC50y = 11344754313517631054846547588577260711034514541809545271052133097551801720046;
    
    uint256 constant IC51x = 11644419883087365414862024991428805251045365697308017048473885393711542868682;
    uint256 constant IC51y = 7169060261330062488427981563689466647938754491369213756282732183085820329319;
    
    uint256 constant IC52x = 17700652920923028251300914203877138176861502008717806160739698109280189330426;
    uint256 constant IC52y = 21067659114312441390239089440830232259070721274771518570704598416929156100444;
    
    uint256 constant IC53x = 1065089394485475074899543193637111628939243546242766003121902145530367925846;
    uint256 constant IC53y = 17168237384318656372085601645971591567607383606129207169786956728233626948043;
    
    uint256 constant IC54x = 16804963235969961338634429554379667978013655284924258792884623908782535570102;
    uint256 constant IC54y = 20219328970839768092782131524507870146940498744767206159091952585006348097460;
    
    uint256 constant IC55x = 733490316018817631058412181791521593770133776225883945498955736583967726883;
    uint256 constant IC55y = 21861812299305717041725310204397669108695898221247806779873107406195996901823;
    
    uint256 constant IC56x = 5704811236999846042276650625942855422384153364201250244986665758033996286892;
    uint256 constant IC56y = 3964494765228530058680350362532845662529109798295738880135276015275473245732;
    
    uint256 constant IC57x = 18404616175323662417513074924259602336762364029237986297957542080059244181027;
    uint256 constant IC57y = 21429354558510638033126158167426492274493538627145702777662274366688147109038;
    
    uint256 constant IC58x = 8256020027475757499502494981275430730780556933161545294711114375869712957930;
    uint256 constant IC58y = 14965844542472308087443074500545095001929807830809108213170962526775278359496;
    
    uint256 constant IC59x = 20463808099072282305293006261273018036144603357520503978055171734351816334822;
    uint256 constant IC59y = 14420491622567722223822712367616593621671767615048288026402914397068686583678;
    
    uint256 constant IC60x = 6424430072652172579830445073448084632203319520994837426633310297449217174338;
    uint256 constant IC60y = 6902270880157283199406782330141146839941967515896966732547202667028063339450;
    
    uint256 constant IC61x = 19961272939675125691475736795282250178929095932480457939279332848914736092828;
    uint256 constant IC61y = 12957221436508855824530584723897458533379864942401117702384248668180854593939;
    
    uint256 constant IC62x = 14543558077427476459103336210246062419533116441733430605729703625144640747324;
    uint256 constant IC62y = 7406814707071151527217923008249680395786072258740884344354315539796509602383;
    
    uint256 constant IC63x = 660266721600579298534050158063636615521473745813589858659409050636037465502;
    uint256 constant IC63y = 5229608657490445227734043314179120337363665153635481705418736530097338848914;
    
    uint256 constant IC64x = 5505942743853666895607829611721584883619869934014697528288597970944676795767;
    uint256 constant IC64y = 17287591912582022527468488977932599759313893908619050274511873166497928240849;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[64] calldata _pubSignals) public view returns (bool) {
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
                
                g1_mulAccC(_pVk, IC20x, IC20y, calldataload(add(pubSignals, 608)))
                
                g1_mulAccC(_pVk, IC21x, IC21y, calldataload(add(pubSignals, 640)))
                
                g1_mulAccC(_pVk, IC22x, IC22y, calldataload(add(pubSignals, 672)))
                
                g1_mulAccC(_pVk, IC23x, IC23y, calldataload(add(pubSignals, 704)))
                
                g1_mulAccC(_pVk, IC24x, IC24y, calldataload(add(pubSignals, 736)))
                
                g1_mulAccC(_pVk, IC25x, IC25y, calldataload(add(pubSignals, 768)))
                
                g1_mulAccC(_pVk, IC26x, IC26y, calldataload(add(pubSignals, 800)))
                
                g1_mulAccC(_pVk, IC27x, IC27y, calldataload(add(pubSignals, 832)))
                
                g1_mulAccC(_pVk, IC28x, IC28y, calldataload(add(pubSignals, 864)))
                
                g1_mulAccC(_pVk, IC29x, IC29y, calldataload(add(pubSignals, 896)))
                
                g1_mulAccC(_pVk, IC30x, IC30y, calldataload(add(pubSignals, 928)))
                
                g1_mulAccC(_pVk, IC31x, IC31y, calldataload(add(pubSignals, 960)))
                
                g1_mulAccC(_pVk, IC32x, IC32y, calldataload(add(pubSignals, 992)))
                
                g1_mulAccC(_pVk, IC33x, IC33y, calldataload(add(pubSignals, 1024)))
                
                g1_mulAccC(_pVk, IC34x, IC34y, calldataload(add(pubSignals, 1056)))
                
                g1_mulAccC(_pVk, IC35x, IC35y, calldataload(add(pubSignals, 1088)))
                
                g1_mulAccC(_pVk, IC36x, IC36y, calldataload(add(pubSignals, 1120)))
                
                g1_mulAccC(_pVk, IC37x, IC37y, calldataload(add(pubSignals, 1152)))
                
                g1_mulAccC(_pVk, IC38x, IC38y, calldataload(add(pubSignals, 1184)))
                
                g1_mulAccC(_pVk, IC39x, IC39y, calldataload(add(pubSignals, 1216)))
                
                g1_mulAccC(_pVk, IC40x, IC40y, calldataload(add(pubSignals, 1248)))
                
                g1_mulAccC(_pVk, IC41x, IC41y, calldataload(add(pubSignals, 1280)))
                
                g1_mulAccC(_pVk, IC42x, IC42y, calldataload(add(pubSignals, 1312)))
                
                g1_mulAccC(_pVk, IC43x, IC43y, calldataload(add(pubSignals, 1344)))
                
                g1_mulAccC(_pVk, IC44x, IC44y, calldataload(add(pubSignals, 1376)))
                
                g1_mulAccC(_pVk, IC45x, IC45y, calldataload(add(pubSignals, 1408)))
                
                g1_mulAccC(_pVk, IC46x, IC46y, calldataload(add(pubSignals, 1440)))
                
                g1_mulAccC(_pVk, IC47x, IC47y, calldataload(add(pubSignals, 1472)))
                
                g1_mulAccC(_pVk, IC48x, IC48y, calldataload(add(pubSignals, 1504)))
                
                g1_mulAccC(_pVk, IC49x, IC49y, calldataload(add(pubSignals, 1536)))
                
                g1_mulAccC(_pVk, IC50x, IC50y, calldataload(add(pubSignals, 1568)))
                
                g1_mulAccC(_pVk, IC51x, IC51y, calldataload(add(pubSignals, 1600)))
                
                g1_mulAccC(_pVk, IC52x, IC52y, calldataload(add(pubSignals, 1632)))
                
                g1_mulAccC(_pVk, IC53x, IC53y, calldataload(add(pubSignals, 1664)))
                
                g1_mulAccC(_pVk, IC54x, IC54y, calldataload(add(pubSignals, 1696)))
                
                g1_mulAccC(_pVk, IC55x, IC55y, calldataload(add(pubSignals, 1728)))
                
                g1_mulAccC(_pVk, IC56x, IC56y, calldataload(add(pubSignals, 1760)))
                
                g1_mulAccC(_pVk, IC57x, IC57y, calldataload(add(pubSignals, 1792)))
                
                g1_mulAccC(_pVk, IC58x, IC58y, calldataload(add(pubSignals, 1824)))
                
                g1_mulAccC(_pVk, IC59x, IC59y, calldataload(add(pubSignals, 1856)))
                
                g1_mulAccC(_pVk, IC60x, IC60y, calldataload(add(pubSignals, 1888)))
                
                g1_mulAccC(_pVk, IC61x, IC61y, calldataload(add(pubSignals, 1920)))
                
                g1_mulAccC(_pVk, IC62x, IC62y, calldataload(add(pubSignals, 1952)))
                
                g1_mulAccC(_pVk, IC63x, IC63y, calldataload(add(pubSignals, 1984)))
                
                g1_mulAccC(_pVk, IC64x, IC64y, calldataload(add(pubSignals, 2016)))
                

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
