// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseScript} from "../BaseScript.sol";
import {IPool} from "src/interfaces/IPool.sol";

contract RegisterRevoker is BaseScript {
    // DECOM_GRP revoker keys
    uint256 constant REVOKER_X =
        20166730020419159052286555107141035920946760385383107576039955225567455300207;
    uint256 constant REVOKER_Y =
        18439266136563662170719450990945300828423393702749802977743662490195521743390;

    uint256 constant ENC_X =
        1415297768191015876969734831367396850794970386289866514910293184189216114711;
    uint256 constant ENC_Y =
        10435528812585515475307388160094137747296379532862976260464438917842987448252;

    function run() external broadcast {
        string memory name = "Veilnyx Internal Group 2";
        string
            memory description = "A revoker group for decentralized applications, ensuring secure and reliable revocation processes.";
        bytes memory metadata = abi.encode(name, description);

        uint256[2] memory revokerPublicKey = [REVOKER_X, REVOKER_Y];
        uint256[2] memory encryptionPublicKey = [ENC_X, ENC_Y];

        IPool(address(0xef7585dFCdB91b0dc9fC9f920c4fb72bfb7B3E1f))
            .registerRevoker(revokerPublicKey, encryptionPublicKey, metadata);
    }
}
