// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DexerV2Pair} from "src/DexerV2Pair.sol";
import {DexerV2Factory} from "src/DexerV2Factory.sol";
import {MockERC20} from "src/mocks/MockERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract DexerV2PairTest is Test {
    MockERC20 tokenA;
    MockERC20 tokenB;
    uint256 STARTING_BALANCE = 100 ether;
    address USER;
    address LIQUIDITY_USER;
    DexerV2Pair dexerV2Pair;
    DexerV2Factory dexerV2Factory;

    function setUp() external {
        USER = makeAddr("user");
        LIQUIDITY_USER = makeAddr("user2");

        // Mock tokens

        MockERC20 token0 = new MockERC20("Token0", "TKN0");
        MockERC20 token1 = new MockERC20("Token1", "TKN1");

        (tokenA, tokenB) = address(token0) < address(token1) ? (token0, token1) : (token1, token0);

        // tokenA = new MockERC20("Token A", "TKNA");
        // tokenB = new MockERC20("Token B", "TKNB");

        // Pair and factory contracts
        dexerV2Factory = new DexerV2Factory();
        // dexerV2Pair = new DexerV2Pair();

        address pair = dexerV2Factory.createPair(address(tokenA), address(tokenB));

        dexerV2Pair = DexerV2Pair(pair);

        // dexerV2Pair.initialize(address(tokenA), address(tokenB));

        vm.deal(USER, STARTING_BALANCE);
        vm.deal(LIQUIDITY_USER, STARTING_BALANCE);

        tokenA.mint(USER, 100 ether);
        tokenB.mint(USER, 100 ether);
        tokenA.mint(LIQUIDITY_USER, 100 ether);
        tokenB.mint(LIQUIDITY_USER, 100 ether);
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
                              MODIFIER
    //////////////////////////////////////////////////////////////*/
    modifier withLiquidity() {
        uint256 tokenAAmount = 1 ether;
        uint256 tokenBAmount = 10 ether;

        vm.startPrank(LIQUIDITY_USER);

        tokenA.transfer(address(dexerV2Pair), tokenAAmount);
        tokenB.transfer(address(dexerV2Pair), tokenBAmount);

        dexerV2Pair.mint();

        vm.stopPrank();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              Initialize
    //////////////////////////////////////////////////////////////*/

    function testInitialize() public {
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

    function testMintRevertsWithInsufficientTokens() public {
        uint256 tokenAAmount = 1 ether;
        uint256 tokenBAmount = 0 ether;

        vm.startPrank(USER);

        tokenA.transfer(address(dexerV2Pair), tokenAAmount);
        tokenB.transfer(address(dexerV2Pair), tokenBAmount);

        vm.expectRevert(DexerV2Pair.DexerV2pair__InsufficientLiquidityMint.selector);
        dexerV2Pair.mint();

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              Burn
    //////////////////////////////////////////////////////////////*/
    function testBurn() public withLiquidity {
        assertReserves({expectedReserve0: 1 ether, expectedReserve1: 10 ether});

        uint256 userLpTokenBalanceBefore = dexerV2Pair.balanceOf(LIQUIDITY_USER);
        vm.startPrank(LIQUIDITY_USER);

        dexerV2Pair.transfer(address(dexerV2Pair), userLpTokenBalanceBefore);

        dexerV2Pair.burn({to: LIQUIDITY_USER});

        vm.stopPrank();

        uint256 userLpTokenBalanceAfter = dexerV2Pair.balanceOf(LIQUIDITY_USER);
        uint256 userTokenABalanceAfter = tokenA.balanceOf(LIQUIDITY_USER);
        uint256 userTokenBBalanceAfter = tokenB.balanceOf(LIQUIDITY_USER);

        assertEq(userLpTokenBalanceAfter, 0, "All LP tokens should be burned");
        assertEq(userTokenABalanceAfter, 100 ether, "Unexpected amount of token A balance after burn");
        assertEq(userTokenBBalanceAfter, 100 ether, "Unexpected amount of token B balance after burn");

        assertReserves({expectedReserve0: 0, expectedReserve1: 0});
    }

    function testBurnRevertsWithNoLiquidity() public {
        vm.startPrank(USER);

        vm.expectRevert(DexerV2Pair.DexerV2pair__InsufficientLiquidityBurn.selector);
        dexerV2Pair.burn({to: USER});

        vm.stopPrank();
    }

    function testBurnBurnsLPToken() public withLiquidity {
        // Variables before tx
        uint256 lpTokenSupplyBefore = dexerV2Pair.totalSupply();
        uint256 userLPTokenBalanceBefore = dexerV2Pair.balanceOf(LIQUIDITY_USER);

        require(userLPTokenBalanceBefore > 0, "Initial USER LP tokens should be > 0");
        require(lpTokenSupplyBefore > 0, "Initial LP tokens should be > 0");

        vm.startPrank(LIQUIDITY_USER);

        dexerV2Pair.transfer(address(dexerV2Pair), userLPTokenBalanceBefore);

        dexerV2Pair.burn({to: LIQUIDITY_USER});

        vm.stopPrank();

        uint256 userLPTokenBalanceAfter = dexerV2Pair.balanceOf(LIQUIDITY_USER);
        uint256 lpTokenSupplyAfter = dexerV2Pair.totalSupply();

        assertEq(userLPTokenBalanceAfter, 0, "USER LP tokens balanced should be zero after burn");
        assertEq(lpTokenSupplyAfter, 0, "LP tokens balanced should be zero after burn");
    }

    function testBurnDepletesReserves() public withLiquidity {
        // Variables before tx
        (uint256 reserveABefore, uint256 reserveBBefore) = dexerV2Pair.getReserves();
        uint256 userLPTokenBalanceBefore = dexerV2Pair.balanceOf(LIQUIDITY_USER);

        require(reserveABefore > 0, "Initial tokenA reserve should be > 0");
        require(reserveBBefore > 0, "Initial tokenB reserve should be > 0");

        vm.startPrank(LIQUIDITY_USER);

        dexerV2Pair.transfer(address(dexerV2Pair), userLPTokenBalanceBefore);

        dexerV2Pair.burn({to: LIQUIDITY_USER});

        vm.stopPrank();

        (uint256 reserveAAfter, uint256 reserveBAfter) = dexerV2Pair.getReserves();

        assertEq(reserveAAfter, 0, "Unexpected TokenA reserves after burn");
        assertEq(reserveBAfter, 0, "Unexpected TokenB reserves after burn");
    }

    function testBurnReturnsCorrectTokensAmount() public withLiquidity {
        uint256 userLPTokenBalanceBefore = dexerV2Pair.balanceOf(LIQUIDITY_USER);
        uint256 amountOfLPTokenToBurn = userLPTokenBalanceBefore / 2; // 50% of total users balance

        assertReserves({expectedReserve0: 1 ether, expectedReserve1: 10 ether});

        vm.startPrank(LIQUIDITY_USER);

        dexerV2Pair.transfer(address(dexerV2Pair), amountOfLPTokenToBurn);

        (uint256 tokenAReturned, uint256 tokenBReturned) = dexerV2Pair.burn({to: LIQUIDITY_USER});

        vm.stopPrank();

        console.log("TokenAReturned: ", tokenAReturned);
        console.log("TokenBReturned: ", tokenBReturned);

        assertReserves({expectedReserve0: 0.5 ether, expectedReserve1: 5 ether});
    }

    /*//////////////////////////////////////////////////////////////
                              Swap
    //////////////////////////////////////////////////////////////*/

    function testSwap() public withLiquidity {
        uint256 amountAIn = 1 ether;
        uint256 amountBIn = 0 ether;
        uint256 amountAOut = 0 ether;
        uint256 amountBOut = 4.9924 ether;

        (uint256 reserveABefore, uint256 reserveBBefore) = dexerV2Pair.getReserves();

        vm.startPrank(USER);

        tokenA.transfer(address(dexerV2Pair), amountAIn);
        tokenB.transfer(address(dexerV2Pair), amountBIn);

        dexerV2Pair.swap({amount0Out: amountAOut, amount1Out: amountBOut, to: USER});

        vm.stopPrank();

        uint256 expectedReserveA = reserveABefore + amountAIn - amountAOut;
        uint256 expectedReserveB = reserveBBefore + amountBIn - amountBOut;

        assertReserves(expectedReserveA, expectedReserveB);
    }

    function testSwapOtherToken() public withLiquidity {
        uint256 amountAIn = 0 ether;
        uint256 amountBIn = 1 ether;
        uint256 amountAOut = 0.09 ether;
        uint256 amountBOut = 0 ether;

        (uint256 reserveABefore, uint256 reserveBBefore) = dexerV2Pair.getReserves();

        vm.startPrank(USER);

        tokenA.transfer(address(dexerV2Pair), amountAIn);
        tokenB.transfer(address(dexerV2Pair), amountBIn);

        dexerV2Pair.swap({amount0Out: amountAOut, amount1Out: amountBOut, to: USER});

        vm.stopPrank();

        uint256 expectedReserveA = reserveABefore + amountAIn - amountAOut;
        uint256 expectedReserveB = reserveBBefore + amountBIn - amountBOut;

        assertReserves(expectedReserveA, expectedReserveB);
    }

    function testSwapRevertsIfOverpriced() public withLiquidity {
        uint256 amountAIn = 1 ether;
        uint256 amountBIn = 0 ether;
        uint256 amountAOut = 0 ether;
        uint256 amountBOut = 7 ether;

        vm.startPrank(USER);

        tokenA.transfer(address(dexerV2Pair), amountAIn);
        tokenB.transfer(address(dexerV2Pair), amountBIn);

        vm.expectRevert(DexerV2Pair.DexerV2Pair__InvalidK.selector);
        dexerV2Pair.swap({amount0Out: amountAOut, amount1Out: amountBOut, to: USER});

        vm.stopPrank();
    }

    function testSwapRevertsIfOverpricedOtherToken() public withLiquidity {
        uint256 amountAIn = 0 ether;
        uint256 amountBIn = 1 ether;
        uint256 amountAOut = 0.5 ether;
        uint256 amountBOut = 0 ether;

        vm.startPrank(USER);

        tokenA.transfer(address(dexerV2Pair), amountAIn);
        tokenB.transfer(address(dexerV2Pair), amountBIn);

        vm.expectRevert(DexerV2Pair.DexerV2Pair__InvalidK.selector);
        dexerV2Pair.swap({amount0Out: amountAOut, amount1Out: amountBOut, to: USER});

        vm.stopPrank();
    }

    function testSwapRevertsIfInsufficientLiquidity() public withLiquidity {
        uint256 amountAIn = 1 ether;
        uint256 amountBIn = 0 ether;
        uint256 amountAOut = 0 ether;
        uint256 amountBOut = 11 ether;

        vm.startPrank(USER);

        tokenA.transfer(address(dexerV2Pair), amountAIn);
        tokenB.transfer(address(dexerV2Pair), amountBIn);

        vm.expectRevert(DexerV2Pair.DexerV2Pair__InsufficientLiquidity.selector);
        dexerV2Pair.swap({amount0Out: amountAOut, amount1Out: amountBOut, to: USER});

        vm.stopPrank();
    }

    function testSwapRevertsIfZeroOutput() public withLiquidity {
        uint256 amountAIn = 1 ether;
        uint256 amountBIn = 0 ether;
        uint256 amountAOut = 0 ether;
        uint256 amountBOut = 0 ether;

        vm.startPrank(USER);

        tokenA.transfer(address(dexerV2Pair), amountAIn);
        tokenB.transfer(address(dexerV2Pair), amountBIn);

        vm.expectRevert(DexerV2Pair.DexerV2Pair__InsufficientOutputAmount.selector);
        dexerV2Pair.swap({amount0Out: amountAOut, amount1Out: amountBOut, to: USER});

        vm.stopPrank();
    }

    function testSwapRevertsIfZeroInput() public withLiquidity {
        uint256 amountAIn = 0 ether;
        uint256 amountBIn = 0 ether;
        uint256 amountAOut = 0 ether;
        uint256 amountBOut = 1 ether;

        vm.startPrank(USER);

        tokenA.transfer(address(dexerV2Pair), amountAIn);
        tokenB.transfer(address(dexerV2Pair), amountBIn);

        vm.expectRevert(DexerV2Pair.DexerV2Pair__InsufficientInputAmount.selector);
        dexerV2Pair.swap({amount0Out: amountAOut, amount1Out: amountBOut, to: USER});

        vm.stopPrank();
    }
}
