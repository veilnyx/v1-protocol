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
    uint256 constant deltax1 = 853350041878762434026922071827089989374586619922676389278573324736937853696;
    uint256 constant deltax2 = 4900459089355420311825744666911113454725536520876153521461710037289846445140;
    uint256 constant deltay1 = 3864487841809130752921911906962552080014661440583093215673891287817590316580;
    uint256 constant deltay2 = 2666074770643401194922244979923172154826680356500413793725607125345128422432;

    
    uint256 constant IC0x = 21730630934736960218246871771531362581792212862129306396972743151784120576253;
    uint256 constant IC0y = 13291882588378311666422069327347908411943641304023683467505259614272734399810;
    
    uint256 constant IC1x = 21798130370918700569245362332639332445398376476121925726549262808540480986102;
    uint256 constant IC1y = 12379999293176794368927208776784249524230074082191217797941571716240797348101;
    
    uint256 constant IC2x = 14011887620483890304830035541448659870779873894566840144949546395766630046805;
    uint256 constant IC2y = 11868269169684109469275085260022562576624975853619723531439217689355471823687;
    
    uint256 constant IC3x = 17828303426635097870838460160301581748783428015260219970722681300649551258218;
    uint256 constant IC3y = 18578319785916215519892198736571189900131588337371184917048850384772802872421;
    
    uint256 constant IC4x = 6461129994486142108072394369006165837072824143309411377752293366981830827456;
    uint256 constant IC4y = 20017760036824830834484630934211366334445313270173221890847161232529032346656;
    
    uint256 constant IC5x = 17870962294436583985733596407817459753127941597054028418871998115928075802256;
    uint256 constant IC5y = 14415864742285822062583753620734307594891297966795501493484831361123114998886;
    
    uint256 constant IC6x = 2970217955604039598206493277418901903367273376966327192765946867589456459642;
    uint256 constant IC6y = 2374156354436173796997547508920593369989620613813381431736632668936188212032;
    
    uint256 constant IC7x = 10411557183892514974841420568680890624077646534934409587675694443339229921280;
    uint256 constant IC7y = 663771001015843040482358018622750391470768147559099820803812961560923877908;
    
    uint256 constant IC8x = 15281326420300962589464465702796024325197722208666585791517050715481686787307;
    uint256 constant IC8y = 20505477092727626501071807243395138275591127042657508079353456397764695763179;
    
    uint256 constant IC9x = 9914394185363903167657044652688398293945433272769934551940037805157920959679;
    uint256 constant IC9y = 15759856710654517208911683153287983807010749513573526431075860514411556737511;
    
    uint256 constant IC10x = 8409072947165486700328218343560424667908822922561281172069589665506692764703;
    uint256 constant IC10y = 6046360062269578720124700487264464785973898669190005179652906193963587842865;
    
    uint256 constant IC11x = 4630679800751875283961496197238126409695684963128929719307941483832008531264;
    uint256 constant IC11y = 19824662104134903268109167688578686482753773994898912412424816641787445377041;
    
    uint256 constant IC12x = 281998608633695355066399506567432285655862556703747897809544928205140886608;
    uint256 constant IC12y = 1475961854350043623099636865191331847795747618451625699328323221794373897763;
    
    uint256 constant IC13x = 11856841838116489956031875214417243665685477373846030152466166420223198797369;
    uint256 constant IC13y = 7488158011587697648717480020686523105411962895926277422356342295042595293039;
    
    uint256 constant IC14x = 9064837004088226901865965412708651074374556305737301511862680823866597032532;
    uint256 constant IC14y = 16444986332242732830267560286763848598900461083855535641668862814758036337322;
    
    uint256 constant IC15x = 9205488997386540608030587574931882109087869400173787828573671903467068928317;
    uint256 constant IC15y = 662858615054373581158534357147108359746249363903666114011743043330299586723;
    
    uint256 constant IC16x = 17681635379632608077488605417788627427066840498326833756745544861695235503681;
    uint256 constant IC16y = 5642537136189238336673635828034261972450066874959501107943450626642460827179;
    
    uint256 constant IC17x = 18699217330462133616776351343742204637808553796508629367518402345640566440002;
    uint256 constant IC17y = 18514364477732116177591289542393067797073150554384311808410719502982217711349;
    
    uint256 constant IC18x = 7657516638856135380812120220289519026616854788852301873736670209746356533131;
    uint256 constant IC18y = 9810989295191642528134675687668075815085177095870608454368754027343193923098;
    
    uint256 constant IC19x = 3809760412748201396710635152121350157924918888967765313632739742972623892953;
    uint256 constant IC19y = 7907426453188508606646136208832311588809571630931801875522382373089103160987;
    
    uint256 constant IC20x = 13953744862386889424344347281375240079387212829730069092259017518299797087433;
    uint256 constant IC20y = 2269590890643179252912338950442369725524391538052025442693921667238624459582;
    
    uint256 constant IC21x = 17914123511474535491520068683924341503725961523406171164246387963895440253657;
    uint256 constant IC21y = 7284876059490705453528212372852757144061045056991856917676490547061874511645;
    
    uint256 constant IC22x = 3337691502879539554439910684184174945181109599918550038445184792228059588988;
    uint256 constant IC22y = 4644753697351624476951798048942467865872488389716767435904179902089202872345;
    
    uint256 constant IC23x = 3877215680912127591268068312305449828475587583743458487210726581284064634326;
    uint256 constant IC23y = 295311262447261306866262126852152338331760522179182596454476066780798785790;
    
    uint256 constant IC24x = 17926806039835136379697309812656123177797327374452242112796448407024075074356;
    uint256 constant IC24y = 2808187191531861736320451945952041288118438026331447722691872915733165856302;
    
    uint256 constant IC25x = 14838889987209473435098168094129759236157814713186750535393350244968942505500;
    uint256 constant IC25y = 3254931370286821526445345395991028372562483403884757077335517022281133909259;
    
    uint256 constant IC26x = 9351794230483739883968818774463854284825023814894599881862380552003810443755;
    uint256 constant IC26y = 7853721527002671898811546208527148688678090471292420736383454995962959590905;
    
    uint256 constant IC27x = 5888302878845011862924417036780744711801143758596012843415416878152711591290;
    uint256 constant IC27y = 15179468383481276625821599141697485120389944631146404168481297148802112773423;
    
    uint256 constant IC28x = 14712616030413165739466324832835406869463837441728580424352901414254759338693;
    uint256 constant IC28y = 17814648232678926897577270704498409915485085415076207913146184725406969328527;
    
    uint256 constant IC29x = 21338332840717784189865588892735583494580199024014819532973361961244266807822;
    uint256 constant IC29y = 19504941631951506974168335781022186782113292527579214208263490723119805023961;
    
    uint256 constant IC30x = 15328236740214664912446791118884883005372095851457129575482357234453947916491;
    uint256 constant IC30y = 18992594072488440107583829314285005887479244587231363190309790801016245489568;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[30] calldata _pubSignals) public view returns (bool) {
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
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
