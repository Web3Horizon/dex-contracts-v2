// // SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";

import {MockERC20} from "src/mocks/MockERC20.sol";

contract DeployTokens is Script {
    function run() external {
        vm.startBroadcast();

        MockERC20 gold = new MockERC20("GOLD", "GLD");
        gold.mint(msg.sender, 1000);
        console.log(address(gold));
        MockERC20 silver = new MockERC20("SILVER", "SLV");
        silver.mint(msg.sender, 1000);
        console.log(address(silver));
        MockERC20 platinum = new MockERC20("PLATINUM", "PLT");
        platinum.mint(msg.sender, 1000);
        console.log(address(platinum));
        MockERC20 ruby = new MockERC20("RUBY", "RUBY");
        ruby.mint(msg.sender, 1000);
        console.log(address(ruby));
        MockERC20 emerald = new MockERC20("EMERALD", "EMR");
        emerald.mint(msg.sender, 1000);
        console.log(address(emerald));
        MockERC20 diamond = new MockERC20("DIAMOND", "DMND");
        diamond.mint(msg.sender, 1000);
        console.log(address(diamond));

        vm.stopBroadcast();
    }
}
