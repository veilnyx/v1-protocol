// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract MockERC20ForReentrancyTest is ERC20, Ownable {
    uint8 private immutable precision;

    constructor(
        address initialOwner,
        uint8 decimals_
    ) ERC20("Token", "TKN") Ownable(initialOwner) {
        precision = decimals_;
    }
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return precision;
    }

    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        super.transfer(to, amount);

        /// @dev This is added to enable reentrancy attack for ERC20 tokens for testing purposes
        (bool success, ) = to.call(
            abi.encodeWithSignature("onTokenTransfer()")
        );
        return success;
    }
}