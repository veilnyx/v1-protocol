// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {console2} from "forge-std/console2.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {VerifierInfo} from "../libraries/DataTypes.sol";
import {ZTransaction, ZTransactionType, ZTransactionLogic} from "../libraries/ZTransaction.sol";
import {Verifier22} from "../verifiers/Verifier22.sol";

contract Verifier is IVerifier {
    using ZTransactionLogic for ZTransaction;

    uint256 constant ENC_PUB_KEY_X =
        5299619240641551281634865583518297030282874472190772894086521144482721001553;
    uint256 constant ENC_PUB_KEY_Y =
        16950150798460657717958625567821834550301663161624707787222815936182638968203;

    /**
     * @notice Verifier id to Verifier info mapping
     */
    mapping(uint256 => VerifierInfo) public verifiers;

    constructor(uint256[] memory ids, VerifierInfo[] memory vInfos) {
        if (ids.length != vInfos.length) {
            revert BadArguments();
        }

        for (uint256 i = 0; i < ids.length; ) {
            verifiers[ids[i]] = vInfos[i];
            unchecked {
                ++i;
            }
        }
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

        bytes memory vInp = ztx.toVerifierInput(vInfo.selector);
        (bool success, bytes memory result) = vInfo.addr.staticcall(vInp);

        if (!success) {
            revert("Verification call failed");
        }

        return uint8(result[31]) == 1;
    }

    function verifyTransactionProof2(
        ZTransaction memory ztx
    ) public view returns (bool) {
        VerifierInfo memory vInfo = getVerifier(
            ztx.nullifiers.length,
            ztx.commitments.length
        );

        if (vInfo.addr == address(0)) {
            revert("Verifier: verifier not found");
        }

        uint256[2] memory proofA = [ztx.proof[0], ztx.proof[1]];
        uint256[2][2] memory proofB = [
            [ztx.proof[2], ztx.proof[3]],
            [ztx.proof[4], ztx.proof[5]]
        ];
        uint256[2] memory proofC = [ztx.proof[6], ztx.proof[7]];

        bool isValid = Verifier22(vInfo.addr).verifyProof(
            proofA,
            proofB,
            proofC,
            [
                ztx.merkleRoot,
                ztx.hash(),
                ztx.txType == ZTransactionType.DEPOSIT ? 0 : 1,
                ztx.pubAssetIds[0],
                0,
                ztx.pubValues[0],
                0,
                ztx.nullifiers[0],
                ztx.nullifiers[1],
                ztx.commitments[0],
                ztx.commitments[1],
                ztx.ephPubKey[0],
                ztx.ephPubKey[1],
                ENC_PUB_KEY_X,
                ENC_PUB_KEY_Y,
                ztx.encAssets[0],
                ztx.encAssets[1]
            ]
        );

        return isValid;
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
