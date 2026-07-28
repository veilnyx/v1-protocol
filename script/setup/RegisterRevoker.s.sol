// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseScript} from "../BaseScript.sol";
import {IPool} from "src/interfaces/IPool.sol";

contract RegisterRevoker is BaseScript {
    // Veilnyx Internal Group 3 revoker keys
    // Revoker EVM address (off-chain reference): 0x4E6de297299Da45E45Fb35E081dBE5A58006C8Fe
    uint256 constant REVOKER_X =
        19670944452806042525069794818829249411975318219685565589987272359777840230253;
    uint256 constant REVOKER_Y =
        5705876210490413354479267746861793442476799294826521514340924438581325830039;

    uint256 constant ENC_X =
        8415733266590874906051569398859887253801673499116319370506942542327247131378;
    uint256 constant ENC_Y =
        4303763666990812745724909494561603880133773663501392405214554054831058921986;

    address constant poolAddress = ;

    function run() external broadcast {
        string memory name = "Veilnyx Security";
        string
            memory description = "A compliance group for dApps, ensuring private yet compliant revocation processes.";
        bytes memory metadata = abi.encode(name, description);

        uint256[2] memory revokerPublicKey = [REVOKER_X, REVOKER_Y];
        uint256[2] memory encryptionPublicKey = [ENC_X, ENC_Y];

        IPool(poolAddress)
            .registerRevoker(revokerPublicKey, encryptionPublicKey, metadata);
    }
}
