// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IVerifier} from "../interfaces/IVerifier.sol";
import {VerifierInfo} from "../libraries/DataTypes.sol";
import {ZTransaction, ZTransactionType, ZTransactionLogic} from "../libraries/ZTransaction.sol";

contract Verifier is IVerifier {
    using ZTransactionLogic for ZTransaction;

    uint256 public immutable REVOKER_PUBLIC_KEY_X;
    uint256 public immutable REVOKER_PUBLIC_KEY_Y;

    uint256 public immutable ENCRYPTION_PUBLIC_KEY_X;
    uint256 public immutable ENCRYPTION_PUBLIC_KEY_Y;

    /**
     * @notice Verifier id to Verifier info mapping
     */
    mapping(uint256 => VerifierInfo) public verifiers;

    constructor(
        VerifierInfo[] memory vInfos,
        uint256[2] memory revokerPublicKey,
        uint256[2] memory encryptionPublicKey
    ) {
        uint256 len = vInfos.length;
        for (uint256 i = 0; i < len; ) {
            verifiers[vInfos[i].id] = vInfos[i];
            unchecked {
                ++i;
            }
        }

        REVOKER_PUBLIC_KEY_X = revokerPublicKey[0];
        REVOKER_PUBLIC_KEY_Y = revokerPublicKey[1];

        ENCRYPTION_PUBLIC_KEY_X = encryptionPublicKey[0];
        ENCRYPTION_PUBLIC_KEY_Y = encryptionPublicKey[1];
    }

    function getRevokerPublicKey() public view returns (uint256[2] memory) {
        return [REVOKER_PUBLIC_KEY_X, REVOKER_PUBLIC_KEY_Y];
    }

    function getEncryptionPublicKey() public view returns (uint256[2] memory) {
        return [ENCRYPTION_PUBLIC_KEY_X, ENCRYPTION_PUBLIC_KEY_Y];
    }

    function verifyTransactionProof(
        ZTransaction memory ztx
    ) public view returns (bool) {
        VerifierInfo memory vInfo = getVerifier(
            ztx.nullifiers.length,
            ztx.commitments.length
        );

        if (vInfo.addr == address(0)) {
            revert("Verifier: verifier not found");
        }

        bytes memory vInp = ztx.toVerifierInput(
            vInfo.selector,
            getEncryptionPublicKey()
        );
        (bool success, bytes memory result) = vInfo.addr.staticcall(vInp);

        if (!success) {
            revert("Verification call failed");
        }

        return uint8(result[31]) == 1;
    }

    function getVerifier(
        uint256 nIns,
        uint256 nOuts
    ) public view returns (VerifierInfo memory) {
        return verifiers[getVerifierId(nIns, nOuts)];
    }

    function getVerifierId(
        uint256 nIns,
        uint256 nOuts
    ) public pure returns (uint256 id) {
        return nIns * 10 + nOuts;
    }
}
