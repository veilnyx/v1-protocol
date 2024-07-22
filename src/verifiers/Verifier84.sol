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

contract Verifier84 {
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
        13637298372337635613858300465692749724980074451560238457840501040904341835071;
    uint256 constant deltax2 =
        12200196770450575808510665470535347405492703039438303179432546220566928489503;
    uint256 constant deltay1 =
        17302427624904324307112955291718205811012276334168863235417293204840658863913;
    uint256 constant deltay2 =
        15736347944390694163532064516551956125741979564184699492085633912902782461731;

    uint256 constant IC0x =
        10785330120583484009930564428472380941582930668996173495865431453655132739370;
    uint256 constant IC0y =
        5391056634731193294145269759331152444269833966442606082944701033461479153565;

    uint256 constant IC1x =
        20072949408624479327299104838738009177374111163900055952743056326082910844824;
    uint256 constant IC1y =
        4164836708349779872775807756327229571662856417919283939339231061835799091984;

    uint256 constant IC2x =
        1176488233349083303987229776251898704359636336774283841990338909896960596182;
    uint256 constant IC2y =
        15629263414660553524878765825134378212774595906774978623969467787031468855543;

    uint256 constant IC3x =
        10140354350263924472945641707523936478029536704673098873569951820715781748384;
    uint256 constant IC3y =
        7033016285579268341864274135464505474869533644620732371683037874093913219719;

    uint256 constant IC4x =
        12667579835644008376033469970656236905624289753093549555738321516398363658586;
    uint256 constant IC4y =
        8318564744166175470245673350253943479450112975071221347171912131629046649548;

    uint256 constant IC5x =
        1529001548587026289998955453325012845073561853100402325931674187323909652814;
    uint256 constant IC5y =
        6007197960168560823990769871607180195330946240673234742420107300125812957781;

    uint256 constant IC6x =
        14566140063498533951095280524622547610429786088024977379767509160763267689093;
    uint256 constant IC6y =
        8481863623664663544250670869659324191630004255204425099919404209806113617139;

    uint256 constant IC7x =
        10078804182741741192882822139380577136191424338064184096549237770434189836113;
    uint256 constant IC7y =
        14793767434973046452517514264673421906752324906505800165615984144613886369349;

    uint256 constant IC8x =
        8289504856137074649484245119175400972990071584707146525249520278477674823107;
    uint256 constant IC8y =
        6602453225268750515067812245130122695591676998324993975313667920028864858065;

    uint256 constant IC9x =
        12511721172331169944533024514756726297784843546132114157594704843421072925057;
    uint256 constant IC9y =
        11621883693486241646610474501131050114674817866383429226232278641452058121952;

    uint256 constant IC10x =
        21732451165938903533009167248033993457181446602435882660908938446144385716479;
    uint256 constant IC10y =
        12498416241330378792229602037435378219949012370755857302820398222843963398573;

    uint256 constant IC11x =
        13555052610487852918101546116898811779369929484286641697721721136509419076395;
    uint256 constant IC11y =
        6818105820855150574598505570216087857110669721291481869454823826677632667955;

    uint256 constant IC12x =
        3311834190372097035334513789521294518263041070880542255233567379436540906699;
    uint256 constant IC12y =
        16149615105443183011497375106923875715204549141697357194509155454736949271186;

    uint256 constant IC13x =
        4481945398758199627606369279359235877982288896346709975382068709046276615832;
    uint256 constant IC13y =
        5502349211712734935816101029656120365190753681317699641624045528639080549458;

    uint256 constant IC14x =
        20661140409313822998618122131726759094679957206087659111355257436705660093846;
    uint256 constant IC14y =
        3398907373636041802203804897015603561434259366281819884276669893507818360758;

    uint256 constant IC15x =
        18465419801711119431492189355717021381053729778110608019196239611486040623559;
    uint256 constant IC15y =
        21663099263487597139057750635059002658265232981714548656396482271952799229544;

    uint256 constant IC16x =
        11513463802668145882954352859054029014487068041620074516890243353359990966661;
    uint256 constant IC16y =
        2871089988128052431588696324203721021291845520866620872187729070169720349783;

    uint256 constant IC17x =
        16770974475237532875007620457436956715573474914794197816380213081475139065837;
    uint256 constant IC17y =
        12791761618237049947734514503193163427234488113105403773079875568786905455216;

    uint256 constant IC18x =
        10845323279986720468212077761751601723214770517663721360213699148073553405584;
    uint256 constant IC18y =
        12635713067224291497012487617924845476968233912443055138694650518527162550257;

    uint256 constant IC19x =
        9728654465930959331051521438649154210010671187490176206206182278273668446671;
    uint256 constant IC19y =
        3146045442034439529807833297013378644985731844931196757791940456868142568420;

    uint256 constant IC20x =
        4600886020774906157073560492621690767128434687351334005886222789065591975821;
    uint256 constant IC20y =
        14241822418035282245993692117643685947338570080324237687369870390724893148588;

    uint256 constant IC21x =
        13757143535439014775610604303103441368238034063749743524980985763569688966590;
    uint256 constant IC21y =
        3967637216659055934573630040638638858171241979903398328793644360296216659222;

    uint256 constant IC22x =
        4835010527724746008693776231750665169274278978777630681378595711165892655783;
    uint256 constant IC22y =
        15942239623933525881940020491643011794742281006663706319205053455940166622572;

    uint256 constant IC23x =
        5525327067427129266720839559329936390761847687068323287048274961326672647289;
    uint256 constant IC23y =
        9134439919819048876771924682010993590339898817002474021870750636084509949348;

    uint256 constant IC24x =
        7609021536842236513500602611645313985458071931840845155371133049197224451788;
    uint256 constant IC24y =
        3768446907687701881003365975483477696159933651486797405122744510355077644703;

    uint256 constant IC25x =
        9870788876235934264827127052114460662296795268081745644205882638503734676734;
    uint256 constant IC25y =
        1943748880047318458475478734744390524431163339709476543191510587414154468102;

    uint256 constant IC26x =
        19728453498938795871840281341349614173201263491529264442426112594238311073341;
    uint256 constant IC26y =
        10221960315425517487316373847427293528319555515277407289583322318574916995379;

    uint256 constant IC27x =
        2555138759962243052370363085513266497111636973956142328380617909144007616702;
    uint256 constant IC27y =
        12902050797397679692460660699091615123279714008053896133355720976958342639565;

    uint256 constant IC28x =
        6584956764404371258098074807730125453948497221475159469750332169075477391073;
    uint256 constant IC28y =
        18354145246176950717070001959108441321544597378858911309758222347852303497001;

    uint256 constant IC29x =
        13540975106954305127051305523766165629193858780279506729004815745350867076655;
    uint256 constant IC29y =
        14059337389176900207386275904186628298454939623003661142743638439698337419662;

    uint256 constant IC30x =
        10549428968641977405920126527364833655153596896677946971466067202399165940750;
    uint256 constant IC30y =
        15785476032573727672239054409768662836287345024246501828786040472326156758129;

    uint256 constant IC31x =
        18527889185248700972377238837602004992117417312881552691460655820285740005165;
    uint256 constant IC31y =
        18192042817715082468854566002324731800348663047640488744374691251527866491547;

    uint256 constant IC32x =
        7341153356145710176049105661166135571079943925522169397129808739246331379256;
    uint256 constant IC32y =
        13158183571730701278999240529409816773541185127001465166734977395398914938349;

    uint256 constant IC33x =
        18327614473550115826773294436972516278053056214223267449299880684963055688841;
    uint256 constant IC33y =
        21155927758623820065538671159386832358720915402783457476872001834564295632105;

    uint256 constant IC34x =
        13763355714824327055730884009877270920757122477779839257909031372840573438862;
    uint256 constant IC34y =
        11836367767700789622480298813966481198844293265800806118823389585565794825294;

    uint256 constant IC35x =
        17543842739806167607820530019240646614990227285642883023688013726039198827450;
    uint256 constant IC35y =
        19494908821498373390986032367219209631384137151977077118690516888231944483060;

    uint256 constant IC36x =
        312326863671663181880782368345291935235844776742814583120589929860521231098;
    uint256 constant IC36y =
        19092422849821760115481740368320334982435137042608697751814632098217528037650;

    uint256 constant IC37x =
        12210192032875719247392183754991227891983812558107599196838341196820323735893;
    uint256 constant IC37y =
        3368996657465956947257964263016512863924704392724069102236282021919072079725;

    uint256 constant IC38x =
        12589208213331870865184580016561038716308733464020089383196333012215100564327;
    uint256 constant IC38y =
        13235002700728087714936663971232919918578518502813215947354801041029963088982;

    uint256 constant IC39x =
        1368480617943062142801791454965264008075910542228434426531021515716959409580;
    uint256 constant IC39y =
        4967397855051561955963412153643303407718178868827507518337925841457340508045;

    uint256 constant IC40x =
        13415387900150621355487867894511703122611142901941026407137910122328415451248;
    uint256 constant IC40y =
        287312463097379580064539602370793796950253995649416461599723809576151670141;

    uint256 constant IC41x =
        14552982498754907133296582690954002794708700639144712022166130033329626105662;
    uint256 constant IC41y =
        2596624430643529036965371350489349395523239039588942885393502008036562508615;

    uint256 constant IC42x =
        4907358373135897876915795179301873072740029829152840363022787752580391413194;
    uint256 constant IC42y =
        3938861082277047792976933182139599494995865517454502407799697054471924810915;

    uint256 constant IC43x =
        11354396751268629386482591323738031830990561931678932355278743437957919681508;
    uint256 constant IC43y =
        14597749099203357426206684867197561908628839818340495587762411270673733022863;

    uint256 constant IC44x =
        18089734041276208063287672419825320695890072317026308518804772334111967902658;
    uint256 constant IC44y =
        4354288062846303108935922422010513514055222425836409615623211590842170995227;

    uint256 constant IC45x =
        1632189006329421370463409614996299304546415551693246434417539971381411224402;
    uint256 constant IC45y =
        19509785207582098255321772142889063311638651508595037423097850901853138583026;

    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[45] calldata _pubSignals
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

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
            return(0, 0x20)
        }
    }
}
