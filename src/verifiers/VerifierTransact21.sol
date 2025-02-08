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
        7258576706812489377564958470241205676575043231469166262208835305545469773864;
    uint256 constant deltax2 =
        10110550700909253624375851265466828820122312851418528456492150517511754909057;
    uint256 constant deltay1 =
        9631564275349309213033936447373557096250569527976135986606640341076397842138;
    uint256 constant deltay2 =
        5293133228041016174989357777946389471743880330310359952844344642406522557006;

    uint256 constant IC0x =
        14456206523921709190538234475708996025054124990077334799325723479481849787785;
    uint256 constant IC0y =
        6113733098443683966261025817927734772774799785356856250645646050608729591627;

    uint256 constant IC1x =
        19498176065743009056455133196203488406550087677428756825367941996840873074459;
    uint256 constant IC1y =
        17445568718922582190680040401409251706417471604386430974698399242605980150350;

    uint256 constant IC2x =
        18643428931948600322099894944762292290780132012603499483257245811691050713508;
    uint256 constant IC2y =
        21174589927183606023214970748450690978748013331441219549040213225544416251535;

    uint256 constant IC3x =
        13851740617162598047403490491816882407781111527622256708122581902763582361238;
    uint256 constant IC3y =
        11119707388896680817097110748747349719526282455091157819946082413479117822403;

    uint256 constant IC4x =
        18353293495101622967579357699748798537853014629880601162565716500690087685716;
    uint256 constant IC4y =
        725314796643522404453587777016218294197385596726130493992586163627836477330;

    uint256 constant IC5x =
        11837912752129370437626723310566393804879861477451570437778911182047079937165;
    uint256 constant IC5y =
        3054901221956425140128745068444066879649558100878798542156874877494293001655;

    uint256 constant IC6x =
        21400267566555799073169427724243622961489677410327100833805133157325311377794;
    uint256 constant IC6y =
        9331198450200984572032281314706294633005807683132263381390022429204840125814;

    uint256 constant IC7x =
        8004173584775256622707327943164666737986286502871413921659154997177704071008;
    uint256 constant IC7y =
        3182095863535883262130332772796355804142024621405201860341134941248556086628;

    uint256 constant IC8x =
        9870237636792303680202331341090396270692870817029451929166064909256038426882;
    uint256 constant IC8y =
        6593199796293248243068013598120176464578283711581346363362018986389724794103;

    uint256 constant IC9x =
        19474717504522132750098197198890855238386316063744877648832659403966060716445;
    uint256 constant IC9y =
        1188701504077193390970696109655643090874563635521367501678518819307157241540;

    uint256 constant IC10x =
        14923784342093916191826702783310829672998466109477072881387053744231960279094;
    uint256 constant IC10y =
        7889282803086205731899227010370368451432550411053396134951205912314708695451;

    uint256 constant IC11x =
        18239706594428437229309351651060857645307315037680889863303280032917965102296;
    uint256 constant IC11y =
        11808543563177888672502929145036703260943921006535784714380647731095586890147;

    uint256 constant IC12x =
        5182023797360547992302503576211305292004556114270086958764809067336799486905;
    uint256 constant IC12y =
        17631567782955267557098074488475297158455202616870632126495956312658029042334;

    uint256 constant IC13x =
        17557742962397508311049495051389323549043488567466638348586331025260404291129;
    uint256 constant IC13y =
        19834901305112674117104968659618719901931254096039212477923665268882073833729;

    uint256 constant IC14x =
        2299205391154245773512113578168964673683472302017583863345540829389499998228;
    uint256 constant IC14y =
        7107650483420479875542655873516630882545105682819449585720657225906127457742;

    uint256 constant IC15x =
        3577632946076437105801573609103007948436983050965154207120366718478383816567;
    uint256 constant IC15y =
        19626971701220758561969725736662188939387625110473163927306286387482930236255;

    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[15] calldata _pubSignals
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

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
            return(0, 0x20)
        }
    }
}
