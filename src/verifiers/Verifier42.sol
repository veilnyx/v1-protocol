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

contract Verifier42 {
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
    uint256 constant deltax1 = 2802450447558815081429075180177391974519719747419397833793602196756187010682;
    uint256 constant deltax2 = 14804728077205932180873978483252380448641703567318037726950187793873445425502;
    uint256 constant deltay1 = 6857124992579137921195711943033982374407337281518512456303617041894440975587;
    uint256 constant deltay2 = 8048540770372646369880705656236045145679570239789680789665811778195316625866;

    
    uint256 constant IC0x = 8836747447330586951931339569400083319567466254156233500615089405786859106774;
    uint256 constant IC0y = 2414860681338870265971597511435691494788920683889194827883175061513976580653;
    
    uint256 constant IC1x = 16697750208558497765714117637259040396182407361126466001022770227708526360080;
    uint256 constant IC1y = 11822357397816461617602332698590836463117625048137816576825902710403185431040;
    
    uint256 constant IC2x = 6131597948117408116600603158104264313326600805393358531550611210549143705938;
    uint256 constant IC2y = 8114305167440409779969569980973284458095435958265103116422698805416747725775;
    
    uint256 constant IC3x = 13032530628077315650045469908907725729745814700482490992089585959336021575969;
    uint256 constant IC3y = 3922854555308081358308483445231134300403252839869391426232316151190659322274;
    
    uint256 constant IC4x = 9016328550329529006127821476255828064680759518333184368130589070957393934449;
    uint256 constant IC4y = 21280093497009889036745840467536371695284696089758784769870897588572397404792;
    
    uint256 constant IC5x = 14524246096276090368640936691184626059568892116801433248606200624038064599418;
    uint256 constant IC5y = 4856691402304401121196927239112079262938375173863847388087142212587333866378;
    
    uint256 constant IC6x = 3995878648064071052095018413498058793686148034232366066718682314911969626479;
    uint256 constant IC6y = 20826044427190551819028037513790182040454912231317892359538520323503047694376;
    
    uint256 constant IC7x = 12852933513905544349913141390111140478960840810070338699774469412347219085178;
    uint256 constant IC7y = 4794260939142665884238585919286211094323305626715005704577684255937908163498;
    
    uint256 constant IC8x = 625147900506328379756552131024664054349164367590017873286893760968701340657;
    uint256 constant IC8y = 3577395931807355886276528562270488100558065144420929771280433399120696485409;
    
    uint256 constant IC9x = 19504132086796538232660111748287785529885320837091268279945512806508341612213;
    uint256 constant IC9y = 18283173946273195194848835182458098601431901484000509945909240152765383765487;
    
    uint256 constant IC10x = 20413107987995412398224069567965686706899872581176982273890396890648138787460;
    uint256 constant IC10y = 16853746740976178943197542887124122818368345368738718065666955157239456377027;
    
    uint256 constant IC11x = 17370271477348890088419911222389562081429062022384944999398343952685663536131;
    uint256 constant IC11y = 3551176877381313004781731011797159691034109822241538258464029725279728299700;
    
    uint256 constant IC12x = 11183239260843647339865349985593730438312132409327530866125967032308016646539;
    uint256 constant IC12y = 12898726653063384848444024180467719803044095229901363364827996490005030623066;
    
    uint256 constant IC13x = 20434481045055855193092701687375162406863368306356077333455309491743651231047;
    uint256 constant IC13y = 3900764731182832323096313118426787570586415330378545797374019431039552440213;
    
    uint256 constant IC14x = 18640738391563221816630913018604654304742406257846141045843657249379880695317;
    uint256 constant IC14y = 5036444207935212087212194793808120127451139977893079999975224353428313214279;
    
    uint256 constant IC15x = 21129977166878339920518512671185162709363418416597480939494839810534788266629;
    uint256 constant IC15y = 16374126481247176743211293632897300156016010638153769334596253015972302656525;
    
    uint256 constant IC16x = 17445948789637997449910416362295325778185800252983371143482563916353954124600;
    uint256 constant IC16y = 11575930529513081775229374330084215059141103744796354292329045880130498297113;
    
    uint256 constant IC17x = 12707567265593550124221122752544450877690637793338208231416740266928911759831;
    uint256 constant IC17y = 12134081830400311341073779334344148101998806943970428321356244592856911887115;
    
    uint256 constant IC18x = 4418286117479226790849359969531761017973589489997501818010229321737612002143;
    uint256 constant IC18y = 15642791083157692640690141284434436740329171741117101908087980396281696962612;
    
    uint256 constant IC19x = 9111774392328423270757730122119422019577633203131686160315601183879002258155;
    uint256 constant IC19y = 5425365366803503936341714388237579291619740535161568931620952914976388604788;
    
    uint256 constant IC20x = 21502530118141474471006374423208626644430471935533204174371551153878599736333;
    uint256 constant IC20y = 5709839917040939894470643812057258936917688741463825017297081401124349776917;
    
    uint256 constant IC21x = 19448169471285395490719716766607212117278152698466207419570802150146666710587;
    uint256 constant IC21y = 19463219208973669784597164861074501940918970591270044345200929162706267770955;
    
    uint256 constant IC22x = 6472574547756011348682438761368668829735546879929785259835707835753084956319;
    uint256 constant IC22y = 19492666731119399509558312312113219130535492610358082076015432372685465741197;
    
    uint256 constant IC23x = 6698401874763667539397040400959495307004651966775906262048544043048779095216;
    uint256 constant IC23y = 15917788506825327535551019897201208610645009734182240269483907941668441449497;
    
    uint256 constant IC24x = 306679148685478308708012653834527698168860607289500656171009006508326137248;
    uint256 constant IC24y = 7552246057320407637513798473055052362890392257910385223856128028952957099854;
    
    uint256 constant IC25x = 2475610949149226676313250832155776185873101662689052665248824762980159792943;
    uint256 constant IC25y = 20164201095161589213350447375843811710493144634955789342644676925762718671562;
    
    uint256 constant IC26x = 14072770343727714911415652531844883053180797316756874518414070554159515511373;
    uint256 constant IC26y = 1245175775337322700330853556367544707760134108439361005582071469198616921754;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[26] calldata _pubSignals) public view returns (bool) {
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
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
