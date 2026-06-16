// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseScript} from "../BaseScript.sol";
import {IPool} from "src/interfaces/IPool.sol";

contract RegisterRevoker is BaseScript {
    // DECOM_GRP revoker keys
    uint256 constant REVOKER_X =
        16481715428292641414090788527523849067643249410247738079187244265915987843343;
    uint256 constant REVOKER_Y =
        11269818143449338126502809473506237318599117872770962832972091717245533415863;

    uint256 constant ENC_X =
        4321126899491414688643883332441835950049136153055686387487184312703532041125;
    uint256 constant ENC_Y =
        16613246411751272682575178888266382768090179459423720344501284773500017351901;

    function run() external broadcast {
        string memory name = "Veilnyx Internal Group";
        string
            memory description = "A revoker group for decentralized applications, ensuring secure and reliable revocation processes.";
        bytes memory metadata = abi.encode(name, description);

        uint256[2] memory revokerPublicKey = [REVOKER_X, REVOKER_Y];
        uint256[2] memory encryptionPublicKey = [ENC_X, ENC_Y];

        IPool(address(0xd971f6C35e7a71f25d912CD652bA182ca0778f5b))
            .registerRevoker(revokerPublicKey, encryptionPublicKey, metadata);
    }
}
