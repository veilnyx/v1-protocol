// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ZTransaction, RevokerData} from "../libraries/ZTransaction.sol";

interface IVerifier {
    error BadArguments();

    function verifyTransactionProof(
        uint16 vId,
        bytes memory vInp
    ) external view returns (bool);

    function verifyAddressProof(bytes memory vInp) external view returns (bool);

    function getTransactionVerifierId(
        uint256 nIns,
        uint256 nOuts
    ) external pure returns (uint16 id);
}
