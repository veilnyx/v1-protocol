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

contract VerifierTransact21 {
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
    uint256 constant deltax1 = 580589810296486450122376557907933632314472557741185242216146730553079399497;
    uint256 constant deltax2 = 21380729994948220531504826454715387859570484961498870435729583877934730941772;
    uint256 constant deltay1 = 18461784946483779535221130163837689510174659787585918144459241798729086579814;
    uint256 constant deltay2 = 8515228049326987563031668420720345048733714322598869801794779386605053105575;

    
    uint256 constant IC0x = 6959846532858429729603593896531988840268683492854407482779530194006606538523;
    uint256 constant IC0y = 2626570905741786573153802976688101092393157621344637129316420346599844344986;
    
    uint256 constant IC1x = 20441636722923353548761276311017980281694837157780803932624213987352880025488;
    uint256 constant IC1y = 10599811289797809015560746329449545515312247738013479905391913569244990735881;
    
    uint256 constant IC2x = 9263660783269628340447959994005753405011127814118858416992431293642352953841;
    uint256 constant IC2y = 8404294345809072185520072466088268071320425649329379159042909675806706915799;
    
    uint256 constant IC3x = 21109873652308115100342106763327285598619783955985589558514216281108215338372;
    uint256 constant IC3y = 6915482421795871617069721276730512150344234230842045672721477210627777465580;
    
    uint256 constant IC4x = 9024548773086498760438618505656072341989981581810336309510657436439392963171;
    uint256 constant IC4y = 20569203007466790825634910613671669125178958152052007559962529739590449469005;
    
    uint256 constant IC5x = 7150825318934498189322700715354790396868882810257497028031875598328629864604;
    uint256 constant IC5y = 17237009331119109641184547687877376925235898996129969138605814969183706589116;
    
    uint256 constant IC6x = 15563793039970954765006460978166108985871788766194686694978867484963062436879;
    uint256 constant IC6y = 17597214944557696826850539874902716950698784936083870246721002191388237197417;
    
    uint256 constant IC7x = 2474915898727367161240793884812070584001536375672520024956918562675892909228;
    uint256 constant IC7y = 8428666347400454196074417093113909221339289010625088066860763083611101133342;
    
    uint256 constant IC8x = 11491396298862520915568466584897250219926781461987584597316857150249961271453;
    uint256 constant IC8y = 13093356232709555651847879843080265476761263477294837487432222509275753836611;
    
    uint256 constant IC9x = 6816339790471885996333124762400353048836162926539948974782331897293811335030;
    uint256 constant IC9y = 21592497916198836319841974252379514988671115178354329242745601726739498074115;
    
    uint256 constant IC10x = 15173676308466215911452836507326487703086914930751662520971123488122285984987;
    uint256 constant IC10y = 1948058175153371451279521656417806926604830012740347189064138996812870438664;
    
    uint256 constant IC11x = 12352691864772184630391131377742186151376846806137691612419912887579557527999;
    uint256 constant IC11y = 12792919848714454715375361318348222566716704416434549739319053310430580055236;
    
    uint256 constant IC12x = 7093554661659924746469938521626654895651204274880756133595054334157319960699;
    uint256 constant IC12y = 17135806222695475332309676542682826720694606358075615012871062480365150940703;
    
    uint256 constant IC13x = 20792472593378840664747420131330585080652267348468369267012562190547694917445;
    uint256 constant IC13y = 8627769244117478980608025929632511501601117103872114315424298234277086230744;
    
    uint256 constant IC14x = 5647677499728052163460918135776146491922199508546091214158575908893926636183;
    uint256 constant IC14y = 12853541516253781500426985728464961184079164965301755313113913468668346158966;
    
    uint256 constant IC15x = 19411621811501463797050933441608118356429644643294167653526498911282785630849;
    uint256 constant IC15y = 20688208603583355733829017655901611915143315003115199500769068192206534226457;
    
    uint256 constant IC16x = 12408476612401383664764469340063328863188356547928628286556349454846401817038;
    uint256 constant IC16y = 999810081869333793243562020927655450419327792318525666870019276940081492353;
    
    uint256 constant IC17x = 3424421024947797748993173835275373440234741130695068229768557536082651691067;
    uint256 constant IC17y = 15349194651300457245086427702290899250165149438116157037409229877561369643741;
    
    uint256 constant IC18x = 9451414109218787860500269833443951891267449099613201374590093717906084317158;
    uint256 constant IC18y = 9509643275730820249202670022393627525137805905901569284822155646703154059528;
    
    uint256 constant IC19x = 3861035487735938818246929988696517935623759089994404350369535379221273347154;
    uint256 constant IC19y = 13657963297606433860354510307324147552851660782926542952551347184272852727355;
    
    uint256 constant IC20x = 1972956186756596588130181369080537662663347650686752251776936103155011036411;
    uint256 constant IC20y = 20699924653872366020257369218397875887372763468793092218654030158270372978193;
    
    uint256 constant IC21x = 8008363792347259687196104118154699608901582800541303010373038014480792562897;
    uint256 constant IC21y = 4385928042079542280148610516738883606251876932492016160764560934768357197502;
    
    uint256 constant IC22x = 10293476129618475301841406676495038069403485719773133239385431651583529469454;
    uint256 constant IC22y = 11672563841861229001515363588946845964419799911841210921763309741996617331155;
    
    uint256 constant IC23x = 15305863543186010992940871312311439444833770190464233678698029659150396020765;
    uint256 constant IC23y = 423156412491358918986652260381808821287127024547248964399901101119883170852;
    
    uint256 constant IC24x = 69320183812170822757594187040505249762330123945237529525026892041044427643;
    uint256 constant IC24y = 19765862142011310357522606430627126021002308405611261987861125839596961405094;
    
    uint256 constant IC25x = 10147359376303648738753942929228200865488091618433479555494310070397770962263;
    uint256 constant IC25y = 4458481985964773240240890179404162158814582760756571947941640734266516831070;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[25] calldata _pubSignals) public view returns (bool) {
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
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
