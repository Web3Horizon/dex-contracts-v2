// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IDexerV2Pair} from "src/interfaces/IDexerV2Pair.sol";

contract DexerV2Pair is IDexerV2Pair, ERC20 {
    using SafeERC20 for IERC20;

    address public token0;
    address public token1;
    address public factory;

    uint256 private reserve0;
    uint256 private reserve1;

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
    error DexerV2Pair__Unauthorized();

    // Possibly change for dynamic naming in the future
    constructor() ERC20("DexerV2Pair", "DXRLP") {
        factory = msg.sender;
    }

    /**
     * @notice Sets the pair contract with the two token addresses.
     * @dev This function can only be called once to prevent reinitialization.
     *      Ensures that the token addresses are set for the contract and
     *      enforces that the contract has not been initialized already.
     * @param _token0 The address of the first token in the pair.
     * @param _token1 The address of the second token in the pair.
     * @custom:reverts DexerV2Pair__AlreadyInitialized If the contract has already been initialized with token addresses.
     */
    function initialize(address _token0, address _token1) external {
        if (token0 != address(0) || token1 != address(0)) {
            revert DexerV2Pair__AlreadyInitialized();
        }

        if (msg.sender != factory) {
            revert DexerV2Pair__Unauthorized();
        }

        token0 = _token0;
        token1 = _token1;
    }

    /**
     * @dev Mints LP tokens to the caller.
     * @return The amount of LP tokens minted.
     */
    function mint(address to) external returns (uint256) {
        // The balance after tokens have been sent
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        // The amount of tokens sent by the user
        uint256 amount0 = balance0 - reserve0;
        uint256 amount1 = balance1 - reserve1;

        uint256 liquidity;
        uint256 _totalSupply = totalSupply();

        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1);
        } else {
            // Get the minimum liquidity contribution
            uint256 liquidity0 = (_totalSupply * amount0) / reserve0;
            uint256 liquidity1 = (_totalSupply * amount1) / reserve1;
            liquidity = Math.min(liquidity0, liquidity1);
        }

        if (liquidity == 0) {
            revert DexerV2pair__InsufficientLiquidityMint();
        }

        // Mint tokens
        _mint(to, liquidity);

        // Update balances
        _update(balance0, balance1);

        // Event
        emit Mint(msg.sender, amount0, amount1);

        return liquidity;
    }

    /**
     * @dev Removes liquidity from the pool by burning LP tokens and transferring the corresponding
     *      amounts of token0 and token1 to the specified address.
     * @param to The address to receive the withdrawn amounts of token0 and token1.
     * @return amount0 The amount of token0 transferred to the `to` address.
     * @return amount1 The amount of token1 transferred to the `to` address.
     */
    function burn(address to) external returns (uint256 amount0, uint256 amount1) {
        address _token0 = token0;
        address _token1 = token1;
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));

        uint256 poolLPTokens = balanceOf(address(this));

        if (poolLPTokens == 0) {
            revert DexerV2pair__InsufficientLiquidityBurn();
        }

        uint256 _totalSupply = totalSupply();
        uint256 amount0ToTransfer = (poolLPTokens * balance0) / _totalSupply;
        uint256 amount1ToTransfer = (poolLPTokens * balance1) / _totalSupply;

        _burn(address(this), poolLPTokens);

        // Transfer tokens
        IERC20(_token0).safeTransfer(to, amount0ToTransfer);
        IERC20(_token1).safeTransfer(to, amount1ToTransfer);

        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        // Update reserves
        _update(balance0, balance1);

        emit Burn(msg.sender, amount0ToTransfer, amount1ToTransfer, to);

        return (amount0ToTransfer, amount1ToTransfer);
    }

    /**
     * @notice Executes a swap of tokens by transferring specified output amounts
     *         of token0 and token1 to the given address, ensuring the invariant
     *         is maintained.
     * @dev The function reverts if the output amounts are invalid or exceed reserves.
     * @param amount0Out The amount of token0 to be sent to the recipient.
     * @param amount1Out The amount of token1 to be sent to the recipient.
     * @param to The address receiving the output tokens.
     * @custom:reverts DexerV2Pair__InsufficientOutputAmount If both output amounts are zero.
     * @custom:reverts DexerV2Pair__InsufficientLiquidity If output amounts exceed available reserves.
     * @custom:reverts DexerV2Pair__InsufficientInputAmount If no input tokens are provided to balance the swap.
     * @custom:reverts DexerV2Pair__InvalidK If the invariant constant is violated after the swap.
     */
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external {
        if (amount0Out == 0 && amount1Out == 0) {
            revert DexerV2Pair__InsufficientOutputAmount();
        }

        (uint256 _reserve0, uint256 _reserve1) = getReserves();

        // Ensure enough reserves
        if (amount0Out > _reserve0 || amount1Out > _reserve1) {
            revert DexerV2Pair__InsufficientLiquidity();
        }

        address _token0 = token0;
        address _token1 = token1;

        // Optimiscally transfer tokens
        if (amount0Out > 0) IERC20(_token0).safeTransfer(to, amount0Out);
        if (amount1Out > 0) IERC20(_token1).safeTransfer(to, amount1Out);

        // Balances after the transfer
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));

        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;

        if (amount0In == 0 && amount1In == 0) {
            revert DexerV2Pair__InsufficientInputAmount();
        }

        // Balance after swap - swap fee 0.3%
        uint256 balance0Adjusted = (balance0 * 1000) - (amount0In * 3);
        uint256 balance1Adjusted = (balance1 * 1000) - (amount1In * 3);

        // Verify the invariant contant (k)
        if (balance0Adjusted * balance1Adjusted < _reserve0 * _reserve1 * (1000 ** 2)) {
            revert DexerV2Pair__InvalidK();
        }

        _update({balance0: balance0, balance1: balance1});

        emit Swap({sender: msg.sender, amount0Out: amount0Out, amount1Out: amount1Out, to: to});
    }

    /* **** Getter functions **** */

    /**
     * @notice Retrieves the last recorded reserves of token0 and token1 in the liquidity pool.
     * @dev The reserves represent the pool's state after the most recent mint, burn, or swap operation.
     *      They may differ from the actual token balances in the contract, as reserves are updated only
     *      through these operations and not through direct token transfers.
     * @return reserve0 The last updated reserve amount of token0 in the pool.
     * @return reserve1 The last updated reserve amount of token1 in the pool.
     */
    function getReserves() public view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }

    /* **** Private functions **** */

    /**
     * @notice Updates the reserve values for token0 and token1 in the liquidity pool.
     * @dev This function is called internally to synchronize the reserves with the current
     *      balances of token0 and token1 held by the contract. It does not perform any validation
     *      or balance checks and assumes that the provided balances are accurate and up-to-date.
     * @param balance0 The new balance of token0 to update the reserve.
     * @param balance1 The new balance of token1 to update the reserve.
     */
    function _update(uint256 balance0, uint256 balance1) private {
        reserve0 = balance0;
        reserve1 = balance1;
    }
}
