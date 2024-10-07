// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.24;

interface IStaticATokenFactory {
    function getStaticAToken(
        address underlyingAsset
    ) external view returns (address);
}
