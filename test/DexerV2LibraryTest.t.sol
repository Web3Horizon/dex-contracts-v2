// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DexerV2Pair} from "src/DexerV2Pair.sol";
import {IDexerV2Pair} from "src/interfaces/IDexerV2Pair.sol";
import {DexerV2Factory} from "src/DexerV2Factory.sol";
import {DexerV2Router} from "src/DexerV2Router.sol";
import {DexerV2Library} from "src/libraries/DexerV2Library.sol";
import {MockERC20} from "src/mocks/MockERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {DexerV2LibraryHarness} from "src/mocks/DexerV2LibraryHarness.sol";

contract TestDexerV2Library is Test {
    DexerV2LibraryHarness libraryHarness;
    DexerV2Factory factory;
    MockERC20 tokenA;
    MockERC20 tokenB;
    MockERC20 tokenC;

    DexerV2Pair dexerV2Pair;
    DexerV2Router dexerV2Router;

    function setUp() public {
        libraryHarness = new DexerV2LibraryHarness();
        factory = new DexerV2Factory();
        tokenA = new MockERC20("TokenA", "TKA");
        tokenB = new MockERC20("TokenB", "TKB");
        tokenC = new MockERC20("TokenC", "TKC");
    }

    /*//////////////////////////////////////////////////////////////
                              sortToken
    //////////////////////////////////////////////////////////////*/

    function testSortTokens() public view {
        (address token0, address token1) = libraryHarness.sortTokens({tokenA: address(tokenA), tokenB: address(tokenB)});
        assertTrue(token0 < token1, "Token0 should be smaller address than Token1");
    }

    /*//////////////////////////////////////////////////////////////
                              quote
    //////////////////////////////////////////////////////////////*/

    function testQuote() public view {
        // amountIn = 10 ether
        // reserveIn = 100 ether
        // reserveOut = 200 ether
        // numerator = 10 * 200
        // denominator = 100
        // amountOut = numerator / denominator = 20

        uint256 amountOut = libraryHarness.quote({amountIn: 10 ether, reserveIn: 100 ether, reserveOut: 200 ether});

        // relative error of 1e15 (0.05%) for approximation
        assertApproxEqRel(amountOut, 20 ether, 5e14, "Unexpected quote amountOut");
    }

    function testQuoteRevertsOnZeroAmountIn() public {
        vm.expectRevert(DexerV2Library.DexerV2Library__InsufficientAmount.selector);
        libraryHarness.quote({amountIn: 0 ether, reserveIn: 100 ether, reserveOut: 200 ether});
    }

    function testQuoteRevertsOnZeroReserveIn() public {
        vm.expectRevert(DexerV2Library.DexerV2Library__InsufficientLiquidity.selector);
        libraryHarness.quote({amountIn: 10 ether, reserveIn: 0 ether, reserveOut: 200 ether});
    }

    function testQuoteRevertsOnZeroReserveOut() public {
        vm.expectRevert(DexerV2Library.DexerV2Library__InsufficientLiquidity.selector);
        libraryHarness.quote({amountIn: 10 ether, reserveIn: 100 ether, reserveOut: 0 ether});
    }

    /*//////////////////////////////////////////////////////////////
                              getAmountOut
    //////////////////////////////////////////////////////////////*/

    function testGetAmountOut() public view {
        // With a 0.3% fee (997 multiplier)
        ///////////////////////////////////////////
        // amountIn = 1000 ether
        // reserveIn = 10_000 ether
        // reserveOut = 20_000 ether
        // amountInWithFee = 1000 * 997 = 997000
        // numerator = 997000 * 20000 = 19,940,000,000
        // denominator = (10000 * 1000) + 997000 = 10,000,000 + 997,000 = 10,997,000
        // amountOut = numerator / denominator ≈ 1814 (approx)
        uint256 amountOut =
            libraryHarness.getAmountOut({amountIn: 1000 ether, reserveIn: 10_000 ether, reserveOut: 20_000 ether});

        // relative error of 1e15 (0.05%) for approximation
        assertApproxEqRel(amountOut, 1814 ether, 5e14, "Unexpected amountOut");
    }

    function testGetAmountOutRevertsOnZeroAmount() public {
        vm.expectRevert(DexerV2Library.DexerV2Library__InsufficientAmount.selector);
        libraryHarness.getAmountOut({amountIn: 0 ether, reserveIn: 10_000 ether, reserveOut: 20_000 ether});
    }

    function testGetAmountOutRevertsOnZeroReserveIn() public {
        vm.expectRevert(DexerV2Library.DexerV2Library__InsufficientLiquidity.selector);
        libraryHarness.getAmountOut({amountIn: 1000 ether, reserveIn: 0 ether, reserveOut: 20_000 ether});
    }

    function testGetAmountOutRevertsOnZeroReserveOut() public {
        vm.expectRevert(DexerV2Library.DexerV2Library__InsufficientLiquidity.selector);
        libraryHarness.getAmountOut({amountIn: 1000 ether, reserveIn: 0 ether, reserveOut: 20_000 ether});
    }

    /*//////////////////////////////////////////////////////////////
                              getAmountsOut
    //////////////////////////////////////////////////////////////*/

    function testGetAmountsOut() public {
        // Set up a pair in the factory
        address pairAddress = factory.createPair(address(tokenA), address(tokenB));

        // Add liquidity:
        // tokenA: 10_000 tokens
        // tokenB: 20_000 tokens
        // Using ether units to keep consistent:
        vm.startPrank(address(this));
        tokenA.mint(address(pairAddress), 10_000 ether);
        tokenB.mint(address(pairAddress), 20_000 ether);
        DexerV2Pair(pairAddress).mint(address(this));
        vm.stopPrank();

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        // With a 0.3% fee (997 multiplier)
        ///////////////////////////////////////////
        // amountIn = 1000 ether
        // reserveIn = 10_000 ether
        // reserveOut = 20_000 ether
        // amountInWithFee = 1000 * 997 = 997000
        // numerator = 997000 * 20000 = 19,940,000,000
        // denominator = (10000 * 1000) + 997000 = 10,000,000 + 997,000 = 10,997,000
        // amountOut = numerator / denominator ≈ 1814 (approx)
        uint256[] memory amounts =
            libraryHarness.getAmountsOut({factoryAddress: address(factory), amountIn: 1000 ether, path: path});

        assertEq(amounts[0], 1000 ether, "Incorrect amountIn");
        assertApproxEqRel(amounts[1], 1814 ether, 5e14, "Unexpected amounts[1]");
    }

    function testGetAmountsOutRevertsIfPathIsLessThanTwo() public {
        address[] memory path = new address[](1);
        path[0] = address(tokenA);
        vm.expectRevert(DexerV2Library.DexerV2Library__InvalidPath.selector);
        libraryHarness.getAmountsOut({factoryAddress: address(factory), amountIn: 1000 ether, path: path});
    }

    /*//////////////////////////////////////////////////////////////
                              getAmountsOut (multi-hop)
    //////////////////////////////////////////////////////////////*/
    function testGetAmountsOutMultiHop() public {
        // Setup two pairs: A-B and B-C
        address pairAB = factory.createPair(address(tokenA), address(tokenB));
        address pairBC = factory.createPair(address(tokenB), address(tokenC));

        // Add liquidity to A-B
        vm.startPrank(address(this));
        tokenA.mint(address(pairAB), 10_000 ether);
        tokenB.mint(address(pairAB), 20_000 ether);
        DexerV2Pair(pairAB).mint(address(this));

        // Add liquidity to B-C
        tokenB.mint(address(pairBC), 20_000 ether);
        tokenC.mint(address(pairBC), 40_000 ether);
        DexerV2Pair(pairBC).mint(address(this));
        vm.stopPrank();

        // Path: A -> B -> C
        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);

        // amountIn: 1000 ether of tokenA
        // This will calculate amount after A->B, then after B->C
        uint256[] memory amounts =
            libraryHarness.getAmountsOut({factoryAddress: address(factory), amountIn: 1000 ether, path: path});

        /*
        First swap A->B: amountIn = 1000, reserveIn = 10_000, reserveOut = 20_000
                        outputAB ≈ 1814  (calculated previously)
        Second swap B->C: amountIn ≈ 1814, reserveIn = 20_000, reserveOut = 40_000
                          amountInFee = 1814 * 997 = 1_808_558
                          numerator = 1_808_558 * 40_000 = 72_342_320_000
                          denominator = 20_000 * 1000 + 1_808_558 = 21_808_558
                          outputBC ≈ numerator / denomiator ≈ 3317
        */

        // Check the amountIn is correct
        assertEq(amounts[0], 1000 ether, "Incorrect amountIn for multi-hop");
        assertApproxEqRel(amounts[1], 1814 ether, 1e15, "Unexpected output from intermidiate swap(A->B) amounts[1]");
        assertApproxEqRel(amounts[2], 3317 ether, 1e15, "Unexpected output from intermidiate swap(B->C) amounts[2]");
    }
}
