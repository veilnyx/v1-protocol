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
    uint256 constant alphax  = 16428432848801857252194528405604668803277877773566238944394625302971855135431;
    uint256 constant alphay  = 16846502678714586896801519656441059708016666274385668027902869494772365009666;
    uint256 constant betax1  = 3182164110458002340215786955198810119980427837186618912744689678939861918171;
    uint256 constant betax2  = 16348171800823588416173124589066524623406261996681292662100840445103873053252;
    uint256 constant betay1  = 4920802715848186258981584729175884379674325733638798907835771393452862684714;
    uint256 constant betay2  = 19687132236965066906216944365591810874384658708175106803089633851114028275753;
    uint256 constant gammax1 = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant gammax2 = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant gammay1 = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant gammay2 = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant deltax1 = 16124584544797200438588944877872612875431664058448439026340877417568467567666;
    uint256 constant deltax2 = 9573666701082378303384398619576931635782776565743021389358219470263383990559;
    uint256 constant deltay1 = 13521682207338237978425833790744944284498817560886217593629748375991353906831;
    uint256 constant deltay2 = 9840109952366944246778864876508059397627091186611070838735179052264459946933;

    
    uint256 constant IC0x = 3638681219383386509560958146358005250188794223489688643542243296274941507507;
    uint256 constant IC0y = 9613660499853236175565479199354614766631760062389264951890347118304555974840;
    
    uint256 constant IC1x = 9701672011119105459322744674562856961986323733033714803458121608540863847031;
    uint256 constant IC1y = 21111436421952017530143662068340014238227400423572827397495241048125910431288;
    
    uint256 constant IC2x = 21800473880765139739855019803461889191909572676941492841627678968944465061909;
    uint256 constant IC2y = 5670172630800971414251205582816106967324961710475852054596372392125685034665;
    
    uint256 constant IC3x = 15584740860986160509431640216551476033716227908950606646591783765693851530635;
    uint256 constant IC3y = 15743824002271307657398822940651824581129983608784632485256698156800610368856;
    
    uint256 constant IC4x = 18364275285079317479002197744712263509373691826710264400156953153183664769314;
    uint256 constant IC4y = 18874250553700278950386180876078675155127143944569902337419879807607433606542;
    
    uint256 constant IC5x = 14900528580952809136349547382528644407666855800203829971509730238220030106579;
    uint256 constant IC5y = 18207517739373585564312300312943943092526618289488358711274582526314727791828;
    
    uint256 constant IC6x = 4821172099322228248595697078615447143356754236966711008368355476161614527841;
    uint256 constant IC6y = 11930738184869947946725779938005000490380999379250577481552266511607719406614;
    
    uint256 constant IC7x = 1152669989624444031972483513062895650184746460220321984683967845066363822664;
    uint256 constant IC7y = 3380374908977043832488840266155204018857186383641208914737652561758997192157;
    
    uint256 constant IC8x = 8068681559723157809959807392450987199337204042431618482056775224673957234094;
    uint256 constant IC8y = 450926269502177608757575194217742568959693710522922571429337476432705859316;
    
    uint256 constant IC9x = 4634961496781291023764140068816126067096262968034193535139129836966844132257;
    uint256 constant IC9y = 10444494496802697378367480444953105469998492836429279427011712532187864788027;
    
    uint256 constant IC10x = 16650786670053439043782924143893509613148079984896593459535801690629261664894;
    uint256 constant IC10y = 19555595366595353429079682896076149275632947690898383328191583844873510506215;
    
    uint256 constant IC11x = 11427790219318931812608879412615006267472888929763370543410201157185123960042;
    uint256 constant IC11y = 12253636518549579346813699667013728990158315582413394169722521827856596863173;
    
    uint256 constant IC12x = 12497815018137891376770369801168911495766410584330159592718699605602264231258;
    uint256 constant IC12y = 714814965220708363921567089945802869965812023870423176667197407884053987469;
    
    uint256 constant IC13x = 20208609400501812917277862962510708269125213092557433439489069636378619412656;
    uint256 constant IC13y = 7640077129232476245546328957833439629077874582204691552438863807487007690585;
    
    uint256 constant IC14x = 9089730745714261325931989840302178261463423042680872870889845168123640385445;
    uint256 constant IC14y = 21669709091307038587456998175258097231392207998433706151751363127371519807158;
    
    uint256 constant IC15x = 9532455436115388155512469427355649776568272390342527300401847985493866775291;
    uint256 constant IC15y = 14930619618788200237449156637886123700862405794160761519906582676683735126855;
    
    uint256 constant IC16x = 21004662813401720684980049455432216497266507567386275476978742449699659266772;
    uint256 constant IC16y = 10838459468469047784665679536465768143708564944776709530927840692857702773600;
    
    uint256 constant IC17x = 21405257502534223647151093847700821327765497039886952589745954847567171556966;
    uint256 constant IC17y = 6558328098050846564200706390255876975730707630265570853277681366973925335260;
    
    uint256 constant IC18x = 12249239616351699147268904347716911209663574400736926470425980443680413911721;
    uint256 constant IC18y = 4028586204196238278941918459046625708114197392456739727339858029428553144507;
    
    uint256 constant IC19x = 6320002837380484894832781697899721798313491755615181924057736617758132084556;
    uint256 constant IC19y = 1008070145564705832952936316908576490449641716126197503893686798057151800005;
    
    uint256 constant IC20x = 4653048962126902576620849356068184289771581209547212353936213445381942427932;
    uint256 constant IC20y = 4175760719722777132785298766940779620598594564994634534133051709939511337243;
    
    uint256 constant IC21x = 18789915619387950870394393325426110911852539188868921354741159729262009114048;
    uint256 constant IC21y = 19847141048195360345545155105780433789420266856370383676904327220641890170336;
    
    uint256 constant IC22x = 2216391462260878275495744491999319975173196394715624780249473325267124759468;
    uint256 constant IC22y = 14085384786084964388169056862149861856566174292083464383075061335408392914349;
    
    uint256 constant IC23x = 2166340912759930267948801349812021704267056628296783928096430227940608741609;
    uint256 constant IC23y = 15682647121028158115712341751982330942182735588097966993782948622457716421581;
    
    uint256 constant IC24x = 11837698920722810917102684266670716460025131502148225399010935336071506363727;
    uint256 constant IC24y = 7458953428939136559004984520546955365878916041600531647206204452826497025238;
    
    uint256 constant IC25x = 2877186412122093041169491345520667260181192808233194876733583378807699211809;
    uint256 constant IC25y = 19051392925082860029920554393450059821069718100503705797373062754413296860928;
    
    uint256 constant IC26x = 19432927765152587523180771401441979392931499526608531721528487046820417978141;
    uint256 constant IC26y = 3447787623009008269207115672386906091091681412414022098287085854553537962119;
    
    uint256 constant IC27x = 12076043700266436856037030701556838994187731390964375818003138480415744877840;
    uint256 constant IC27y = 13566856587093929470617126060346809333262171265897978645108128251094373841905;
    
    uint256 constant IC28x = 706964189270765278741918568465039730500676987766991003384308995240407453493;
    uint256 constant IC28y = 11700749893578386602517522511138144313294045881419355675535079472551136660077;
    
    uint256 constant IC29x = 18385181411963240698061187232575692322932703888599941070231764681555001421832;
    uint256 constant IC29y = 5156235887852497505331301172253031469228013107201849354096986659900110588264;
    
    uint256 constant IC30x = 21592993367633434458336901738139895387671031488047273972337722851234367781007;
    uint256 constant IC30y = 3875819253740260112851052075260116840497291615366027265703266524588445689661;
    
    uint256 constant IC31x = 7822535175245816680319690184382036179998878870175247141405981941641250054098;
    uint256 constant IC31y = 17005177161436333011734883330204033072134808764751876117397544272592790222396;
    
    uint256 constant IC32x = 18375193207204684364496686867992455630849053542136529584831497736075085466282;
    uint256 constant IC32y = 13423553170373040741541328220236136832576824533125777779255627737868652358918;
    
    uint256 constant IC33x = 18617541613710930073766121019589753103640703648019190490106526612138401239448;
    uint256 constant IC33y = 11863458777896633910807136170800237700281147221067391516738343696758515680446;
    
    uint256 constant IC34x = 5234932155211625767168640857721013080379881063241672139495223384087237418317;
    uint256 constant IC34y = 18994228359430542130792143401929035573054393442801896415983171771564845072148;
    
    uint256 constant IC35x = 6081238323351891665017660780696104600200036916701969830764819718182523948364;
    uint256 constant IC35y = 712561849525583662599600836030328438176584954272661541079006079755095620985;
    
    uint256 constant IC36x = 1845549641916969041699727441647821307627161650895018058966270527188900917217;
    uint256 constant IC36y = 18682854226978874423932178960609144622219869192323821586569005907050955093243;
    
    uint256 constant IC37x = 18167727859229746244982917146862963853448505877996642124989712666877649264444;
    uint256 constant IC37y = 15423764038589242607858958951852044107483416301923744404267133934899845036607;
    
    uint256 constant IC38x = 3175009130279764969199205178420578716554670416115400972913143468631819299475;
    uint256 constant IC38y = 9088659598435360239487563628656611510190573562767666181070683848037534445538;
    
    uint256 constant IC39x = 3741050537788041016403661343279189255212101606887421841506373496766548819878;
    uint256 constant IC39y = 17292676312500862440495043809569904738724352916421774196198983178311578505080;
    
    uint256 constant IC40x = 21620300349170295234203223764835913908471393409198140809805487891182931894294;
    uint256 constant IC40y = 19045569915937512583378943803605878712199609744890399284932064315893406852305;
    
    uint256 constant IC41x = 15674690987732723257875250125196766322068887192731023497242441473772525902144;
    uint256 constant IC41y = 10676052758791610385147871216207818912841346253802501092437843909176288414642;
    
    uint256 constant IC42x = 6105338980676264139286196746985507239233678872871676048251552871097505388462;
    uint256 constant IC42y = 14329985401657968439388871526376935673130495939642568636223594681292031943248;
    
    uint256 constant IC43x = 12143818049883297561311190644994714205817579783463571075352007059176667406144;
    uint256 constant IC43y = 12443352467749516848579557211671180865431766579944462781855202277875714142564;
    
    uint256 constant IC44x = 21270044200131590207783323557068809051605054440729245399610696995205578554127;
    uint256 constant IC44y = 20641255962640916325740071882719059292180118627344686033605792575310786534963;
    
    uint256 constant IC45x = 3852330938663335231730660716731433167958750364950440658384605038915719429451;
    uint256 constant IC45y = 4940836680846237987962315114735096480098367473615421542746728568864265007924;
    
    uint256 constant IC46x = 11957369305081166485468268386879540891318927590629784439314386845841579957498;
    uint256 constant IC46y = 13786778902456219252561612962478709980017597532872571049496475097624132235485;
    
    uint256 constant IC47x = 8158034978384458610709650185082896923324021532394702004447170288265050447313;
    uint256 constant IC47y = 1461122969710177854156824125267148023272004127490744967875457789067436698096;
    
    uint256 constant IC48x = 17060886774588959593582755657581408336058141624708207394264379766466839033386;
    uint256 constant IC48y = 14226906860779972854441843443031238800309882929233539340443275121438733624722;
    
    uint256 constant IC49x = 296466297878529649558880558206167863244518016306436270323639018313477596234;
    uint256 constant IC49y = 16342990484525274468193974736298219328805047339139079626530957628719209962850;
    
    uint256 constant IC50x = 20893605874386791183580489710743449342783327721786924678753009320045535966671;
    uint256 constant IC50y = 15197549615316179197738315901128142842419765567344763411822870451880353984567;
    
    uint256 constant IC51x = 10005284263170205369965694545814078948134077762161777182460309738734501470562;
    uint256 constant IC51y = 11539564559926140189542206571448052300383119325090695629224808628838531960748;
    
    uint256 constant IC52x = 600909592400019632596193937270148441695283160764907311797806446167901878170;
    uint256 constant IC52y = 12159767235455515603791567580695451357582227101775784302257754992290881292925;
    
    uint256 constant IC53x = 1435292082846351422814024167533052355817778153370353680577005276144037895606;
    uint256 constant IC53y = 16979185831769598091332380549454945813271300167799909431132913448740872465533;
    
    uint256 constant IC54x = 9107336900894777769703885548368299339333522760959304044594224143420288296315;
    uint256 constant IC54y = 7559915080375645313416373444327805043438580754327343125471301182446312339808;
    
    uint256 constant IC55x = 18875303224053043828609495990947883988443674519507384799016853063216023991549;
    uint256 constant IC55y = 16774264351389688060090008556828202393290744294090007956148975372020589580385;
    
    uint256 constant IC56x = 15971328983402729760659233242281413495168084533635351790541990911615651644858;
    uint256 constant IC56y = 15568367078241131157607456727737781948174041939857802958072366904701299431162;
    
    uint256 constant IC57x = 18945996877444142370494118532999488929374588669520832396269702985759189063141;
    uint256 constant IC57y = 9699551170418814730934649037206097552671485885893792287240842044840554248567;
    
    uint256 constant IC58x = 1578735978605481431629933411993843341933390182337376447999702708108577014622;
    uint256 constant IC58y = 4297785511679971865635251003303880445604666075940828171136426010441373045831;
    
    uint256 constant IC59x = 21714399300416422328997955871577507863642804107204100742109649078531336277981;
    uint256 constant IC59y = 4477181389200183142977319858565558780248349312723783827226689237138121536532;
    
    uint256 constant IC60x = 4739310998787130694173819118046950141700151456903441234570470955565848685417;
    uint256 constant IC60y = 21254095621398000661380641854015889102164307731663792547352046012407570891807;
    
    uint256 constant IC61x = 815012616562567657793962613079688951635955945749478517254408559325512372934;
    uint256 constant IC61y = 10663105658989639068771792932408238496103387181491100017278006280286865559496;
    
    uint256 constant IC62x = 16380239790503052131914200462395843606534486828646813377833640835429615869109;
    uint256 constant IC62y = 8942285630032146080935657907230687474616622013064643016791652009311754867288;
    
    uint256 constant IC63x = 10617058405830208826307703258682715441302153844921771831626175750690551491333;
    uint256 constant IC63y = 9747601799003592876277478086311761116685530810362776963479408138748505344049;
    
    uint256 constant IC64x = 507629664941614416630398508805667890870711694149694292430990593644358627941;
    uint256 constant IC64y = 3760036464072786139969895197369140660187310775754835285075749522284934855612;
    
 
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
