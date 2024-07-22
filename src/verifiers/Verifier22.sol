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

contract Verifier22 {
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
        18285724398660680787844927286330017937755398695047541742042297184948617622106;
    uint256 constant deltax2 =
        6627191447394868566642656350483124898845527248624776557747123336603577122584;
    uint256 constant deltay1 =
        6244125240184461493681045703941885297664139629279225727356409714365798249639;
    uint256 constant deltay2 =
        8731000863317707952620190817078093895802281694010117368007612691223658054163;

    uint256 constant IC0x =
        7260567290692250919466575687589297007120166106661573641220152554867223114433;
    uint256 constant IC0y =
        18256305064679985820413129340788971610595070952718504334262335656264584936859;

    uint256 constant IC1x =
        980664067169383229597301697560447266478223996387177417543236141830268220898;
    uint256 constant IC1y =
        6179584272378907700574730503337681462679018612787789772243878975638582451002;

    uint256 constant IC2x =
        11303378798933050233609420605274994420045798507177423544062683081179386915737;
    uint256 constant IC2y =
        15315023455911202686715182588825477360735538018973052462290894802574153863085;

    uint256 constant IC3x =
        14491721463916924242805942701508542214487808662552706748121228855547698214732;
    uint256 constant IC3y =
        3099508668335702884635063299596610624763440465589777979476008238152182039291;

    uint256 constant IC4x =
        17309860953714784108135598122952067533144966854601008242764122687123086591709;
    uint256 constant IC4y =
        19960605112926131900397394746119595998118489206792133126508032267428257306080;

    uint256 constant IC5x =
        16753331530752986353185636555047299127720836666234048754857862368328834401000;
    uint256 constant IC5y =
        15310118636233288313580989234638691252287737810902560903587089394468616582563;

    uint256 constant IC6x =
        7456477637915101113579077078437276497481888117859985423036597237546174634883;
    uint256 constant IC6y =
        12951089148615246226843447743163635517584863861394096213370846711020317934393;

    uint256 constant IC7x =
        9149456048036817381235031555455243690765973968175217505994217477205532036234;
    uint256 constant IC7y =
        10221407961418598066451289775735234444982512423111015893945649493514222657632;

    uint256 constant IC8x =
        9994014510075477304722564087465578814568099352878810668014972602172875717771;
    uint256 constant IC8y =
        20140266817810337873007414876409327044053577696556628890065966409917695011066;

    uint256 constant IC9x =
        2229178010914659436753630406645865240041061255314493986105828717024235585413;
    uint256 constant IC9y =
        20682622602719557530061525137189557339033984166287301309160979165402433475735;

    uint256 constant IC10x =
        20146975394798206106026184705126762973112046568881832139990885788194163453397;
    uint256 constant IC10y =
        14365022216621211337932342464607931546752757712050703056524874242830036800845;

    uint256 constant IC11x =
        11444940144016680793375555156954545192908696406503026474312035649573407528718;
    uint256 constant IC11y =
        3863011592305233348610553285109127301938344746641254689451654944900694184203;

    uint256 constant IC12x =
        19673518175148208860680456799096656403684944920223371373275807011400721864072;
    uint256 constant IC12y =
        17040675012101522371237785476247606111595098514619549687262265134954261057061;

    uint256 constant IC13x =
        18319987141886394116453108212555606722864892003048165738255308393907657962058;
    uint256 constant IC13y =
        838997099775073138330818598320775196278768428002624879094729113231439975261;

    uint256 constant IC14x =
        7280454409359669946362883703719468677483693477396375974254763262890802993414;
    uint256 constant IC14y =
        3201674253800553623004607039262597524404560931455108900005934813144296253100;

    uint256 constant IC15x =
        13727442465561549579894851711987103481332017553761567361039810322898020002571;
    uint256 constant IC15y =
        20565632969288837153420347328566453211415159503329545046802179694942191877217;

    uint256 constant IC16x =
        18603983490499401580143549073320071125226642321642753147563826963982571623243;
    uint256 constant IC16y =
        14430758383637698382182021270330411645793297121552279179842235554039143306181;

    uint256 constant IC17x =
        5702217414854200516862949731281467683639984857107393657260414365348300585955;
    uint256 constant IC17y =
        12498147784366432835905913488898249012787044066037825882394864154386450886273;

    uint256 constant IC18x =
        10487385590919261129328186142902021407342984414496577443605629413139581281377;
    uint256 constant IC18y =
        6437904248615738858053646972382929924860057126335964038559845780596301727103;

    uint256 constant IC19x =
        12784519830866439554948350615473321805266696790916795643120598921878449253817;
    uint256 constant IC19y =
        13679414029818710422132051032974232103248536755796015255980887319972749375898;

    uint256 constant IC20x =
        16718635974025836707305083941040843875106871870595423533132630129337575129410;
    uint256 constant IC20y =
        20377818932264587439901533540817880570654283598382510904056257836648115437152;

    uint256 constant IC21x =
        18885632561532083011095676604527352068470087515980172802923271719284440002980;
    uint256 constant IC21y =
        1228019096367312511679089356742605030059147524975764186179407785160309210472;

    uint256 constant IC22x =
        10884815647640077842837559206683584393730915966048558015070798970606048145710;
    uint256 constant IC22y =
        15303718733020910721194197922542143818255363431180377212118725842996719735304;

    uint256 constant IC23x =
        4057477345306926864416765282776801417236121202763241700347773033424524453176;
    uint256 constant IC23y =
        20221279945567417576292479204544171121739798490408655037759484163347833076065;

    uint256 constant IC24x =
        7160991899605615449336011508161558198152137118801519026872942305997846922777;
    uint256 constant IC24y =
        19571728507783024916344016946705228165962095177877218286985957611987632521889;

    uint256 constant IC25x =
        2726243914984475486753779329258689552465273709992356858687418474742003318207;
    uint256 constant IC25y =
        3807321604209192513155106755431729218677310667507599698998348277107546979643;

    uint256 constant IC26x =
        20638258013833822824556756451999732224125948107221263333207443793980837125926;
    uint256 constant IC26y =
        17176580953506828641727976900012727599730447080227456826440767665425464426798;

    uint256 constant IC27x =
        18278154264981861954124132375391901959934527980115421670828706290437212684192;
    uint256 constant IC27y =
        7846835095829879253528882975248398488233618295219148735594314098620662487484;

    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[27] calldata _pubSignals
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

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
            return(0, 0x20)
        }
    }
}
