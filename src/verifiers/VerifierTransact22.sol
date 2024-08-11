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

contract VerifierTransact22 {
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
        1839278810780863903433023246119313866896716775020418450268971613541881422763;
    uint256 constant deltax2 =
        14954890420793524850216365255487650035856410508796459563499564746371438365826;
    uint256 constant deltay1 =
        3313553487485094540160141212877502766461104497358959976519369569949745656309;
    uint256 constant deltay2 =
        5764798946184466409390500731572150361835092101548488811910327291123256111820;

    uint256 constant IC0x =
        13997399856152554591418407172432641771082710788276855991169368353880075991578;
    uint256 constant IC0y =
        13694110465974523785101722063345777970050826654138449211380403847775439140777;

    uint256 constant IC1x =
        8412389553066789711071599455075167952293716043909047301640321738998492097509;
    uint256 constant IC1y =
        6665599650830238268813258959851596000306324295349620318001386122878520680555;

    uint256 constant IC2x =
        350241641249916375206670535475885848909133482457113997495811468703570645695;
    uint256 constant IC2y =
        21230997112585490188337764479943620492216113396218793935299554369052380222880;

    uint256 constant IC3x =
        6035658907421726387070355600842199685423225661566904609755939806029642144107;
    uint256 constant IC3y =
        603723345126822171328448266526748438572549542634765567455947781593376701996;

    uint256 constant IC4x =
        12118387088352597103992760545102071279032144448444166604905774495623090449341;
    uint256 constant IC4y =
        4507512688804017604184741527378698044363505491432586035093579596773850775715;

    uint256 constant IC5x =
        21096871272805423875997814709695075573603990587628427173150396170842113453274;
    uint256 constant IC5y =
        20746037776511785704142345447535313872702904452143225931507371772508352556688;

    uint256 constant IC6x =
        20619701948781932227387351667722717547507726683536931361336932404745735952077;
    uint256 constant IC6y =
        19513654721309759928823704988955749561576211834223583969019880501458717132546;

    uint256 constant IC7x =
        6631733803101954129332699667160498970240289984194252705877431689720124500431;
    uint256 constant IC7y =
        12280650226430112962674990888897888120679628541255389015230084934211843575257;

    uint256 constant IC8x =
        14423305731173856693992155632946091194251295473373092802944121733012558179763;
    uint256 constant IC8y =
        16669404875299251993663965499819915952804550955641984892727971879152471230752;

    uint256 constant IC9x =
        9033189609502702069694354625197656360875289997984025609911487633903078274301;
    uint256 constant IC9y =
        20288273648392753261065147457415225927998483094472568515414765850034862360581;

    uint256 constant IC10x =
        4428588468894782709634225717406527917374137845970982458680284115725689053248;
    uint256 constant IC10y =
        10701642546516881964212852296792261426699396402702482733229068267550247044252;

    uint256 constant IC11x =
        10485341707447596189596825259016230966884586143242655010083725232784357146541;
    uint256 constant IC11y =
        21481470026437526985652066708209210027181949985015376880159496801835648435037;

    uint256 constant IC12x =
        4257248116129529072530184538235071045722623835137607184777038535773836660632;
    uint256 constant IC12y =
        14482483738696162711315690362990607885718793861681297068905617160762627069827;

    uint256 constant IC13x =
        19277150071667223970548281680887336817399392786592695021949952282104220785233;
    uint256 constant IC13y =
        11764083736435145762082585351416407185685579411680837081137230082271378647850;

    uint256 constant IC14x =
        20775881096609504062253082517495340589355831918268829069355453717767252842873;
    uint256 constant IC14y =
        9833958351425872703484956932831073284582129007237649697083748452880906486440;

    uint256 constant IC15x =
        3020890532443720273504571530485017227314442433782936450399976548521995559024;
    uint256 constant IC15y =
        12138877786585823814649634479644269239565312006099912052757891797671384941455;

    uint256 constant IC16x =
        11611298192797788337908312017558002255623034863993311945469983020246561739442;
    uint256 constant IC16y =
        6365526996139013950034309600649985351669848185007046786875339934618477306693;

    uint256 constant IC17x =
        14563642652129253375459629506499012709071265583239812001270684192100238533096;
    uint256 constant IC17y =
        10667111790621334213702238270434641103745627159612610692189929286363880823761;

    uint256 constant IC18x =
        12989530114931818346742316486096099407460070284246790665068288119579228769729;
    uint256 constant IC18y =
        14643529226265079344369290233696127997267907480395141867089251862517788494887;

    uint256 constant IC19x =
        19102914969421845918399554704527280611307372226445776646878733297281041808445;
    uint256 constant IC19y =
        6736638561861493561080652866169324246013063914621289153962803993240633810549;

    uint256 constant IC20x =
        13136598476101192158372144497062334872159546557302659759826823513691089840696;
    uint256 constant IC20y =
        15853668466122631341247842950267637973870663114265068843216596333100503945032;

    uint256 constant IC21x =
        20477306634701916186898309748298265364397656359682203836427944683573215074657;
    uint256 constant IC21y =
        9035005076296783563729473432493719523412271481301252508708951540433709937148;

    uint256 constant IC22x =
        20900000068359346639270282824418384301419975708215711751453375700363842459005;
    uint256 constant IC22y =
        20350553370147060104938535584077148033292908159092507282483589000123759009595;

    uint256 constant IC23x =
        16847841614588965990711952985443592168766421855145160817651799087526618987659;
    uint256 constant IC23y =
        18105620986343602184238896869343382944473078460527923803424171860376099163563;

    uint256 constant IC24x =
        7291109561238030508574110888349499362786364994270863733545141676056897039748;
    uint256 constant IC24y =
        16044948484867130815156524250958846389884927371011138198317564125113546344443;

    uint256 constant IC25x =
        2726153866244379890263914641500888534847405502021330251869810577805547613970;
    uint256 constant IC25y =
        5647483337882983112930507849046912318914945317506917504048876515078097865066;

    uint256 constant IC26x =
        4946302373677723423204563698063088662425932745674147700122837478634238181252;
    uint256 constant IC26y =
        15890090730608704684743852639142011390958863926285011698977606962692648135489;

    uint256 constant IC27x =
        15487313467674411075830448715409943735999306503848516073945665379156252300286;
    uint256 constant IC27y =
        11020868081307305956371379729587299040162658045500625128518241134602834997626;

    uint256 constant IC28x =
        1482990754159022353271203490000212489394219820189145801331455621002917186880;
    uint256 constant IC28y =
        18163118538621333390868447730613907395049349519817640708544830905046109875991;

    uint256 constant IC29x =
        11857674057205698467870582637803318515935958165249880783853511276781981000676;
    uint256 constant IC29y =
        21279501043023754323705962655355907112924847513885296624842816010079052881838;

    uint256 constant IC30x =
        1428836488347836171101562397565548072631252439986200374111034202124746254623;
    uint256 constant IC30y =
        8824466890519490953319183372749514958033277144739736320436812620793744409021;

    uint256 constant IC31x =
        2949897757556408429304363782374164051433770246994394296431359541063056235804;
    uint256 constant IC31y =
        16776172387439543334322140853369696027386916922756690555947133210689972836245;

    uint256 constant IC32x =
        18932719454724847344960349221552070033492622690754993975933484116220147251236;
    uint256 constant IC32y =
        12972494179905415033348715258279043307479152864303327819518601141467154208170;

    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[32] calldata _pubSignals
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

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
            return(0, 0x20)
        }
    }
}
