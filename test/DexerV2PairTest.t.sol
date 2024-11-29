// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DexerV2Pair} from "src/DexerV2Pair.sol";
import {MockERC20} from "src/mocks/MockERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract DexerV2PairTest is Test {
    MockERC20 tokenA;
    MockERC20 tokenB;
    uint256 STARTING_BALANCE = 100 ether;
    address USER;
    address USER2;
    DexerV2Pair dexerV2Pair;

    function setUp() external {
        USER = makeAddr("user");
        USER2 = makeAddr("user2");
        tokenA = new MockERC20("Token A", "TKNA");
        tokenB = new MockERC20("Token B", "TKNB");
        dexerV2Pair = new DexerV2Pair(address(tokenA), address(tokenB));

        vm.deal(USER, STARTING_BALANCE);
        vm.deal(USER2, STARTING_BALANCE);

        tokenA.mint(USER, 100 ether);
        tokenB.mint(USER, 100 ether);
        tokenA.mint(USER2, 100 ether);
        tokenB.mint(USER2, 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                              Helpers
    //////////////////////////////////////////////////////////////*/
    function assertReserves(uint256 expectedReserve0, uint256 expectedReserve1) internal view {
        (uint256 reserve0, uint256 reserve1) = dexerV2Pair.getReserves();
        assertEq(reserve0, expectedReserve0, "Unexpected reserve0");
        assertEq(reserve1, expectedReserve1, "Unexpected reserve1");
    }

    /*//////////////////////////////////////////////////////////////
                              MODIFIER
    //////////////////////////////////////////////////////////////*/
    modifier withLiquidity() {
        uint256 tokenAAmount = 1 ether;
        uint256 tokenBAmount = 10 ether;

        vm.startPrank(USER2);

        tokenA.transfer(address(dexerV2Pair), tokenAAmount);
        tokenB.transfer(address(dexerV2Pair), tokenBAmount);

        dexerV2Pair.mint();

        vm.stopPrank();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              Mint
    //////////////////////////////////////////////////////////////*/
    function testMintWithNoLiquidity() public {
        uint256 tokenAAmount = 1 ether;
        uint256 tokenBAmount = 10 ether;

        vm.startPrank(USER); // Start prank

        tokenA.transfer(address(dexerV2Pair), tokenAAmount);
        tokenB.transfer(address(dexerV2Pair), tokenBAmount);

        uint256 lpTokensMinted = dexerV2Pair.mint();

        vm.stopPrank(); // End prank

        uint256 lpTokenSupplyAfter = dexerV2Pair.totalSupply();
        uint256 UserLPTokenBalanceAfter = dexerV2Pair.balanceOf(USER);

        // Asserts
        assertReserves(tokenAAmount, tokenBAmount);
        assertEq(lpTokenSupplyAfter, Math.sqrt(tokenAAmount * tokenBAmount), "Unexpected amount of LP tokens minted");
        assertEq(UserLPTokenBalanceAfter, lpTokensMinted, "LP tokens should be minted for the USER");
    }

    function testMintWithLiquidity() public withLiquidity {
        uint256 tokenAAmount = 1 ether;
        uint256 tokenBAmount = 10 ether;

        // Variables before tx
        (uint256 reserve0Before, uint256 reserve1Before) = dexerV2Pair.getReserves();
        uint256 lpTokenSupplyBefore = dexerV2Pair.totalSupply();
        uint256 UserLPTokenBalanceBefore = dexerV2Pair.balanceOf(USER);

        vm.startPrank(USER);

        tokenA.transfer(address(dexerV2Pair), tokenAAmount);
        tokenB.transfer(address(dexerV2Pair), tokenBAmount);

        uint256 lpTokensMinted = dexerV2Pair.mint();

        vm.stopPrank();

        // Variables after tx
        uint256 lpTokenSupplyAfter = dexerV2Pair.totalSupply();
        uint256 UserLPTokenBalanceAfter = dexerV2Pair.balanceOf(USER);

        uint256 expectedTotalLPTokenSupply = lpTokenSupplyBefore + lpTokensMinted;
        uint256 expectedReserve0 = reserve0Before + tokenAAmount;
        uint256 expectedReserve1 = reserve1Before + tokenBAmount;
        // Asserts
        assertEq(lpTokenSupplyAfter, expectedTotalLPTokenSupply, "Unexpected total LP token supply");

        assertEq(UserLPTokenBalanceAfter, UserLPTokenBalanceBefore + lpTokensMinted, "Unexpected User LP token balance");

        assertReserves({expectedReserve0: expectedReserve0, expectedReserve1: expectedReserve1});
    }

    function testMintUnbalanced() public withLiquidity {
        // With liquidity modifier gives us a A:B ratio of 1:10
        uint256 tokenAAmount = 1 ether;
        uint256 tokenBAmount = 100 ether;

        // Variables before tx
        (uint256 reserve0Before, uint256 reserve1Before) = dexerV2Pair.getReserves();
        uint256 lpTokenSupplyBefore = dexerV2Pair.totalSupply();

        vm.startPrank(USER);

        tokenA.transfer(address(dexerV2Pair), tokenAAmount);
        tokenB.transfer(address(dexerV2Pair), tokenBAmount);

        uint256 lpTokensMinted = dexerV2Pair.mint();

        vm.stopPrank();

        // Variables after tx
        uint256 expectedReserve0 = reserve0Before + tokenAAmount;
        uint256 expectedReserve1 = reserve1Before + tokenBAmount;

        // Asserts
        // Any excess tokens should not be considered, therefore the LP tokens should be doubled in this case.
        assertEq(lpTokensMinted, lpTokenSupplyBefore, "LP tokens minted be minted in terms of the minimum reserve");
        assertReserves({expectedReserve0: expectedReserve0, expectedReserve1: expectedReserve1});
    }
}
