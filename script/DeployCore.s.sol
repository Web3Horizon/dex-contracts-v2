// // SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";

import {DexerV2Factory} from "src/DexerV2Factory.sol";
import {DexerV2Pair} from "src/DexerV2Pair.sol";
import {MockERC20} from "src/mocks/MockERC20.sol";

contract DeployCore is Script {
    function run() external returns (DexerV2Factory) {
        vm.startBroadcast();

        if (block.chainid == 31337) {
            MockERC20 tokenA = new MockERC20("TokenA", "TKNA");
            MockERC20 tokenB = new MockERC20("TokenB", "TKNB");

            tokenA.mint(msg.sender, 1000 ether);
            tokenB.mint(msg.sender, 1000 ether);

            console.log("Token A:", address(tokenA));
            console.log("Token B:", address(tokenB));
        }

        DexerV2Factory dexerV2Factory = new DexerV2Factory();

        vm.stopBroadcast();

        return dexerV2Factory;
    }
}
