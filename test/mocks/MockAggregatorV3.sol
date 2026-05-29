// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @dev Minimal Chainlink AggregatorV3Interface mock for testing.
///      All fields are mutable so individual tests can set staleness or invalid prices.
contract MockAggregatorV3 is AggregatorV3Interface {
    int256 private _price;
    uint8 private _feedDecimals;
    uint256 private _updatedAt;

    constructor(int256 price_, uint8 decimals_) {
        _price = price_;
        _feedDecimals = decimals_;
        _updatedAt = block.timestamp;
    }

    /// @notice Update the price returned by latestRoundData. Also refreshes updatedAt.
    function setPrice(int256 price_) external {
        _price = price_;
        _updatedAt = block.timestamp;
    }

    /// @notice Manually set updatedAt without changing the price (used to simulate staleness).
    function setUpdatedAt(uint256 updatedAt_) external {
        _updatedAt = updatedAt_;
    }

    // ---- AggregatorV3Interface ----

    function decimals() external view override returns (uint8) {
        return _feedDecimals;
    }

    function description() external pure override returns (string memory) {
        return "MockAggregatorV3";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId, _price, _updatedAt, _updatedAt, _roundId);
    }

    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (1, _price, _updatedAt, _updatedAt, 1);
    }
}
