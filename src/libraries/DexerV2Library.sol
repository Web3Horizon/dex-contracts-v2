// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IDexerV2Pair} from "src/interfaces/IDexerV2Pair.sol";
import {DexerV2Pair} from "src/DexerV2Pair.sol";

library DexerV2Library {
    error DexerV2Library__InsufficientAmount();
    error DexerV2Library__InsufficientLiquidity();
    error DexerV2Library__InvalidPath();

    /**
     * @notice Fetches the reserves of a token pair from the liquidity pool.
     *         Returns the reserves in the same order as the provided token addresses.
     *
     * @dev This function retrieves the reserves of `tokenA` and `tokenB` from the corresponding
     *      pair contract in the specified factory. It ensures that the reserves are returned
     *      in the correct order matching `tokenA` and `tokenB`.
     * @dev The function calls `sortTokens` to ensure consistent token order, then retrieves
     *         reserves from the pair contract using `pairFor` and `getReserves`.
     *         It reverts if the pair contract does not exist or the `getReserves` function fails.
     *
     * @param factoryAddress The address of the factory contract that manages the liquidity pairs.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     *
     * @return reserveA The reserve of `tokenA` in the liquidity pool.
     * @return reserveB The reserve of `tokenB` in the liquidity pool.
     */
    function getReserves(address factoryAddress, address tokenA, address tokenB)
        internal
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        // Determine which token is token0 and token1
        (address token0, address token1) = sortTokens(tokenA, tokenB);

        // Get the reserves of the tokens in the pair contract
        (uint256 reserve0, uint256 reserve1) = IDexerV2Pair(pairFor(factoryAddress, token0, token1)).getReserves();

        // Sort the tokens to return them in the order of the parameter inputs
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /**
     * @notice This function is called for managing liquidity only, not swaps.
     *
     * @notice Calculates the optimal amount of the second token to add to a liquidity pool
     *         to maintain balance, given the amount of the first token being added and the
     *         reserves of both tokens in the pool.
     *
     * @dev This function is a pure utility that uses the formula:
     *      `amountOut = (amountIn * reserveOut) / reserveIn`.
     *      It reverts if the input amount is zero or if either of the reserves is zero.
     *
     * @param amountIn The amount of the first token being added to the liquidity pool.
     * @param reserveIn The current reserve of the first token in the liquidity pool.
     * @param reserveOut The current reserve of the second token in the liquidity pool.
     *
     * @return amountOtherTokenToAdd The calculated optimal amount of the second token to add to the pool.
     *
     * @notice Reverts with `DexerV2Library__InsufficientAmount` if `amountIn` is zero.
     *         Reverts with `DexerV2Library__InsufficientLiquidity` if either `reserveIn` or `reserveOut` is zero.
     */
    function quote(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOtherTokenToAdd)
    {
        // If no amountIn is provided, we cant calculate the amountOut
        if (amountIn == 0) revert DexerV2Library__InsufficientAmount();

        // If there are no reserves, revert
        if (reserveIn == 0 || reserveOut == 0) revert DexerV2Library__InsufficientLiquidity();

        uint256 numerator = amountIn * reserveOut;

        uint256 denominator = reserveIn;

        amountOtherTokenToAdd = numerator / denominator;

        return amountOtherTokenToAdd;
    }

    /**
     * @notice Calculates the amount of output tokens based on the input token amount
     *         and the reserves of both of the tokens in a liquidity pool.
     *
     * @dev This function is a pure utility that uses the formula:
     *      `amountOut = (amountInWithFee * reserveOut) / reserveIn + amountInWithFee`.
     *      It reverts if the input amount is zero or if either of the reserves is zero.
     *
     * @param amountIn The amount of input tokens being provided.
     * @param reserveIn The reserve amount of the input token in the liquidity pool.
     * @param reserveOut The reserve amount of the output token in the liquidity pool.
     *
     * @return amountOut The calculated amount of output tokens based on the given reserves and `amountIn`.
     *
     * @notice Reverts with `DexerV2Library__InsufficientAmount` if `amountIn` is zero.
     *         Reverts with `DexerV2Library__InsufficientLiquidity` if either `reserveIn` or `reserveOut` is zero.
     */
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        // If no amountIn is provided, we cant calculate the amountOut
        if (amountIn == 0) revert DexerV2Library__InsufficientAmount();

        // If there are no reserves, revert
        if (reserveIn == 0 || reserveOut == 0) revert DexerV2Library__InsufficientLiquidity();

        // No decimals in solidity so we multiply by 997 then divide by 1000 to get the 0.3% fee
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;

        amountOut = numerator / denominator;
        return amountOut;
    }

    /**
     * @notice Calculates the amount of input tokens required to obtain a specific output token amount
     *         based on the reserves of both tokens in a liquidity pool.
     *
     * @dev This function is a pure utility that uses the formula:
     *      `amountIn = (amountOut * reserveIn * 1000) / ((reserveOut * 997) - amountOut)`.
     *      It reverts if the output amount is zero or if either of the reserves is zero.
     *
     * @param amountOut The desired amount of output tokens.
     * @param reserveIn The reserve amount of the input token in the liquidity pool.
     * @param reserveOut The reserve amount of the output token in the liquidity pool.
     *
     * @return amountIn The calculated amount of input tokens required to obtain the given `amountOut`.
     *
     * @notice Reverts with `DexerV2Library__InsufficientAmount` if `amountOut` is zero.
     *         Reverts with `DexerV2Library__InsufficientLiquidity` if either `reserveIn` or `reserveOut` is zero.
     */
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountIn)
    {
        // If no amountOut is provided, we cant calculate the amountIn
        if (amountOut == 0) revert DexerV2Library__InsufficientAmount();

        // If there are no reserves, revert
        if (reserveIn == 0 || reserveOut == 0) revert DexerV2Library__InsufficientLiquidity();

        uint256 numerator = amountOut * (reserveIn * 1000);
        uint256 denominator = (reserveOut * 997) - amountOut;

        amountIn = numerator / denominator;
        return amountIn;
    }

    /**
     * @notice This function performs a chain call of `getAmountIn` for pairs in the `path`.
     *
     * @dev This function performs a chain call of `getAmountIn` for pairs in the `path`.
     *         It populates the last element of the return array with `amountOut`,
     *         and the first element is the amount of input tokens of the first swap, the required input token.
     *
     * @param factoryAddress The address of the factory contract.
     * @param amountOut The desired amount of output tokens for the user to receive (`path[length - 1]`).
     * @param path An array of token addresses indicating the path to take for swaps.
     *           path[0] is the input token provided by the user.
     *           path[length - 1] is the token to be received by the user.
     *
     * @return amountsIn An array of calculated amounts of input tokens required for each given pair of tokens in the `path`.
     *
     * @custom:reverts DexerV2Library__InvalidPath if the `path` does not contain at least two addresses.
     *
     */
    function getAmountsIn(address factoryAddress, uint256 amountOut, address[] memory path)
        internal
        view
        returns (uint256[] memory amountsIn)
    {
        // Path length should be more than two
        if (path.length < 2) revert DexerV2Library__InvalidPath();

        // Initiate a new array to store amountIn for each swap
        amountsIn = new uint256[](path.length);

        // Set the last element as the amountOut
        amountsIn[amountsIn.length - 1] = amountOut;

        // Iterate through the whole path array and get the amountOut for each swap
        for (uint256 i = path.length - 1; i > 0; i--) {
            // Get the reserves of the current two tokens in the iteration
            (uint256 reserveIn, uint256 reserveOut) =
                getReserves({factoryAddress: factoryAddress, tokenA: path[i - 1], tokenB: path[1]});

            // Set the amountOut for the current token pair in the itaration
            amountsIn[i - 1] = getAmountIn({amountOut: amountsIn[i], reserveIn: reserveIn, reserveOut: reserveOut});
        }

        return amountsIn;
    }

    /**
     * @notice This function performs a chain call of `getAmountOut` for pairs in the `path`.
     *
     * @dev This function performs a chain call of `getAmountOut` for pairs in the `path`.
     *         It populates the first element of the return array with `amountIn`,
     *         and the last element is the amount of output tokens of the last swap, the desired output token.
     *
     * @param factoryAddress The address of the factory contract.
     * @param amountIn The amount of tokens to the user wants wants to swap path[0].
     * @param path An array of token addresses indicating the path to take for swaps.
     *           path[0] is the token sent from the user.
     *           path[length - 1] is the end token for the user to receive.
     *
     * @return amountsOut An array of calculated amount of output tokens for each given pair of tokens in the `path`.
     *
     * @custom:reverts DexerV2Library__InvalidPath if the `path` does not contain at least two addresses.
     *
     */
    function getAmountsOut(address factoryAddress, uint256 amountIn, address[] memory path)
        internal
        view
        returns (uint256[] memory amountsOut)
    {
        // Path length should be more than two
        if (path.length < 2) revert DexerV2Library__InvalidPath();

        // Initiate a new array to store amountOut for each swap
        amountsOut = new uint256[](path.length);

        // Set the first element as the amountIn defined by the user
        amountsOut[0] = amountIn;

        // Iterate through the whole path array and get the amountOut for each swap
        for (uint256 i; i < path.length - 1; i++) {
            // Get the reserves of the current two tokens in the iteration
            (uint256 reserveIn, uint256 reserveOut) =
                getReserves({factoryAddress: factoryAddress, tokenA: path[i], tokenB: path[i + 1]});

            // Set the amountOut for the current token pair in the itaration
            amountsOut[i + 1] = getAmountOut({amountIn: amountsOut[i], reserveIn: reserveIn, reserveOut: reserveOut});
        }

        return amountsOut;
    }

    /**
     * @notice A helper function to determine which of `tokenA` or `tokenB` is `token0` and `token1` respectively.
     *
     * @dev This function returns the two token addresses in ascending order.
     *      This is how the `DexerV2Pair` contract assigns token0 and token1.
     *
     * @param tokenA The address of the first token.
     * @param tokenB The address of the second token.
     *
     * @return token0 The address of the token that comes first (the smaller address).
     * @return token1 The address of the token that comes second (the larger address).
     *
     * @notice The function does not perform any checks to validate whether the addresses are valid tokens.
     *         It assumes that `tokenA` and `tokenB` are distinct addresses.
     */
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    /**
     * @notice Calculates the deterministic address of a pair contract for a given token pair and factory contract address.
     *          This function does not check if the pair contract exists; it simply computes the address.
     *
     * @notice
     * - The function uses `sortTokens` to ensure the tokens are always in the same order (`token0` and `token1`).
     * - The deterministic address is computed using the `CREATE2` address derivation formula:
     *   `pairAddress = address(keccak256(abi.encodePacked(hex"ff", factory, keccak256(token0, token1), initCodeHash)))`.
     *
     * @dev This function uses the `CREATE2` opcode deterministic address calculation to compute the address of the
     *      pair contract without deploying it. The address is calculated based on the factory address, the sorted
     *      token addresses, and the creation bytecode of the pair contract (`DexerV2Pair`).
     *
     * @dev We use this method to calculate the address instead of simply calling `DexerV2Factory(factoryAddress).pairs(tokenA, tokenB)`
     *      which would result on an external call, to save on gas costs.
     *
     * @param factoryAddress The address of the factory contract.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     *
     * @return pairAddress The deterministic address of the pair contract for the given token pair.
     */
    function pairFor(address factoryAddress, address tokenA, address tokenB)
        internal
        pure
        returns (address pairAddress)
    {
        // Sort tokens for consistency
        (address token0, address token1) = sortTokens(tokenA, tokenB);

        // Compute the deterministic address by following the `CREATE2` approach (CREATE2 is used in the `DexerV2Factory` contract)
        return pairAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factoryAddress,
                            keccak256(abi.encodePacked(token0, token1)),
                            keccak256(type(DexerV2Pair).creationCode)
                        )
                    )
                )
            )
        );
    }
}
