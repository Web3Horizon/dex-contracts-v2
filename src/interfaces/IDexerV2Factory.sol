// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

interface IDexerV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}
