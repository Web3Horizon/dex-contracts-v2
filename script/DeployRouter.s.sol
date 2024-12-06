// // SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";

import {DexerV2Router} from "src/DexerV2Router.sol";

contract DeployRouter is Script {
    function run(address factoryAddress) external returns (DexerV2Router) {
        vm.startBroadcast();

        DexerV2Router dexerV2Router = new DexerV2Router(factoryAddress);

        vm.stopBroadcast();

        console.log("DexerV2Router deployed at: ", address(dexerV2Router));
        return dexerV2Router;
    }
}
