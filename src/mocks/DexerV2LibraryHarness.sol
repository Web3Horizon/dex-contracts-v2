// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DexerV2Library} from "src/libraries/DexerV2Library.sol";

contract DexerV2LibraryHarness {
    function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1) {
        return DexerV2Library.sortTokens(tokenA, tokenB);
    }

    function pairFor(address factoryAddress, address tokenA, address tokenB) external pure returns (address pair) {
        return DexerV2Library.pairFor(factoryAddress, tokenA, tokenB);
    }

    function getReserves(address factoryAddress, address tokenA, address tokenB)
        external
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        return DexerV2Library.getReserves(factoryAddress, tokenA, tokenB);
    }

    function quote(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) external pure returns (uint256 amountOut) {
        return DexerV2Library.quote(amountIn, reserveIn, reserveOut);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        returns (uint256 amountOut)
    {
        return DexerV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountsOut(address factoryAddress, uint256 amountIn, address[] memory path)
        external
        view
        returns (uint256[] memory amounts)
    {
        return DexerV2Library.getAmountsOut(factoryAddress, amountIn, path);
    }
}
