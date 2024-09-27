// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {AdaptorHandler} from "src/core/AdaptorHandler.sol";
import {console2} from "forge-std/console2.sol";
import {Pool} from "src/core/Pool.sol";
import {Payload} from "src/adaptors/curveNG/CurveNGAdaptor.sol";
struct AddressInfo {
    address addr;
    string description;
    uint256 version;
    uint256 last_modified;
}

/// @dev Static script that generates the `targetPayload` bytes for convert txns or any other purpose (if required).
/// @dev The components to be encoded are static and should be updated as required.
contract GenerateAdaptorPayload is Script {
    function run() external {
        /**
        bytes memory payload = bytes(
            "0xb74cba1c000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000100060000000000000000000000000000000000000000000000000000000000010007000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000009896800000000000000000000000000000000000000000000000008ac7230489e8000000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000096266f43ceddfeff150dc4997350a850f0d7067500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000"
        );

        Payload memory decodedPayload = abi.decode(payload, (Payload));
        console2.log("Adaptor Address: %s", decodedPayload.curvePool);
         */
        console2.logBytes(
            abi.encode(
                uint8(1),
                address(0x92A14518434a46E88CB4C3918AD33B3344099E02)
            )
        );

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
