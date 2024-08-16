// SPDX-License-Identifier: MTI
pragma solidity ^0.8.24;

import {IVerifier} from "src/interfaces/IVerifier.sol";

contract MockVerifier is IVerifier {
    bool internal _res = true;

    function setResult(bool res) public {
        _res = res;
    }

    function verifyTransactionProof(
        uint16,
        bytes memory
    ) external view returns (bool) {
        return _res;
    }

    function verifyAddressProof(bytes memory) external view returns (bool) {
        return _res;
    }

    function verifyTreeUpdateProof(
        bytes calldata
    ) external view returns (bool) {
        return _res;
    }

    function getTransactionVerifierId(
        uint256,
        uint256
    ) external pure returns (uint16) {
        revert("Not implemented");
    }
}
