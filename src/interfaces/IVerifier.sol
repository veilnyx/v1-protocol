// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ShieldedTransaction, RevokerData} from "../libraries/ShieldedTransaction.sol";

interface IVerifier {
    error BadArguments(uint256 nIns, uint256 nOuts);
    error VerifierIdOverflow(uint256 computedVerifierId);

    function verifyTransactionProof(
        uint16 verifierId,
        bytes calldata vInputs
    ) external view returns (bool);

    function verifyAddressProof(
        bytes calldata vInputs
    ) external view returns (bool);

    function verifyTreeUpdateProof(
        bytes calldata vInputs
    ) external view returns (bool);

    function getTransactionVerifierId(
        uint256 nIns,
        uint256 nOuts
    ) external pure returns (uint16 id);
}
