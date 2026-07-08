// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

interface INebraUpa {
    function isProofVerified(bytes32 proofId) external view returns (bool);
}
