// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DexerV2Pair} from "src/DexerV2Pair.sol";
import {DexerV2Factory} from "src/DexerV2Factory.sol";
import {MockERC20} from "src/mocks/MockERC20.sol";

contract DexerV2FactoryTest is Test {
    MockERC20 tokenA;
    MockERC20 tokenB;
    MockERC20 tokenC;
    DexerV2Pair dexerV2Pair;
    DexerV2Factory dexerV2Factory;

    function setUp() external {
        // Mock tokens
        MockERC20 token0 = new MockERC20("Token0", "TKN0");
        MockERC20 token1 = new MockERC20("Token1", "TKN1");

        (tokenA, tokenB) = address(token0) < address(token1) ? (token0, token1) : (token1, token0);
        tokenC = new MockERC20("TokenC", "TKNC");

        // Pair and factory contracts
        dexerV2Factory = new DexerV2Factory();
    }

    /*//////////////////////////////////////////////////////////////
                              Helpers
    //////////////////////////////////////////////////////////////*/
    function _getPairTokens(address pairAddress) internal view returns (address, address) {
        DexerV2Pair pair = DexerV2Pair(pairAddress);
        return (pair.token0(), pair.token1());
    }

    /*//////////////////////////////////////////////////////////////
                              CreatePair
    //////////////////////////////////////////////////////////////*/
    function testCreatePair() public {
        // Create pair for tokenA and tokenB
        address pairAddress = dexerV2Factory.createPair({tokenA: address(tokenA), tokenB: address(tokenB)});
        dexerV2Pair = DexerV2Pair(pairAddress);

        // Check it has been stored in factory mapping `pairs`
        address retrievedPair = dexerV2Factory.pairs(address(tokenA), address(tokenB));
        assertEq(pairAddress, retrievedPair, "Pair address should match the retrieved pair address.");

        // Check factory mapping with inverse token order
        retrievedPair = dexerV2Factory.pairs(address(tokenB), address(tokenA));
        assertEq(pairAddress, retrievedPair, "Pair address should match the retrieved pair address.");

        (address token0, address token1) = _getPairTokens({pairAddress: pairAddress});

        // Ensure tokens are initialized correctly
        // Ensure order (token0 < token1), `tokenA` and `tokenB` has been ordered during setup
        assertEq(token0, address(tokenA), "Token0 does not match expected");
        assertEq(token1, address(tokenB), "Token1 does not match expected");

        // Check it has been stored in `allPairs`
        assertEq(dexerV2Factory.allPairs(0), pairAddress, "`allPairs[0]` Should contain the newly created pair");
    }

    function testCreatePairInverseTokenOrder() public {
        // Create pair for tokenA and tokenB
        address pairAddress = dexerV2Factory.createPair({tokenA: address(tokenB), tokenB: address(tokenA)});
        dexerV2Pair = DexerV2Pair(pairAddress);

        // Check it has been stored in factory mapping `pairs`
        address retrievedPair = dexerV2Factory.pairs(address(tokenA), address(tokenB));
        assertEq(pairAddress, retrievedPair, "Pair address should match the retrieved pair address(A,B).");

        // Check factory mapping with inverse token order
        retrievedPair = dexerV2Factory.pairs(address(tokenB), address(tokenA));
        assertEq(pairAddress, retrievedPair, "Pair address should match the retrieved pair address(B,A).");

        (address token0, address token1) = _getPairTokens({pairAddress: pairAddress});

        // Ensure tokens are initialized correctly
        // Ensure order (token0 < token1), `tokenA` and `tokenB` has been ordered during setup
        assertEq(token0, address(tokenA), "Token0 does not match expected");
        assertEq(token1, address(tokenB), "Token1 does not match expected");

        // Check it has been stored in `allPairs`
        assertEq(dexerV2Factory.allPairs(0), pairAddress, "`allPairs[0]` Should contain the newly created pair");
    }

    function testCreatePairRevertsWithZeroAddress() public {
        vm.expectRevert(DexerV2Factory.DexerV2Factory__ZeroAddress.selector);
        dexerV2Factory.createPair({tokenA: address(0), tokenB: address(tokenB)});
    }

    function testCreatePairRevertsWithIdenticalAddresses() public {
        vm.expectRevert(DexerV2Factory.DexerV2Factory__IndeticalAddresses.selector);
        dexerV2Factory.createPair({tokenA: address(tokenB), tokenB: address(tokenB)});
    }

    function testCreatePairRevertsWithExistingPair() public {
        dexerV2Factory.createPair({tokenA: address(tokenA), tokenB: address(tokenB)}); // First deploy
        vm.expectRevert(DexerV2Factory.DexerV2Factory__ExistingPair.selector);
        dexerV2Factory.createPair({tokenA: address(tokenA), tokenB: address(tokenB)}); // 2nd deploy
    }

    function testCreateMultiplePairs() public {
        // Create multiple pairs
        address pairAB = dexerV2Factory.createPair({tokenA: address(tokenA), tokenB: address(tokenB)});
        address pairAC = dexerV2Factory.createPair({tokenA: address(tokenA), tokenB: address(tokenC)});

        // Verify correct index and order
        assertEq(dexerV2Factory.allPairs(0), pairAB, "First pair should be pairAB");
        assertEq(dexerV2Factory.allPairs(1), pairAC, "Second pair should be pairAC");

        // Check pairs mapping in both directions
        assertEq(dexerV2Factory.pairs(address(tokenA), address(tokenB)), pairAB, "pairs(tokenA,tokenB) mismatch");
        assertEq(dexerV2Factory.pairs(address(tokenB), address(tokenA)), pairAB, "pairs(tokenB,tokenA) mismatch");

        assertEq(dexerV2Factory.pairs(address(tokenA), address(tokenC)), pairAC, "pairs(tokenA,tokenC) mismatch");
        assertEq(dexerV2Factory.pairs(address(tokenC), address(tokenA)), pairAC, "pairs(tokenC,tokenA) mismatch");
    }
}
