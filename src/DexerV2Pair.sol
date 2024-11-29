// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/* **** Errors **** */

contract DexerV2Pair is ERC20 {
    address public token0;
    address public token1;

    uint256 private reserve0;
    uint256 private reserve1;

    /* **** Events **** */
    event Burn(address sender, uint256 amount0, uint256 amount1, address to);
    event Mint(address sender, uint256 amount0, uint256 amount1);

    /* **** Errors **** */
    error InsufficientLiquidityMint();
    error InsufficientLiquidityBurn();

    // Possibly change for dynamic naming in the future
    constructor(address _token0, address _token1) ERC20("DexerV2Pair", "DXRLP") {
        token0 = _token0;
        token1 = _token1;
    }

    /**
     * @dev Mints LP tokens to the caller.
     * @return The amount of LP tokens minted.
     */
    function mint() public returns (uint256) {
        // The balance after tokens have been sent
        uint256 balance0 = ERC20(token0).balanceOf(address(this));
        uint256 balance1 = ERC20(token1).balanceOf(address(this));

        // The amount of tokens sent by the user
        uint256 amount0 = balance0 - reserve0;
        uint256 amount1 = balance1 - reserve1;

        uint256 liquidity;

        if (totalSupply() == 0) {
            liquidity = Math.sqrt(amount0 * amount1);
        } else {
            // Get the minimum liquidity contribution
            uint256 liquidity0 = (totalSupply() * amount0) / reserve0;
            uint256 liquidity1 = (totalSupply() * amount1) / reserve1;
            liquidity = Math.min(liquidity0, liquidity1);
        }

        if (liquidity == 0) {
            revert InsufficientLiquidityMint();
        }

        // Mint tokens
        _mint(msg.sender, liquidity);

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
    function burn(address to) public returns (uint256 amount0, uint256 amount1) {
        uint256 balance0 = ERC20(token0).balanceOf(address(this));
        uint256 balance1 = ERC20(token1).balanceOf(address(this));

        uint256 poolLPTokens = balanceOf(address(this));

        if (poolLPTokens == 0) {
            revert InsufficientLiquidityBurn();
        }

        uint256 amount0ToTransfer = (poolLPTokens * balance0) / totalSupply();
        uint256 amount1ToTransfer = (poolLPTokens * balance1) / totalSupply();

        _burn(msg.sender, poolLPTokens);

        // Transfer tokens
        ERC20(token0).transfer(to, amount0ToTransfer);
        ERC20(token1).transfer(to, amount1ToTransfer);

        balance0 = ERC20(token0).balanceOf(address(this));
        balance1 = ERC20(token1).balanceOf(address(this));

        // Update reserves
        _update(balance0, balance1);

        emit Burn(msg.sender, amount0ToTransfer, amount1ToTransfer, to);

        return (amount0ToTransfer, amount1ToTransfer);
    }

    /* **** Getter functions **** */
    function getReserves() public view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }

    /* **** Private functions **** */

    function _update(uint256 balance0, uint256 balance1) private {
        reserve0 = balance0;
        reserve1 = balance1;
    }
}
