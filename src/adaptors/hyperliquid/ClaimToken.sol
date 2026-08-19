// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title ClaimToken - a transferable receipt for a queued vault redemption
/// @notice Minted when a redemption cannot be paid from the vault's idle buffer.
/// @dev Deliberately ONE token per vault rather than one per batch or epoch.
///      Claims settle pro rata against a shared pot, so every claim is fungible
///      whatever unwind funded it. That matters because each distinct token has
///      to be registered as a Pool asset by `addAssets` (owner-only, and it needs
///      a price feed), and a note is a bearer commitment that stays redeemable
///      forever — so a per-epoch token could never be retired and the registry
///      would grow without bound.
///
///      Denominated in the vault's ASSET units, being the value owed at the time
///      the redemption was queued.
contract ClaimToken is ERC20 {
    address public immutable vault;
    uint8 private immutable _decimals;

    error OnlyVault();

    constructor(string memory name_, string memory symbol_, uint8 decimals_)
        ERC20(name_, symbol_)
    {
        vault = msg.sender;
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    modifier onlyVault() {
        if (msg.sender != vault) revert OnlyVault();
        _;
    }

    function mint(address to, uint256 amount) external onlyVault {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyVault {
        _burn(from, amount);
    }
}
