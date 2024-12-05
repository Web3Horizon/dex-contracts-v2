//// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IDexerV2Factory} from "src/interfaces/IDexerV2Factory.sol";
import {IDexerV2Pair} from "src/interfaces/IDexerV2Pair.sol";
import {DexerV2Library} from "src/libraries/DexerV2Library.sol";

contract DexerV2Router {
    using SafeERC20 for IDexerV2Pair;
    using SafeERC20 for IERC20;

    IDexerV2Factory public immutable i_factory;

    /*//////////////////////////////////////////////////////////////
                               Custom Errors
    //////////////////////////////////////////////////////////////*/
    error DexerV2Router__InsufficientAAmount();
    error DexerV2Router__InsufficientBAmount();
    error DexerV2Router__TransferFailed();
    error DexerV2Router__LiquidityCalculationFail();
    error DexerV2Router__InsufficientOutputAmount();

    constructor(address factoryAddress) {
        i_factory = IDexerV2Factory(factoryAddress);
    }

    /**
     * @notice The function to call to create a LP or add liquidity to an existing pool.
     *         It uses `_calculateLiquidity` to determine the optimal amount of tokens to add.
     *         It reverts if the pair contract creation fails or liquidity calculation cannot satisfy the minimum requirements.
     *
     * @dev Adds liquidity to an existing LP. If the pair contract does not exist it creates one by calling the factory contract.
     *      The function ensures that the added liquidity is balanced relative to the existing LP reserves and the user's desired amounts,
     *      while respecting the minimum constraints.
     *      The function calls the lower level core contracts `DexerV2Factory` to verify and create pair contracts
     *      The function calls the lower level core contract `DexerV2Pair` to add liquidity and mint LP tokens for the user.
     *
     * @param tokenA Address of the first token in the pair.
     * @param tokenB Address of the second token in the pair.
     * @param amountADesired The desired amount of tokenA to add as liquidity.
     * @param amountBDesired The desired amount of tokenB to add as liquidity.
     * @param amountAMin The minimum amount of tokenA that must be added (to prevent slippage).
     * @param amountBMin The minimum amount of tokenB that must be added (to prevent slippage).
     * @param to Address of the recipient for the liquidity tokens.
     *
     * @return amountA The final amount of tokenA that should be added as liquidity.
     * @return amountB The final amount of tokenB that should be added as liquidity.
     * @return amountLPToken The amount of LP tokens minted and sent to the user.
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) external returns (uint256 amountA, uint256 amountB, uint256 amountLPToken) {
        // Check if pair contract for this combination exists already, if not create one
        if (i_factory.pairs(tokenA, tokenB) == address(0)) {
            i_factory.createPair(tokenA, tokenB);
        }

        (amountA, amountB) = _calculateLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);

        // Get the pair address without an external conctract call.
        address pairAddress = DexerV2Library.pairFor(address(i_factory), tokenA, tokenB);

        // Transfer the tokens from the user to the pair contract.
        IERC20(tokenA).safeTransferFrom(msg.sender, pairAddress, amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, pairAddress, amountB);

        // Call the mint function in the pair contract
        amountLPToken = IDexerV2Pair(pairAddress).mint(to);

        return (amountA, amountB, amountLPToken);
    }

    /**
     * @notice The function to call to burn LP tokens and receive the share of pooled tokens.
     *         It reverts if the amount of returned tokens are below the specified minimum required.
     *
     * @dev Removes liquidity from an existing LP. The function burns the specified amount of LP tokens
     *      and sends the proportional amounts of tokenA and tokenB to the user.
     *      It ensures that the returned token amounts satisfy the minimum constraints specified by the user.
     *      The function calls the lower level core contract `DexerV2Pair` to remove liquidity and burn LP tokens for the user.
     *
     * @param tokenA Address of the first token in the pair.
     * @param tokenB Address of the second token in the pair.
     * @param amountLPToken The amount of LP tokens the user wants to burn.
     * @param amountAMin The minimum amount of tokenA that the user expects to receive from burning the LP tokens.
     * @param amountBMin The minimum amount of tokenB that the user expects to receive from burning the LP tokens.
     * @param to Address of the recipient for tokenA and tokenB tokens.
     *
     * @return amountA The amount of tokenA sent to the recipient as a result of the LP tokens burn.
     * @return amountB The amount of tokenB sent to the recipient as a result of the LP tokens burn.
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountLPToken,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) external returns (uint256 amountA, uint256 amountB) {
        address pair = DexerV2Library.pairFor({factoryAddress: address(i_factory), tokenA: tokenA, tokenB: tokenB});

        IDexerV2Pair(pair).safeTransferFrom(msg.sender, pair, amountLPToken);

        (amountA, amountB) = IDexerV2Pair(pair).burn(to);

        if (amountA < amountAMin) revert DexerV2Router__InsufficientAAmount();
        if (amountB < amountBMin) revert DexerV2Router__InsufficientBAmount();
    }

    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to)
        external
        returns (uint256[] memory amounts)
    {
        amounts = DexerV2Library.getAmountsOut(address(i_factory), amountIn, path);

        // Check if the final amountOut is more than the minimum amount expected
        if (amounts[amounts.length - 1] < amountOutMin) {
            revert DexerV2Router__InsufficientOutputAmount();
        }

        // Transfer the input token from the user to the pair contract
        IERC20(path[0]).safeTransferFrom(
            msg.sender,
            DexerV2Library.pairFor({factoryAddress: address(i_factory), tokenA: path[0], tokenB: path[1]}),
            amountIn
        );

        _swap(amounts, path, to);
    }

    // PAIR SWAP: (uint256 amount0Out, uint256 amount1Out, address to) external {

    function _swap(uint256[] memory amounts, address[] memory path, address _to) private {
        for (uint256 i; i < path.length - 1; i++) {
            // Define input and output tokens for the swap: Example tokenA -> tokenB -> tokenC
            // First interation input: tokenA -> output:tokenB
            // Second interation input: tokenB -> output: tokenC
            (address inputToken, address outputToken) = (path[i], path[i + 1]);

            // Sort tokens in each iteration (Needed for pair contract swap logic)
            (address token0,) = DexerV2Library.sortTokens({tokenA: inputToken, tokenB: outputToken});

            uint256 amountOut = amounts[i + 1];

            (uint256 amount0Out, uint256 amount1Out) =
                inputToken == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));

            // Define if we are sending tokens to a contract OR to the user if its the last swap
            address to = i < path.length - 2
                ? DexerV2Library.pairFor({factoryAddress: address(i_factory), tokenA: outputToken, tokenB: path[i + 2]})
                : _to;

            // Call the swap function in the pair contract
            IDexerV2Pair(
                DexerV2Library.pairFor({factoryAddress: address(i_factory), tokenA: inputToken, tokenB: outputToken})
            ).swap({amount0Out: amount0Out, amount1Out: amount1Out, to: to});
        }
    }

    /*//////////////////////////////////////////////////////////////
                              Private Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice This is a helper function to calculate optimal token amounts when calling `addLiquidity`.
     *
     * @dev Calculates the optimal amounts of tokenA and tokenB to add as liquidity.
     *         This function ensures that the token amounts are balanced relative to the pool reserves.
     *
     * @param tokenA Address of the first token in the pair.
     * @param tokenB Address of the second token in the pair.
     * @param amountADesired The desired amount of tokenA to add as liquidity.
     * @param amountBDesired The desired amount of tokenB to add as liquidity.
     * @param amountAMin The minimum amount of tokenA that must be added (to prevent slippage).
     * @param amountBMin The minimum amount of tokenB that must be added (to prevent slippage).
     *
     * @return amountA The final amount of tokenA that should be added as liquidity.
     * @return amountB The final amount of tokenB that should be added as liquidity.
     *
     * @custom:reverts DexerV2Router__InsufficientAAmount If the calculated amountA is less than the amountAMin.
     * @custom:reverts DexerV2Router__InsufficientBAmount If the calculated amountB is less than the amountBMin.
     * @custom:reverts DexerV2Router__LiquidityCalculationFail fallback error incase the calculation fails (should be unreacheable).
     */
    function _calculateLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) private view returns (uint256 amountA, uint256 amountB) {
        // Get reserves
        (uint256 reserveA, uint256 reserveB) = DexerV2Library.getReserves(address(i_factory), tokenA, tokenB);

        // Case 1:  If there are no reserves, we can add any ratio the user wants.
        if (reserveA == 0 && reserveB == 0) {
            return (amountADesired, amountBDesired);
        }

        // Case 2: Calculate optimal tokenB amount for the desired tokenA amount
        // Calculate the optimal amount of token B with the given amountA desired.
        uint256 amountBOptimal = DexerV2Library.quote(amountADesired, reserveA, reserveB);

        if (amountBOptimal <= amountBDesired) {
            // If the optimal amount is less than the minimum amount revert.
            if (amountBOptimal <= amountBMin) revert DexerV2Router__InsufficientBAmount();

            // Return the values
            return (amountADesired, amountBOptimal);
        }

        // Case 3: Calculate optimal tokenA amount for the desired tokenB amount
        // If we cant find suitable values in terms of tokenA, check for values in terms of tokenB (find optimal amount of tokenA for given tokenB)
        uint256 amountAOptimal = DexerV2Library.quote(amountBDesired, reserveA, reserveB);

        if (amountAOptimal <= amountADesired) {
            if (amountAOptimal <= amountAMin) revert DexerV2Router__InsufficientAAmount();

            // Return the values
            return (amountAOptimal, amountBDesired);
        }

        revert DexerV2Router__LiquidityCalculationFail();
    }
}
