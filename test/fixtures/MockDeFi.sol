// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockDeFi is ERC20 {
    address public immutable tokenAddress;

    constructor(address wTokenAddress_) ERC20("MockDeFiToken", "MTKN") {
        tokenAddress = wTokenAddress_;
    }

    function depositToken(address account, uint256 amount) external {
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        _mint(account, amount);
    }

    function withdrawToken(address account, uint256 amount) external {
        _burn(account, amount);
        IERC20(tokenAddress).transfer(account, amount);
    }
}
