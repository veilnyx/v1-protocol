// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseScript} from "../BaseScript.sol";
import {IPool} from "src/interfaces/IPool.sol";

contract RegisterRevoker is BaseScript {
    // Veilnyx Internal Group 3 revoker keys
    // Revoker EVM address (off-chain reference): 0x4E6de297299Da45E45Fb35E081dBE5A58006C8Fe
    uint256 constant REVOKER_X =
        2749704438653731913188138418018248383640313533126118762606204960313160705060;
    uint256 constant REVOKER_Y =
        14954171922332770306296821288711456505467306686450412062256847568323648387209;

    uint256 constant ENC_X =
        8585211455054262025734530102131927858150037756720423682188447718953446140897;
    uint256 constant ENC_Y =
        6678436805882868525395395045499965952852531887623729224842556806569195954800;

    function run() external broadcast {
        string memory name = "Veilnyx Internal Group 3";
        string
            memory description = "A revoker group for decentralized applications, ensuring secure and reliable revocation processes.";
        bytes memory metadata = abi.encode(name, description);

        uint256[2] memory revokerPublicKey = [REVOKER_X, REVOKER_Y];
        uint256[2] memory encryptionPublicKey = [ENC_X, ENC_Y];

        IPool(address(0xef7585dFCdB91b0dc9fC9f920c4fb72bfb7B3E1f))
            .registerRevoker(revokerPublicKey, encryptionPublicKey, metadata);
    }
}
