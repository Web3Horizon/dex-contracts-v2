// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DexerV2Pair} from "src/DexerV2Pair.sol";
import {DexerV2Factory} from "src/DexerV2Factory.sol";
import {MockERC20} from "src/mocks/MockERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract DexerV2FactoryTest is Test {
    MockERC20 tokenA;
    MockERC20 tokenB;
    address USER;
    DexerV2Pair dexerV2Pair;
    DexerV2Factory dexerV2Factory;

    function setUp() external {
        USER = makeAddr("user");

        // Mock tokens
        MockERC20 token0 = new MockERC20("Token0", "TKN0");
        MockERC20 token1 = new MockERC20("Token1", "TKN1");

        (tokenA, tokenB) = address(token0) < address(token1) ? (token0, token1) : (token1, token0);

        // Pair and factory contracts
        dexerV2Factory = new DexerV2Factory();
    }

    /*//////////////////////////////////////////////////////////////
                              Helpers
    //////////////////////////////////////////////////////////////*/
    function assertReserves(uint256 expectedReserve0, uint256 expectedReserve1) internal view {
        (uint256 reserve0, uint256 reserve1) = dexerV2Pair.getReserves();
        assertApproxEqRel(reserve0, expectedReserve0, 1e15, "Unexpected reserve0"); // 1e15 = 0.1%
        assertApproxEqRel(reserve1, expectedReserve1, 1e15, "Unexpected reserve1");
    }

    /*//////////////////////////////////////////////////////////////
                              CreatePair
    //////////////////////////////////////////////////////////////*/

    function testCreatePair() public {
        address pairAddress = dexerV2Factory.createPair({tokenA: address(tokenA), tokenB: address(tokenB)});

        dexerV2Pair = DexerV2Pair(pairAddress);
        address token0 = dexerV2Pair.token0();
        address token1 = dexerV2Pair.token1();

        // Ensure tokens are initialized correctly
        assertEq(token0, address(tokenA), "Token0 does not match expected");
        assertEq(token1, address(tokenB), "Token1 does not match expected");

        // Ensure the pair contract's reserves start at zero
        (uint256 reserve0, uint256 reserve1) = dexerV2Pair.getReserves();
        assertEq(reserve0, 0, "Initial reserve0 is not zero");
        assertEq(reserve1, 0, "Initial reserve1 is not zero");
    }

    function testCreatePairRevertsWith0Address() public {
        vm.expectRevert(DexerV2Factory.DexerV2Factory__ZeroAddress.selector);
        dexerV2Factory.createPair({tokenA: address(0), tokenB: address(tokenB)});
    }

    function testCreatePairRevertsWithIdenticalAddresses() public {
        vm.expectRevert(DexerV2Factory.DexerV2Factory__IndeticalAddresses.selector);
        dexerV2Factory.createPair({tokenA: address(tokenB), tokenB: address(tokenB)});
    }

    function testCreatePairRevertsWithExistingPair() public {
        dexerV2Factory.createPair({tokenA: address(tokenA), tokenB: address(tokenB)});
        vm.expectRevert(DexerV2Factory.DexerV2Factory__ExistingPair.selector);
        dexerV2Factory.createPair({tokenA: address(tokenA), tokenB: address(tokenB)}); // 2nd deploy
    }
}
