// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ZTransaction} from "../libraries/ZTransaction.sol";

interface IVerifier {
    error BadArguments();

    function getRevokerPublicKey() external view returns (uint256, uint256);

    function getEncryptionPublicKey() external view returns (uint256, uint256);

    function verifyTransactionProof(
        ZTransaction memory ztx
    ) external view returns (bool);

    function getVerifierId(
        uint256 nIns,
        uint256 nOuts
    ) external pure returns (uint256 id);
}
