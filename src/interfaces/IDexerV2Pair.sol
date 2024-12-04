// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDexerV2Pair is IERC20 {
    function initialize(address token0, address token1) external;

    function mint(address to) external returns (uint256 amountLPToken);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external;

    function getReserves() external view returns (uint256 reserve0, uint256 reserve1);
}
