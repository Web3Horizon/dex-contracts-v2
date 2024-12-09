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
    address LIQUIDITY_USER;
    address FACTORY;
    DexerV2Pair dexerV2Pair;

    function setUp() external {
        // Users and factory
        USER = makeAddr("user");
        LIQUIDITY_USER = makeAddr("user2");
        FACTORY = makeAddr("factory");

        // Mock tokens
        MockERC20 token0 = new MockERC20("Token0", "TKN0");
        MockERC20 token1 = new MockERC20("Token1", "TKN1");

        // Sort mock tokens and rename (tokenA < tokenB)
        (tokenA, tokenB) = address(token0) < address(token1) ? (token0, token1) : (token1, token0);

        // Deal and mint tokens
        vm.deal(USER, STARTING_BALANCE);
        vm.deal(LIQUIDITY_USER, STARTING_BALANCE);
        tokenA.mint(USER, STARTING_BALANCE);
        tokenB.mint(USER, STARTING_BALANCE);
        tokenA.mint(LIQUIDITY_USER, STARTING_BALANCE);
        tokenB.mint(LIQUIDITY_USER, STARTING_BALANCE);

        // Deploy pair as if done by the factory
        vm.startPrank(FACTORY);
        dexerV2Pair = new DexerV2Pair();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              Helpers
    //////////////////////////////////////////////////////////////*/
    function _assertReserves(uint256 expectedReserve0, uint256 expectedReserve1) internal view {
        (uint256 reserve0, uint256 reserve1) = dexerV2Pair.getReserves();
        assertApproxEqRel(reserve0, expectedReserve0, 1e15, "Unexpected reserve0"); // 1e15 = 0.1%
        assertApproxEqRel(reserve1, expectedReserve1, 1e15, "Unexpected reserve1");
    }

    /*//////////////////////////////////////////////////////////////
                              MODIFIER
    //////////////////////////////////////////////////////////////*/

    modifier initialized() {
        vm.startPrank(FACTORY);

        dexerV2Pair.initialize({_token0: address(tokenA), _token1: address(tokenB)});

        vm.stopPrank();
        _;
    }

    modifier withLiquidity() {
        uint256 tokenAAmount = 1 ether;
        uint256 tokenBAmount = 10 ether;

        vm.startPrank(LIQUIDITY_USER);

        tokenA.transfer(address(dexerV2Pair), tokenAAmount);
        tokenB.transfer(address(dexerV2Pair), tokenBAmount);

        dexerV2Pair.mint({to: LIQUIDITY_USER});

        vm.stopPrank();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              Initialize
    //////////////////////////////////////////////////////////////*/
    function testInitialize() public {
        vm.startPrank(FACTORY);

        dexerV2Pair.initialize({_token0: address(tokenA), _token1: address(tokenB)});

        vm.stopPrank();

        address token0 = dexerV2Pair.token0();
        address token1 = dexerV2Pair.token1();

        // Ensure tokens are initialized correctly
        assertEq(token0, address(tokenA), "Token0 does not match expected");
        assertEq(token1, address(tokenB), "Token1 does not match expected");

        // // Ensure the pair contract's reserves start at zero
        _assertReserves({expectedReserve0: 0, expectedReserve1: 0});
    }

    function testInitializeRevertsIfNotFactory() public {
        vm.startPrank(USER);

        vm.expectRevert(DexerV2Pair.DexerV2Pair__Unauthorized.selector);
        dexerV2Pair.initialize({_token0: address(tokenA), _token1: address(tokenB)});

        vm.stopPrank();
    }

    function testInitializeRevertsIfAlreadyInitialized() public {
        vm.startPrank(FACTORY);

        // Initialize once
        dexerV2Pair.initialize({_token0: address(tokenA), _token1: address(tokenB)});

        // Initialize again
        vm.expectRevert(DexerV2Pair.DexerV2Pair__AlreadyInitialized.selector);
        dexerV2Pair.initialize({_token0: address(tokenA), _token1: address(tokenB)});

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              Mint
    //////////////////////////////////////////////////////////////*/
    function testMintWithNoLiquidity() public initialized {
        uint256 tokenAAmount = 1 ether;
        uint256 tokenBAmount = 10 ether;

        // Add liquidity
        vm.startPrank(USER);

        tokenA.transfer(address(dexerV2Pair), tokenAAmount);
        tokenB.transfer(address(dexerV2Pair), tokenBAmount);

        uint256 lpTokensMinted = dexerV2Pair.mint({to: USER});

        vm.stopPrank();

        // Asserts reserves
        _assertReserves(tokenAAmount, tokenBAmount);

        uint256 UserLPTokenBalanceAfter = dexerV2Pair.balanceOf(USER);

        // Assert LP minted
        assertEq(lpTokensMinted, Math.sqrt(tokenAAmount * tokenBAmount), "Unexpected amount of LP tokens minted");
        assertEq(UserLPTokenBalanceAfter, lpTokensMinted, "LP tokens should be minted for the USER");
    }

    function testMintWithLiquidity() public initialized withLiquidity {
        uint256 tokenAAmount = 1 ether;
        uint256 tokenBAmount = 10 ether;

        // Variables before tx
        (uint256 reserve0Before, uint256 reserve1Before) = dexerV2Pair.getReserves();
        uint256 lpTokenSupplyBefore = dexerV2Pair.totalSupply();
        uint256 UserLPTokenBalanceBefore = dexerV2Pair.balanceOf(USER);

        // Add liquidity
        vm.startPrank(USER);

        tokenA.transfer(address(dexerV2Pair), tokenAAmount);
        tokenB.transfer(address(dexerV2Pair), tokenBAmount);

        uint256 lpTokensMinted = dexerV2Pair.mint({to: USER});

        vm.stopPrank();

        // Variables after tx
        uint256 lpTokenSupplyAfter = dexerV2Pair.totalSupply();
        uint256 UserLPTokenBalanceAfter = dexerV2Pair.balanceOf(USER);

        // Expected variables
        uint256 expectedTotalLPTokenSupply = lpTokenSupplyBefore + lpTokensMinted;
        uint256 expectedReserve0 = reserve0Before + tokenAAmount;
        uint256 expectedReserve1 = reserve1Before + tokenBAmount;

        // Assert LP token total supply
        assertEq(lpTokenSupplyAfter, expectedTotalLPTokenSupply, "Unexpected total LP token supply");

        // Assert users lp token balance
        assertEq(UserLPTokenBalanceAfter, UserLPTokenBalanceBefore + lpTokensMinted, "Unexpected User LP token balance");

        // Assert reserves
        _assertReserves({expectedReserve0: expectedReserve0, expectedReserve1: expectedReserve1});
    }

    function testMintUnbalanced() public initialized withLiquidity {
        // With liquidity modifier gives us a A:B ratio of 1:10
        uint256 tokenAAmount = 1 ether;
        uint256 tokenBAmount = 100 ether;

        // Variables before tx
        (uint256 reserve0Before, uint256 reserve1Before) = dexerV2Pair.getReserves();
        uint256 lpTokenSupplyBefore = dexerV2Pair.totalSupply();

        // Add liquidity
        vm.startPrank(USER);

        tokenA.transfer(address(dexerV2Pair), tokenAAmount);
        tokenB.transfer(address(dexerV2Pair), tokenBAmount);

        uint256 lpTokensMinted = dexerV2Pair.mint({to: USER});

        vm.stopPrank();

        // Variables after tx
        uint256 expectedReserve0 = reserve0Before + tokenAAmount;
        uint256 expectedReserve1 = reserve1Before + tokenBAmount;

        // Asserts
        // Any excess tokens should not be considered, therefore the LP tokens should be doubled in this case.
        assertEq(lpTokensMinted, lpTokenSupplyBefore, "LP tokens minted be minted in terms of the minimum reserve");

        // Assert reserves
        _assertReserves({expectedReserve0: expectedReserve0, expectedReserve1: expectedReserve1});
    }

    function testMintRevertsWithInsufficientToken0() public initialized {
        uint256 tokenAAmount = 1 ether;
        uint256 tokenBAmount = 0 ether;

        // Add liquidity
        vm.startPrank(USER);

        tokenA.transfer(address(dexerV2Pair), tokenAAmount);
        tokenB.transfer(address(dexerV2Pair), tokenBAmount);

        vm.expectRevert(DexerV2Pair.DexerV2pair__InsufficientLiquidityMint.selector);
        dexerV2Pair.mint({to: USER});

        vm.stopPrank();
    }

    function testMintRevertsWithInsufficientToken1() public initialized {
        uint256 tokenAAmount = 0 ether;
        uint256 tokenBAmount = 1 ether;

        // Add liquidity
        vm.startPrank(USER);

        tokenA.transfer(address(dexerV2Pair), tokenAAmount);
        tokenB.transfer(address(dexerV2Pair), tokenBAmount);

        vm.expectRevert(DexerV2Pair.DexerV2pair__InsufficientLiquidityMint.selector);
        dexerV2Pair.mint({to: USER});

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              Burn
    //////////////////////////////////////////////////////////////*/
    function testBurn() public initialized withLiquidity {
        _assertReserves({expectedReserve0: 1 ether, expectedReserve1: 10 ether});

        uint256 userLpTokenBalanceBefore = dexerV2Pair.balanceOf(LIQUIDITY_USER);

        // Burn LP
        vm.startPrank(LIQUIDITY_USER);

        dexerV2Pair.transfer(address(dexerV2Pair), userLpTokenBalanceBefore); // Transfer the whole balance

        dexerV2Pair.burn({to: LIQUIDITY_USER});

        vm.stopPrank();

        // Variables after burn
        uint256 userLpTokenBalanceAfter = dexerV2Pair.balanceOf(LIQUIDITY_USER);
        uint256 userTokenABalanceAfter = tokenA.balanceOf(LIQUIDITY_USER);
        uint256 userTokenBBalanceAfter = tokenB.balanceOf(LIQUIDITY_USER);

        // Assert USER's token balances
        assertEq(userLpTokenBalanceAfter, 0, "All LP tokens should be burned");
        assertEq(userTokenABalanceAfter, 100 ether, "Unexpected amount of token A balance after burn");
        assertEq(userTokenBBalanceAfter, 100 ether, "Unexpected amount of token B balance after burn");

        // Assert reserves
        _assertReserves({expectedReserve0: 0, expectedReserve1: 0});
    }

    function testBurnRevertsWithNoLiquidity() public initialized {
        vm.startPrank(USER);

        vm.expectRevert(DexerV2Pair.DexerV2pair__InsufficientLiquidityBurn.selector);
        dexerV2Pair.burn({to: USER});

        vm.stopPrank();
    }

    function testBurnBurnsLPToken() public initialized withLiquidity {
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

    function testBurnDepletesReserves() public initialized withLiquidity {
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

    function testBurnReturnsCorrectTokensAmount() public initialized withLiquidity {
        uint256 userLPTokenBalanceBefore = dexerV2Pair.balanceOf(LIQUIDITY_USER);
        uint256 amountOfLPTokenToBurn = userLPTokenBalanceBefore / 2; // 50% of total users balance

        _assertReserves({expectedReserve0: 1 ether, expectedReserve1: 10 ether});

        vm.startPrank(LIQUIDITY_USER);

        dexerV2Pair.transfer(address(dexerV2Pair), amountOfLPTokenToBurn);

        (uint256 tokenAReturned, uint256 tokenBReturned) = dexerV2Pair.burn({to: LIQUIDITY_USER});

        vm.stopPrank();

        console.log("TokenAReturned: ", tokenAReturned);
        console.log("TokenBReturned: ", tokenBReturned);

        _assertReserves({expectedReserve0: 0.5 ether, expectedReserve1: 5 ether});
    }

    /*//////////////////////////////////////////////////////////////
                              Swap
    //////////////////////////////////////////////////////////////*/

    function testSwap() public initialized withLiquidity {
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

        _assertReserves(expectedReserveA, expectedReserveB);
    }

    function testSwapOtherToken() public initialized withLiquidity {
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

        _assertReserves(expectedReserveA, expectedReserveB);
    }

    function testSwapRevertsIfOverpriced() public initialized withLiquidity {
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

    function testSwapRevertsIfOverpricedOtherToken() public initialized withLiquidity {
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

    function testSwapRevertsIfInsufficientLiquidity() public initialized withLiquidity {
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

    function testSwapRevertsIfZeroOutput() public initialized withLiquidity {
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

    function testSwapRevertsIfZeroInput() public initialized withLiquidity {
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
