// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {AdaptorHandler} from "src/core/AdaptorHandler.sol";
import {console2} from "forge-std/console2.sol";
import {Pool} from "src/core/Pool.sol";
import {IStableSwapFactory} from "src/adaptors/curveNG/IStableSwapFactory.sol";
import {ICurvePool} from "src/adaptors/curveNG/ICurvePool.sol";
struct AddressInfo {
    address addr;
    string description;
    uint256 version;
    uint256 last_modified;
}

interface IPoseidonT3 {
    function poseidon(uint256[2] calldata inValues) external returns (uint256);
}

interface IPoseidonT4 {
    function poseidon(uint256[3] calldata inValues) external returns (uint256);
}

/// @dev Static script that generates the `targetPayload` bytes for convert txns or any other purpose (if required).
/// @dev The components to be encoded are static and should be updated as required.
contract GenerateAdaptorPayload is Script {
    function run() external {
        address poseidonT3 = 0x9122b25a94712dEDDe5D32cAA38A7e9e86D9337c;
        address poseidonT4 = 0x8eB83D9eDe9F044C3e004DcB71cd0DF0B1413bcB;
        uint256 codeSizeT3;
        uint256 codeSizeT4;
        assembly {
            codeSizeT3 := extcodesize(poseidonT3)
            codeSizeT4 := extcodesize(poseidonT4)
        }
        console2.log("Code size of poseidonT3: %s", codeSizeT3);
        console2.log("Code size of poseidonT4: %s", codeSizeT4);

        uint256 returnT3 = IPoseidonT3(poseidonT3).poseidon(
            [uint256(65538), uint256(123)]
        );

        uint256 returnT4 = IPoseidonT4(poseidonT4).poseidon(
            [uint256(43434443423432423), uint256(820382083), uint256(3480384)]
        );

        console2.log("PoseidonT3 returns:", returnT3);
        console2.log("PoseidonT4 returns:", returnT4);

        // getting StableSwap Factory addr
        /**
        address curveAddressRegistry = 0x5ffe7FB82894076ECB99A30D6A32e969e6e35E98;
        (, bytes memory addressInfo) = curveAddressRegistry.call(
            abi.encodeWithSignature("get_id_info(uint256)", 12) // 12 is the id for StableSwapFactory
        );

        AddressInfo memory addrInfo = abi.decode(addressInfo, (AddressInfo));
        console.log("Factory Address: %s", addrInfo.addr);
        console.log("Description: %s", addrInfo.description);
        */

        // getting swap pool addr
        // address stableSwapFactory = /* addrInfo.addr; */ 0x6A8cbed756804B16E05E741eDaBd5cB544AE21bf;
        // address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        // address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        // address pool = IStableSwapFactory(stableSwapFactory)
        //     .find_pool_for_coins(USDC, USDT, 0);
        // console2.log("USDC-USDT Pool: %s");
        // console2.logAddress(pool); // 0x31b46c84e4fb0704dE69DBf4B054b5Cb81Aa3736

        // Pool ops
        // address pool = 0xC55Bcf5370e67fbA281E2aac8937B4Ea71E7785F;
        // uint256[] memory depositAmounts = new uint256[](2);
        // depositAmounts[0] = 10 ** 18;
        // depositAmounts[1] = 10 ** 18;

        // (, bytes memory lpToken) = pool.staticcall(
        //     abi.encodeWithSignature(
        //         "calc_token_amount(uint256[],bool)",
        //         depositAmounts,
        //         true
        //     )
        // );
        // uint256 lpTokenAmount = abi.decode(lpToken, (uint256));

        // uint256 lpTokenAmount = ICurvePool(pool).calc_token_amount(
        //     depositAmounts,
        //     true
        // );
        // console2.log("LP Token Amount: %s", lpTokenAmount);
    }
}
