// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IDexerV2Pair {
    function initialize(address token0, address token1) external;

    function mint() external returns (uint256);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external;

    function getReserves() external view returns (uint256 reserve0, uint256 reserve1);
}
