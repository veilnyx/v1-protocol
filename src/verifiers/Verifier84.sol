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
    uint256 constant deltax1 = 19159977593166587443865116346006224951770265179057940094150202071889285222755;
    uint256 constant deltax2 = 10835072937836109146350344326313385768443583765241005164214482708925650389507;
    uint256 constant deltay1 = 3199645145495428756896778316430550459595833450673256140798465865146768812016;
    uint256 constant deltay2 = 12795577719927324568728573213830447259616438404717380054289546740444163463005;

    
    uint256 constant IC0x = 14798327403146654837696496331044350223711265294330380243999609909477819591260;
    uint256 constant IC0y = 4332169064887554875047390411308809200433767199604980487095798857062724277347;
    
    uint256 constant IC1x = 13666531561222023404020316108827656465001125977864055924679045423116431303409;
    uint256 constant IC1y = 11818000575223274628839328698175272872981645386504267190778407870773152095090;
    
    uint256 constant IC2x = 9910000942461804011875707027695424045970962239013635549253217681960068620091;
    uint256 constant IC2y = 13492203081144049721768128827392009765895850529662266231542201792709906320029;
    
    uint256 constant IC3x = 6139858793375482000511934797816765590951195205982586899526827141166162099850;
    uint256 constant IC3y = 4786019881254872706535341263239030498648629971980934540348038369787885574280;
    
    uint256 constant IC4x = 3915525691751779351642836982397347533412071830364541060447220893642775600038;
    uint256 constant IC4y = 1738414276106782367105658058816348178510039522956531205622425265608073449898;
    
    uint256 constant IC5x = 169502383029425510680630074258006902005389359159541580815449032612064523639;
    uint256 constant IC5y = 20962926183933360387615599322025899162014433998452307751630027753778187748080;
    
    uint256 constant IC6x = 252635080502841279494348835421388629402278053854332684097798353332861642963;
    uint256 constant IC6y = 4950413329429714475036647360608053300960967678384618916139999772430916428769;
    
    uint256 constant IC7x = 3623563466007493428985931826607351589626866408491845961416460084812890876565;
    uint256 constant IC7y = 9491695869836535353711279042491106504862482891615431907175591681938418285291;
    
    uint256 constant IC8x = 11693434380567968692287045897739670831893157872272324747222831840778399377342;
    uint256 constant IC8y = 9373388149936834452702997697113714940795266198149368774366298616614728220520;
    
    uint256 constant IC9x = 15358647313864642012081377550516140481224428190251164405045308747353791671405;
    uint256 constant IC9y = 6847334460149672728010422843384387189826104235287259594022151275434018923215;
    
    uint256 constant IC10x = 5507056016569199098874188309852861441401370153692130800174985768961205772098;
    uint256 constant IC10y = 9650973941715057820396248137398616458131327084093704986201295526503240531699;
    
    uint256 constant IC11x = 17978195432745399265231253737561800441948427785015498173044109185476518724296;
    uint256 constant IC11y = 6875991532246663053618469007623907230146637810496369725681957229305580856281;
    
    uint256 constant IC12x = 21548946227073571068065113919457356985768630457060415658735062917553413533810;
    uint256 constant IC12y = 1065044927337365510267016447160893935725642201591130174044436773383441469718;
    
    uint256 constant IC13x = 13866881219843189651178722221368780126409490921257214722041955325261825043068;
    uint256 constant IC13y = 21313116446112372596760222324626779444310699604558842574258596128574390501275;
    
    uint256 constant IC14x = 17334194542310436978265325707266033136885375832615726477609622594486900794042;
    uint256 constant IC14y = 8508670374957955609609861174483745739956950096251911733643793150349589314475;
    
    uint256 constant IC15x = 12835740011682337461408132486147822000135959828256098621333047290868515274960;
    uint256 constant IC15y = 14376248933066675005283344282599850933129828850496853987525083517477767667837;
    
    uint256 constant IC16x = 7312355377525983991853252563108458401063295320365309002624445074257392484228;
    uint256 constant IC16y = 21107259999137908815041645290663966712466448658118582617843058563666971210226;
    
    uint256 constant IC17x = 8972300341963589179242315855140713820581991614817324976032605126403082362876;
    uint256 constant IC17y = 4705008851437496336167271190354084689084705689130854768521262082324996298729;
    
    uint256 constant IC18x = 4530925871986052048126304846477174916660090682528171530310405489522332390700;
    uint256 constant IC18y = 14825720549021549409970520084360817260386750451862518099120501253788811953197;
    
    uint256 constant IC19x = 6903047053853848851568929008627626980948436377131981026696633263066166071865;
    uint256 constant IC19y = 7444372420568440193336163912987332949715582565107177484300781182413164005343;
    
    uint256 constant IC20x = 18344092939767145922187330274837389446135998496072329343364189231059359865981;
    uint256 constant IC20y = 21815780862677793785798663973592308817296916978152614249660739070291338744188;
    
    uint256 constant IC21x = 4306421213845585218895757138321448532860537420599592505592759717927688670059;
    uint256 constant IC21y = 14141232109977336291656810237443206304848464051529158403695349556983044555658;
    
    uint256 constant IC22x = 2617761473920167612322979097900976810864264611722468153237730192689668050748;
    uint256 constant IC22y = 10339902346505289077797180701990686837825248487006894267618851020159977491317;
    
    uint256 constant IC23x = 10813390469447508128062710850632341950928838871318874937620425655741587445190;
    uint256 constant IC23y = 10152872257489232395337494550314065777616580833126276302303045546279900993344;
    
    uint256 constant IC24x = 18130057819794632171440429996587880155729313852309062461141739163773887030340;
    uint256 constant IC24y = 17241279377628434964269136493687928023375392137991651955867739187976383764521;
    
    uint256 constant IC25x = 2587312939555340118137220455377041290597481090992365315115655316765786146886;
    uint256 constant IC25y = 18959244429682395804674409518629069383008525260992184487274774831255235181720;
    
    uint256 constant IC26x = 16186113467033989265034547767626295824846277762124816670038756767015291065857;
    uint256 constant IC26y = 14572080626725340727429938321116497681642979401918366958981787440479793138686;
    
    uint256 constant IC27x = 21441343680749711428403436830310766958977497065617912152144134970345357942775;
    uint256 constant IC27y = 19501367416332733707245117187306931047873858412110778955919383161718965514194;
    
    uint256 constant IC28x = 15386100600919705362915260389693101207129489317075665242489343149693192355336;
    uint256 constant IC28y = 1854776682744219853862761108155650669587960291299080547134695130541600071641;
    
    uint256 constant IC29x = 8662550547550379850513413934192225528758232718654560873821571553646680219457;
    uint256 constant IC29y = 11538420732693760411586450471408429719445603264008474302456434626938243462299;
    
    uint256 constant IC30x = 16154248861040257040495551650836778358576482276519541414394080711371376631650;
    uint256 constant IC30y = 7017023572516215668431804532278065373852338838280697524648957944294867270655;
    
    uint256 constant IC31x = 1768536822808477360695521437953569864248084892260056286779376854061080525577;
    uint256 constant IC31y = 16954440543799888690972130956096062810117675899192782085866148918353047189128;
    
    uint256 constant IC32x = 14877211709108000734477980560419164322057086994316364205018032436192518330033;
    uint256 constant IC32y = 1462817669212898848357181426682426949459378648470873661849487855156698268264;
    
    uint256 constant IC33x = 13209280063254543764603529590488807886798648006562452012272651054749052165132;
    uint256 constant IC33y = 18330999737277852425138035454512782795887001893046565233412997708880364391685;
    
    uint256 constant IC34x = 19778084569546130414912106015325385188137876744736602595548058233426295057226;
    uint256 constant IC34y = 17972469852144241329802390762846785185062033512112836709778543567006615442276;
    
    uint256 constant IC35x = 406838932629884812609086523147017555559254581882479741335729062820609672565;
    uint256 constant IC35y = 1060010007935452990615223660427414739301744806925385396423817411775062598900;
    
    uint256 constant IC36x = 17525506201031103790527162721666913958214468697471741068977511701029264269204;
    uint256 constant IC36y = 16559202135681344287172539285909506197869795127211240389695163343219397270748;
    
    uint256 constant IC37x = 14074904274161323352723282181902260059073660120287341281287154313410190162029;
    uint256 constant IC37y = 3043064426101707533805813058060318023132324922113129348615537112378280605869;
    
    uint256 constant IC38x = 15395880408680987388288094927497687507193358537017284066922289946658179796549;
    uint256 constant IC38y = 14267590107406209205161482234704424091074428257201608389405710468722012418323;
    
    uint256 constant IC39x = 9597855083820195665983860279462624918431268633552526291996217764266431545558;
    uint256 constant IC39y = 6940205622656097603137650396522675662562519440363470760145942255319807906613;
    
    uint256 constant IC40x = 12170408752754372128626632502754169362446368021530664093274049918353944730282;
    uint256 constant IC40y = 19787808974261188116185396870360549079224911341947579174365162861133236569373;
    
    uint256 constant IC41x = 6577452988322163807759212997720097613012350640116822878074470393165552197349;
    uint256 constant IC41y = 10411556088917866452533884224282764083711149661083140347048604511149796102839;
    
    uint256 constant IC42x = 2926145422840732036207541219519497321840419868979698652315865717114772151384;
    uint256 constant IC42y = 16778434120655496786853148040478555092600504327260826262888845229812958294195;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[42] calldata _pubSignals) public view returns (bool) {
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
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
