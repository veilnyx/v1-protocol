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
    uint256 constant deltax1 = 8143041421509346634172910568566320302121754829422529567281525876012080709254;
    uint256 constant deltax2 = 10132693360046740063277339355608053838859301359794124846712630607971485802063;
    uint256 constant deltay1 = 36912720488357604692838899099759175192799932891483700396139619055193807022;
    uint256 constant deltay2 = 16728538279974239405325944950913098796000959625712655209162681029279578358367;

    
    uint256 constant IC0x = 4701505549702199080948784138891845059422729038733957025159128684199483596147;
    uint256 constant IC0y = 7290253775760115267299320459430284548093024209767668805353659590421933574389;
    
    uint256 constant IC1x = 3319919457629438681313092621339435506853669222675664856771888832375835304686;
    uint256 constant IC1y = 7189096553309358327711363851905830746928150066447883762492171836972704162643;
    
    uint256 constant IC2x = 3693528506664088019954352577593057276204380322575099553345345404602130229472;
    uint256 constant IC2y = 12347002747704032022868340361907944044807881722873060619205736386773754881973;
    
    uint256 constant IC3x = 10230221988773557363421044351742902476383155693423059473845696531054212766533;
    uint256 constant IC3y = 3531453373179379951525843627303117092839815273701992755094106498234735476095;
    
    uint256 constant IC4x = 11168270881540419395093012622876953053028274525398438521174100292288950661369;
    uint256 constant IC4y = 21529972652032580223778064571002182520045496909359218112246846779047397961659;
    
    uint256 constant IC5x = 19195743634471173972952259906540288880677136032631221704376295049207301980709;
    uint256 constant IC5y = 7042403711820023220627317845158910535290258969857188139672000933170578677955;
    
    uint256 constant IC6x = 3599478879927775115859361116786325393124733231394765743126550790070438889208;
    uint256 constant IC6y = 5767578545425573259929641570954544852771478740958366300194533173768814092904;
    
    uint256 constant IC7x = 5334794506524161937066359275987494452069591059378181663035763600458284216978;
    uint256 constant IC7y = 19102997320492670855146810247989583322644818893628274054214963729763235302012;
    
    uint256 constant IC8x = 2574238035326085638777002988735684946632752238768514216337136652832293355016;
    uint256 constant IC8y = 13116524897405116665710443455561652201606878782437510738848609960868035521936;
    
    uint256 constant IC9x = 5547296794320561097053105805080563295330389406197624762088114579291411748705;
    uint256 constant IC9y = 3846462140419624397775257747498809001743035571698543822154743252271221842643;
    
    uint256 constant IC10x = 16131366910753959203903812401191541038664641790579857110880331165164638222281;
    uint256 constant IC10y = 8528546820366437238474318733968570584800740629530561404622467435684827146496;
    
    uint256 constant IC11x = 18080878677141341385255550503960650459524113634409338524335915124364045531363;
    uint256 constant IC11y = 3393606296922677903001128657053165482753526606650956541375098933274039178425;
    
    uint256 constant IC12x = 9535588327825488478544592013049313364368892049417575814820741891880143987468;
    uint256 constant IC12y = 16995822360498149746004443871185885671965420401302908862629559732061566336014;
    
    uint256 constant IC13x = 6474730108121819050350129048769104844531473063262120399766798358141996161759;
    uint256 constant IC13y = 15025096503988408164469711100015983624217422894142653607747806753662925640236;
    
    uint256 constant IC14x = 6661314307644634008936352906687379290294217256320447835337841584084879177372;
    uint256 constant IC14y = 267798237344086410987300196034692525871480980349531591388437693229208109391;
    
    uint256 constant IC15x = 3097184918728781592950730926477592623942866504076467953759481855191605147662;
    uint256 constant IC15y = 12424790453912881194185384071715335962985992101859757214026417462828625929793;
    
    uint256 constant IC16x = 19493146847825474251331337888522331806916242177218574262247202500657496975283;
    uint256 constant IC16y = 6188324625122204300421983679056793073583106829246893925489195100325191210551;
    
    uint256 constant IC17x = 10140863081705475945389943835314083148740287053240593030356799770791063478793;
    uint256 constant IC17y = 17674976791645402066064512731009027702029355833214134208578104252233416729678;
    
    uint256 constant IC18x = 4863196591822420514480624108393609137280838476594241426451110199384009815446;
    uint256 constant IC18y = 15200514908298117815437588441074933006116943377160082345428026739309693128465;
    
    uint256 constant IC19x = 1003314688832131947738782826682428414271927634647804484734488862691827185819;
    uint256 constant IC19y = 11206175909084096410788415965593021381008340842297698595932969072002038193240;
    
    uint256 constant IC20x = 13298017990885269307126875799328198951305714401494508985964871398270114437977;
    uint256 constant IC20y = 15132234860590628774838179304245119172235689043537783393527202280028374465730;
    
    uint256 constant IC21x = 1744898098486428739651706058424412439920163712386219806583452175876394546451;
    uint256 constant IC21y = 12690570538880549543291653963908295728473787786061571267457153063204129324840;
    
    uint256 constant IC22x = 17625119322957826958653595383373452652131485674684623724776367869066838011554;
    uint256 constant IC22y = 765665481044362053621193083433407519282322299739903507499220760828644268038;
    
    uint256 constant IC23x = 4997113013853435541876979485076989648507792291021792290105464642876691591392;
    uint256 constant IC23y = 16872946365683435001328802649732283628579368868590647493348778444401069311112;
    
    uint256 constant IC24x = 7908629589483389618796004758710240110061904236848036286037425702916038170820;
    uint256 constant IC24y = 6573848570351125758133130242008177695766005091733419124145200907826401502057;
    
    uint256 constant IC25x = 16515511778234285916778933080584442690593343435580260633712603621735747572141;
    uint256 constant IC25y = 2991671716809122117630402835604163801699982881371633895915224514354972098039;
    
    uint256 constant IC26x = 7597633628512949265202927401253372849876125259392011720200774604688429409049;
    uint256 constant IC26y = 5096745348316676071986691709685828071781859535352735184072687171110031694151;
    
    uint256 constant IC27x = 2017804731293828237478943526714298745747878977482559912722771587807358204835;
    uint256 constant IC27y = 6236754808178891399159036090973840112888563128975273063218312746011026140097;
    
    uint256 constant IC28x = 16000083925067523383005271597353811905597466962646271601999827217044384576437;
    uint256 constant IC28y = 666110556490525091081891886206844357011735946339813520095478765023025446446;
    
    uint256 constant IC29x = 969481443032429683737632255241700513044102539488738278941286825568316548852;
    uint256 constant IC29y = 8038238061716637553467280770932433220471565531520021069155737612419878961055;
    
    uint256 constant IC30x = 9572255393133759220395152064827832818333125048963606264358871683118801119256;
    uint256 constant IC30y = 7801979663284740824487878987511451346712650090804514450253746048223200961246;
    
    uint256 constant IC31x = 19390842564033713707167996311287588673005934174954881759895040324517377688982;
    uint256 constant IC31y = 4920033903633739232194569656923051212908957025353530450942530896219795868565;
    
    uint256 constant IC32x = 18401753398865521459639116751050480618560765717633694540221487303102504610701;
    uint256 constant IC32y = 17895630081740944736215268444535130244844522507230067673005402535946026929343;
    
    uint256 constant IC33x = 16166388554467155106083916031602776813422586211326235641198189673515237758875;
    uint256 constant IC33y = 18451891303863870837030732773539520139612696992175635784801244693252659386579;
    
    uint256 constant IC34x = 12763166398034697641290973276342128218984444013223780725545365903864592234740;
    uint256 constant IC34y = 3150254869498875741819863910348867397850174843243503597383691847425990301247;
    
    uint256 constant IC35x = 8736043963234247690827463490673424630387616794008092674618575492903989565510;
    uint256 constant IC35y = 4362285702336255998334670253916189032019637982035311162068126456237356160327;
    
    uint256 constant IC36x = 12671995058410004229443835040725104663571224114184551115279789414004462395890;
    uint256 constant IC36y = 10033955771169774666209123241962161780669641219705198382194441695993265498812;
    
    uint256 constant IC37x = 11654377396040971137005479386962794107533582023718894783335996297177640445827;
    uint256 constant IC37y = 13271391419383576909027433468919082155059690119698601983205608535402195422493;
    
    uint256 constant IC38x = 2371759622774726655557006942213314286681974453537183832235073727121701678346;
    uint256 constant IC38y = 4176235514480489008083722118378582956717947774086541023336019985055321700834;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[38] calldata _pubSignals) public view returns (bool) {
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
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
