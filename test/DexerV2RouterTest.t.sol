// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DexerV2Pair} from "src/DexerV2Pair.sol";
import {IDexerV2Pair} from "src/interfaces/IDexerV2Pair.sol";
import {DexerV2Factory} from "src/DexerV2Factory.sol";
import {DexerV2Router} from "src/DexerV2Router.sol";
import {DexerV2Library} from "src/libraries/DexerV2Library.sol";
import {MockERC20} from "src/mocks/MockERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract DexerV2RouterTest is Test {
    address USER;
    address LIQUIDITY_USER;
    MockERC20 tokenA;
    MockERC20 tokenB;
    MockERC20 tokenC;
    uint256 STARTING_BALANCE = 100 ether;
    DexerV2Pair dexerV2Pair;
    DexerV2Factory dexerV2Factory;
    DexerV2Router dexerV2Router;

    function setUp() external {
        // USERs
        USER = makeAddr("user");
        LIQUIDITY_USER = makeAddr("user2");

        // Labels to facilitate testing
        vm.label(USER, "User");
        vm.label(LIQUIDITY_USER, "Liquidity user");

        // Create mock tokens
        MockERC20 token0 = new MockERC20("Token0", "TKN0");
        MockERC20 token1 = new MockERC20("Token1", "TKN1");
        MockERC20 token2 = new MockERC20("Token2", "TKN2");

        // Sort tokens to facilitate testing
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }
        if (address(token1) > address(token2)) {
            (token1, token2) = (token2, token1);
        }
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        // Assign sorted tokens, tokenA < tokenB < tokenC
        tokenA = token0;
        tokenB = token1;
        tokenC = token2;

        // Deploy factory and router contract
        dexerV2Factory = new DexerV2Factory();
        dexerV2Router = new DexerV2Router({factoryAddress: address(dexerV2Factory)});

        // Deal ether and mint `tokenA`, `tokenB` and `tokenC` to users.
        vm.deal(USER, STARTING_BALANCE);
        vm.deal(LIQUIDITY_USER, STARTING_BALANCE);
        tokenA.mint(USER, STARTING_BALANCE);
        tokenB.mint(USER, STARTING_BALANCE);
        tokenC.mint(USER, STARTING_BALANCE);
        tokenA.mint(LIQUIDITY_USER, STARTING_BALANCE);
        tokenB.mint(LIQUIDITY_USER, STARTING_BALANCE);
        tokenC.mint(LIQUIDITY_USER, STARTING_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                              Helpers
    //////////////////////////////////////////////////////////////*/
    function _assertReserves(uint256 expectedReserve0, uint256 expectedReserve1) internal view {
        (uint256 reserve0, uint256 reserve1) = dexerV2Pair.getReserves();
        assertApproxEqRel(reserve0, expectedReserve0, 1e15, "Unexpected reserve0"); // 1e15 = 0.1%
        assertApproxEqRel(reserve1, expectedReserve1, 1e15, "Unexpected reserve1");
    }

    /*//////////////////////////////////////////////////////////////
                              MODIFIER
    //////////////////////////////////////////////////////////////*/
    modifier withLiquidity() {
        address tokenAAddress = address(tokenA);
        address tokenBAddress = address(tokenB);
        uint256 amountADesired = 1 ether;
        uint256 amountBDesired = 10 ether;
        uint256 amountAMin = 1 ether;
        uint256 amountBMin = 10 ether;
        address to = LIQUIDITY_USER;

        vm.startPrank(LIQUIDITY_USER);

        // Approve token expenditure
        tokenA.approve(address(dexerV2Router), amountADesired);
        tokenB.approve(address(dexerV2Router), amountBDesired);

        // Add liquidity
        dexerV2Router.addLiquidity({
            tokenA: tokenAAddress,
            tokenB: tokenBAddress,
            amountADesired: amountADesired,
            amountBDesired: amountBDesired,
            amountAMin: amountAMin,
            amountBMin: amountBMin,
            to: to
        });

        vm.stopPrank();
        _;
    }

    modifier withAllowance() {
        // Allowance for LIQUIDITY_USER
        vm.startPrank(LIQUIDITY_USER);

        tokenA.approve(address(dexerV2Router), type(uint256).max);
        tokenB.approve(address(dexerV2Router), type(uint256).max);
        tokenC.approve(address(dexerV2Router), type(uint256).max);

        vm.stopPrank();

        // Allowance for USER
        vm.startPrank(USER);

        tokenA.approve(address(dexerV2Router), type(uint256).max);
        tokenB.approve(address(dexerV2Router), type(uint256).max);
        tokenC.approve(address(dexerV2Router), type(uint256).max);

        vm.stopPrank();

        _;
    }

    /*//////////////////////////////////////////////////////////////
                              addLiquidity
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that addLiquidity creates a pair contract if it doesnt exist, and adds liquidity.
    function testAddLiquidityCreatesPairAndAddsLiquidity() public withAllowance {
        address tokenAAddress = address(tokenA);
        address tokenBAddress = address(tokenB);
        uint256 amountADesired = 1 ether;
        uint256 amountBDesired = 10 ether;
        uint256 amountAMin = 1 ether;
        uint256 amountBMin = 10 ether;
        address to = USER;

        // Assert pair does not exist
        address pairAddress = dexerV2Factory.pairs(tokenAAddress, tokenBAddress);
        assertEq(pairAddress, address(0), "Pair should not exist");

        vm.startPrank(USER);

        // Add liquidity
        (uint256 amountA, uint256 amountB, uint256 lp) = dexerV2Router.addLiquidity({
            tokenA: tokenAAddress,
            tokenB: tokenBAddress,
            amountADesired: amountADesired,
            amountBDesired: amountBDesired,
            amountAMin: amountAMin,
            amountBMin: amountBMin,
            to: to
        });

        vm.stopPrank();

        // Assert the pair has been created
        pairAddress = dexerV2Factory.pairs(tokenAAddress, tokenBAddress);
        assertNotEq(pairAddress, address(0), "Pair contract for `tokenA and `tokenB` should have been created");

        dexerV2Pair = DexerV2Pair(pairAddress);

        // Assert return values
        assertEq(amountA, amountADesired, "AmountA should match amountADesired");
        assertEq(amountB, amountBDesired, "AmountB should match amountBDesired");
        assertEq(lp, Math.sqrt(amountA * amountB));

        // Assert reserves are equal to deposited amount
        _assertReserves(amountA, amountB);

        // assert LP token has been transfered to the user
        assertEq(lp, DexerV2Pair(pairAddress).balanceOf(to), "LP tokens should be minted to specified address `to`");
    }

    /// @notice Test addLiquidity to an existing pool
    function testAddLiquidityExistingPool() public withLiquidity withAllowance {
        uint256 amountADesired = 2 ether;
        uint256 amountBDesired = 20 ether;
        // address to = USER;

        // Get pair address
        dexerV2Pair = DexerV2Pair(dexerV2Factory.pairs(address(tokenA), address(tokenB)));

        // Get reserves before adding liquidity
        (uint256 reserveABefore, uint256 reserveBBefore) = dexerV2Pair.getReserves();

        // Get USER balances before adding liquidity
        uint256 userTokenABefore = tokenA.balanceOf(USER);
        uint256 userTokenBBefore = tokenB.balanceOf(USER);
        uint256 toLPBefore = dexerV2Pair.balanceOf(USER);

        vm.startPrank(USER);

        // Add liquidity
        (uint256 amountA, uint256 amountB, uint256 lp) = dexerV2Router.addLiquidity({
            tokenA: address(tokenA),
            tokenB: address(tokenB),
            amountADesired: amountADesired,
            amountBDesired: amountBDesired,
            amountAMin: amountADesired,
            amountBMin: amountBDesired,
            to: USER
        });

        vm.stopPrank();

        // Assert return values
        assertEq(amountA, amountADesired, "AmountA should match amountADesired");
        assertEq(amountB, amountBDesired, "AmountB should match amountBDesired");

        // Assert pair reserves increased
        _assertReserves({expectedReserve0: reserveABefore + amountA, expectedReserve1: reserveBBefore + amountB});

        // Assert USER's token balances decreased
        uint256 userTokenAAfter = tokenA.balanceOf(USER);
        uint256 userTokenBAfter = tokenB.balanceOf(USER);

        assertEq(userTokenAAfter, userTokenABefore - amountA, "Incorrect USER `tokenA` balance after adding liquidity");
        assertEq(userTokenBAfter, userTokenBBefore - amountB, "Incorrect USER `tokenB` balance after adding liquidity");

        // Assert specified `to` LP token increased
        uint256 toLPAfter = dexerV2Pair.balanceOf(USER);

        assertEq(toLPAfter, toLPBefore + lp, "Incorrect `to` LP token balance after adding liquidity");
    }

    function testAddLiquidityUnbalancedAmountB() public withLiquidity withAllowance {
        // Get pair address
        dexerV2Pair = DexerV2Pair(dexerV2Factory.pairs(address(tokenA), address(tokenB)));

        // Get reserves before adding liquidity
        (uint256 reserveABefore, uint256 reserveBBefore) = dexerV2Pair.getReserves();

        // Get USER balances before adding liquidity
        uint256 userTokenABefore = tokenA.balanceOf(USER);
        uint256 userTokenBBefore = tokenB.balanceOf(USER);
        uint256 toLPBefore = dexerV2Pair.balanceOf(USER);

        vm.startPrank(USER);

        // Add liquidity
        (uint256 amountA, uint256 amountB, uint256 lp) = dexerV2Router.addLiquidity({
            tokenA: address(tokenA),
            tokenB: address(tokenB),
            amountADesired: 1 ether,
            amountBDesired: 15 ether, // Overshoot
            amountAMin: 1 ether,
            amountBMin: 10 ether,
            to: USER
        });

        vm.stopPrank();

        // Assert return values
        assertEq(amountA, 1 ether, "Unexpected amountA added");
        assertEq(amountB, 10 ether, "Unexpected amountB added");

        // Assert pair reserves increased
        _assertReserves({expectedReserve0: reserveABefore + amountA, expectedReserve1: reserveBBefore + amountB});

        // Assert USER's token balances decreased
        uint256 userTokenAAfter = tokenA.balanceOf(USER);
        uint256 userTokenBAfter = tokenB.balanceOf(USER);

        assertEq(userTokenAAfter, userTokenABefore - amountA, "Incorrect USER `tokenA` balance after adding liquidity");
        assertEq(userTokenBAfter, userTokenBBefore - amountB, "Incorrect USER `tokenB` balance after adding liquidity");

        // Assert specified `to` LP token increased
        uint256 toLPAfter = dexerV2Pair.balanceOf(USER);

        assertEq(toLPAfter, toLPBefore + lp, "Incorrect `to` LP token balance after adding liquidity");
    }

    function testAddLiquidityUnbalancedAmountA() public withLiquidity withAllowance {
        // Get pair address
        dexerV2Pair = DexerV2Pair(dexerV2Factory.pairs(address(tokenA), address(tokenB)));

        // Get reserves before adding liquidity
        (uint256 reserveABefore, uint256 reserveBBefore) = dexerV2Pair.getReserves();

        // Get USER balances before adding liquidity
        uint256 userTokenABefore = tokenA.balanceOf(USER);
        uint256 userTokenBBefore = tokenB.balanceOf(USER);
        uint256 toLPBefore = dexerV2Pair.balanceOf(USER);

        vm.startPrank(USER);

        // Add liquidity
        (uint256 amountA, uint256 amountB, uint256 lp) = dexerV2Router.addLiquidity({
            tokenA: address(tokenA),
            tokenB: address(tokenB),
            amountADesired: 1.5 ether, // overshoot
            amountBDesired: 10 ether,
            amountAMin: 1 ether,
            amountBMin: 10 ether,
            to: USER
        });

        vm.stopPrank();

        // Assert return values
        assertEq(amountA, 1 ether, "Unexpected amountA added");
        assertEq(amountB, 10 ether, "Unexpected amountB added");

        // Assert pair reserves increased
        _assertReserves({expectedReserve0: reserveABefore + amountA, expectedReserve1: reserveBBefore + amountB});

        // Assert USER's token balances decreased
        uint256 userTokenAAfter = tokenA.balanceOf(USER);
        uint256 userTokenBAfter = tokenB.balanceOf(USER);

        assertEq(userTokenAAfter, userTokenABefore - amountA, "Incorrect USER `tokenA` balance after adding liquidity");
        assertEq(userTokenBAfter, userTokenBBefore - amountB, "Incorrect USER `tokenB` balance after adding liquidity");

        // Assert specified `to` LP token increased
        uint256 toLPAfter = dexerV2Pair.balanceOf(USER);

        assertEq(toLPAfter, toLPBefore + lp, "Incorrect `to` LP token balance after adding liquidity");
    }

    /* ******** Reverts ******** */

    function testAddLiquidityRevertsIfZeroAmountADesired() public withLiquidity withAllowance {
        address tokenAAddress = address(tokenA);
        address tokenBAddress = address(tokenB);
        uint256 amountADesired = 0 ether;
        uint256 amountBDesired = 9 ether;
        uint256 amountAMin = 1 ether;
        uint256 amountBMin = 9 ether;
        address to = USER;

        vm.startPrank(USER);

        vm.expectRevert(DexerV2Library.DexerV2Library__InsufficientAmount.selector);
        // Add liquidity
        dexerV2Router.addLiquidity({
            tokenA: tokenAAddress,
            tokenB: tokenBAddress,
            amountADesired: amountADesired,
            amountBDesired: amountBDesired,
            amountAMin: amountAMin,
            amountBMin: amountBMin,
            to: to
        });

        vm.stopPrank();
    }

    function testAddLiquidityRevertsIfZeroAmountBDesired() public withLiquidity withAllowance {
        address tokenAAddress = address(tokenA);
        address tokenBAddress = address(tokenB);
        uint256 amountADesired = 1 ether;
        uint256 amountBDesired = 0 ether;
        uint256 amountAMin = 1 ether;
        uint256 amountBMin = 9 ether;
        address to = USER;

        vm.startPrank(USER);

        vm.expectRevert(DexerV2Library.DexerV2Library__InsufficientAmount.selector);
        // Add liquidity
        dexerV2Router.addLiquidity({
            tokenA: tokenAAddress,
            tokenB: tokenBAddress,
            amountADesired: amountADesired,
            amountBDesired: amountBDesired,
            amountAMin: amountAMin,
            amountBMin: amountBMin,
            to: to
        });

        vm.stopPrank();
    }

    function testAddLiquidityRevertsIfAmountBMinNotMet() public withLiquidity withAllowance {
        address tokenAAddress = address(tokenA);
        address tokenBAddress = address(tokenB);
        uint256 amountADesired = 1 ether;
        uint256 amountBDesired = 10 ether;
        uint256 amountAMin = 1 ether;
        uint256 amountBMin = 11 ether; // too high
        address to = USER;

        vm.startPrank(USER);

        vm.expectRevert(DexerV2Router.DexerV2Router__InsufficientBAmount.selector);
        // Add liquidity
        dexerV2Router.addLiquidity({
            tokenA: tokenAAddress,
            tokenB: tokenBAddress,
            amountADesired: amountADesired,
            amountBDesired: amountBDesired,
            amountAMin: amountAMin,
            amountBMin: amountBMin,
            to: to
        });

        vm.stopPrank();
    }

    function testAddLiquidityRevertsIfAmountAMinNotMet() public withLiquidity withAllowance {
        address tokenAAddress = address(tokenA);
        address tokenBAddress = address(tokenB);
        uint256 amountADesired = 1 ether;
        uint256 amountBDesired = 9 ether;
        uint256 amountAMin = 1 ether;
        uint256 amountBMin = 9 ether;
        address to = USER;

        /* 
        ADesired(1): optimalB(10) > desiredB(9) NOT OK

        BDesired(9): optimalA(0.9) <=desiredA(1) OK
            BDesired(9): optimalA(0.9) > MinA(1) NOT OK

        */

        vm.startPrank(USER);

        vm.expectRevert(DexerV2Router.DexerV2Router__InsufficientAAmount.selector);
        // Add liquidity
        dexerV2Router.addLiquidity({
            tokenA: tokenAAddress,
            tokenB: tokenBAddress,
            amountADesired: amountADesired,
            amountBDesired: amountBDesired,
            amountAMin: amountAMin,
            amountBMin: amountBMin,
            to: to
        });

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              REMOVE LIQUIDITY
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                              SWAP
    //////////////////////////////////////////////////////////////*/

    /// @notice Test basic swap A -> B
    function testSwapExactTokensForTokens() public withLiquidity withAllowance {
        uint256 amountIn = 0.1 ether;
        uint256 amountOutMin = 0.9 ether;
        dexerV2Pair = DexerV2Pair(dexerV2Factory.pairs(address(tokenA), address(tokenB)));

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        // Get USER balances before swap
        uint256 userTokenABefore = tokenA.balanceOf(USER);
        uint256 userTokenBBefore = tokenB.balanceOf(USER);

        // Get reserves before swap
        (uint256 reserveABefore, uint256 reserveBBefore) = dexerV2Pair.getReserves();

        vm.startPrank(USER);

        // Swap to = USER
        uint256[] memory amounts = dexerV2Router.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: amountOutMin,
            path: path,
            to: USER
        });

        vm.stopPrank();

        // Get USER balances after swap
        uint256 userTokenAAfter = tokenA.balanceOf(USER);
        uint256 userTokenBAfter = tokenB.balanceOf(USER);

        // Get reserves after swap
        (uint256 reserveAAfter, uint256 reserveBAfter) = dexerV2Pair.getReserves();

        // expected amountOut
        uint256 expectedAmountOut =
            dexerV2Router.getAmountOut({amountIn: amountIn, reserveIn: reserveABefore, reserveOut: reserveBBefore});

        // Assert output of tokenB
        assertEq(amounts[amounts.length - 1], expectedAmountOut, "Unexpected amount out");

        // Assert input of tokenA
        assertEq(amounts[0], amountIn, "Unexpected amount in");

        // Check that user spent `amountIn` of tokenA
        assertEq(userTokenAAfter, userTokenABefore - amountIn, "Incorrect tokenA balance after swap");

        // Assert the user received tokenB
        assertEq(userTokenBAfter, userTokenBBefore + amounts[amounts.length - 1], "Incorrect tokenB balance afer swap");

        // Assert reserves after

        assertEq(reserveAAfter, reserveABefore + amountIn, "Unexpected reserveA after swap");
        assertEq(reserveBAfter, reserveBBefore - amounts[amounts.length - 1], "Unexpected reserveA after swap");
    }

    /* ******** Reverts ******** */

    /// @notice Tests that swapExactTokensForTokens reverts if input is zero.
    function testSwapExactTokensForTokensRevertsIfAmountInIsZero() public withLiquidity withAllowance {
        uint256 amountIn = 0 ether;
        uint256 amountOutMin = 0 ether; // no expectations
        dexerV2Pair = DexerV2Pair(dexerV2Factory.pairs(address(tokenA), address(tokenB)));

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        vm.startPrank(USER);

        vm.expectRevert(DexerV2Library.DexerV2Library__InsufficientAmount.selector);

        uint256[] memory amounts = dexerV2Router.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: amountOutMin,
            path: path,
            to: USER
        });

        vm.stopPrank();
    }

    /// @notice Tests that swapExactTokensForTokens reverts if the amountOutMin is not met
    function testSwapExactTokensForTokensRevertsIfAmountOutMinNotMet() public withLiquidity withAllowance {
        uint256 amountIn = 0.1 ether;
        uint256 amountOutMin = 50 ether; // very high
        dexerV2Pair = DexerV2Pair(dexerV2Factory.pairs(address(tokenA), address(tokenB)));

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        vm.startPrank(USER);

        vm.expectRevert(DexerV2Router.DexerV2Router__InsufficientOutputAmount.selector);

        dexerV2Router.swapExactTokensForTokens({amountIn: amountIn, amountOutMin: amountOutMin, path: path, to: USER});

        vm.stopPrank();
    }

    /// @notice Tests that swapExactTokensForTokens reverts if the pair has no liquidity
    function testSwapExactTokensForTokensRevertsIfNoLiquidity() public withAllowance {
        address pairAddress = dexerV2Factory.createPair({tokenA: address(tokenA), tokenB: address(tokenB)});
        uint256 amountIn = 0.1 ether;
        uint256 amountOutMin = 1 ether;

        dexerV2Pair = DexerV2Pair(pairAddress);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        vm.startPrank(USER);

        vm.expectRevert(DexerV2Library.DexerV2Library__InsufficientLiquidity.selector);

        uint256[] memory amounts = dexerV2Router.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: amountOutMin,
            path: path,
            to: USER
        });

        vm.stopPrank();
    }

    /// @notice Tests that swapExactTokensForTokens reverts if the path is not valid (Need >= 2 token addresses)
    function testSwapExactTokensForTokensRevertsIfInvalidPath() public withLiquidity withAllowance {
        uint256 amountIn = 0.1 ether;
        uint256 amountOutMin = 1 ether;
        dexerV2Pair = DexerV2Pair(dexerV2Factory.pairs(address(tokenA), address(tokenB)));

        address[] memory path = new address[](1); // Dont set second path
        path[0] = address(tokenA);

        vm.startPrank(USER);

        vm.expectRevert(DexerV2Library.DexerV2Library__InvalidPath.selector);

        dexerV2Router.swapExactTokensForTokens({amountIn: amountIn, amountOutMin: amountOutMin, path: path, to: USER});

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              SWAP MULTI-HOP
    //////////////////////////////////////////////////////////////*/

    /// @notice Test multihop swap including two or more pair pools, example: A->B->C; available pools: AB and BC
    function testSwapExactTokensForTokensMultiHop() public withLiquidity withAllowance {
        // Add liquidity for tokenB - tokenC pair as well to simulate a multi-hop environment
        vm.startPrank(LIQUIDITY_USER);
        dexerV2Router.addLiquidity({
            tokenA: address(tokenB),
            tokenB: address(tokenC),
            amountADesired: 1 ether,
            amountBDesired: 20 ether,
            amountAMin: 1 ether,
            amountBMin: 20 ether,
            to: LIQUIDITY_USER
        });
        vm.stopPrank();

        uint256 amountIn = 1 ether;
        uint256 amountOutMin = 10 ether;
        dexerV2Pair = DexerV2Pair(dexerV2Factory.pairs(address(tokenA), address(tokenB)));

        // Path A->B->C
        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);

        // Get USER balances before swap
        uint256 userTokenABefore = tokenA.balanceOf(USER);
        uint256 userTokenBCefore = tokenC.balanceOf(USER);

        vm.startPrank(USER);

        // Swap to = USER
        dexerV2Router.swapExactTokensForTokens({amountIn: amountIn, amountOutMin: amountOutMin, path: path, to: USER});

        vm.stopPrank();

        // Get USER balances after swap
        uint256 userTokenAAfter = tokenA.balanceOf(USER);
        uint256 userTokenCAfter = tokenC.balanceOf(USER);

        // Check that user spent `amountIn` of tokenA
        assertEq(userTokenAAfter, userTokenABefore - amountIn, "Incorrect tokenA balance after swap");

        // Assert the user received tokenC (We are avoiding calculation here, so calculate at least amountOutMin)
        assertGt(userTokenCAfter, userTokenBCefore + amountOutMin, "User should have received tokenC");
    }
}
