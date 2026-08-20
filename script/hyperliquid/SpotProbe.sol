// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {HyperCore} from "src/adaptors/hyperliquid/IHyperCore.sol";

/// Minimal probe: does a CONTRACT's spotSend get accepted by Core? A direct
/// spotSend from the admin EOA was rejected with "Action disabled when unified
/// account is active"; this establishes whether contracts hit the same rule.
/// Deliberately sends to a normal address, not a system address, so nothing can
/// be stranded behind a broken token link.
contract SpotProbe {
    function probe(address dest, uint64 token, uint64 weiAmt) external {
        HyperCore.spotSend(dest, token, weiAmt);
    }
}
