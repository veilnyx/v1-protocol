// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

library ArrayUtils {
    function concat(
        uint256[] memory a,
        uint256[] memory b
    ) internal pure returns (uint256[] memory result) {
        result = new uint256[](a.length + b.length);
        for (uint256 i = 0; i < a.length; ) {
            result[i] = a[i];
            unchecked {
                ++i;
            }
        }
        for (uint256 i = 0; i < b.length; ) {
            result[a.length + i] = b[i];
            unchecked {
                ++i;
            }
        }
    }
}
