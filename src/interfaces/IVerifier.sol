// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ZTransaction, RevokerData} from "../libraries/ZTransaction.sol";

interface IVerifier {
    error BadArguments();

    function verifyTransactionProof(
        ZTransaction memory ztx,
        RevokerData memory cKeys
    ) external view returns (bool);

    function getVerifierId(
        uint256 nIns,
        uint256 nOuts
    ) external pure returns (uint256 id);
}
