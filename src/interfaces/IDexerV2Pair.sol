// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IDexerV2Pair {
    /* **** Events **** */
    event Burn(address sender, uint256 amount0, uint256 amount1, address to);
    event Mint(address sender, uint256 amount0, uint256 amount1);
    event Swap(address indexed sender, uint256 amount0Out, uint256 amount1Out, address indexed to);

    /* **** Errors **** */
    error DexerV2pair__InsufficientLiquidityMint();
    error DexerV2pair__InsufficientLiquidityBurn();
    error DexerV2Pair__InsufficientOutputAmount();
    error DexerV2Pair__InsufficientInputAmount();
    error DexerV2Pair__InsufficientLiquidity();
    error DexerV2Pair__InvalidK();
    error DexerV2Pair__AlreadyInitialized();

    /* **** Functions **** */
    function initialize(address token0, address token1) external;

    function mint() external returns (uint256);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external;

    function getReserves() external view returns (uint256 reserve0, uint256 reserve1);
}
