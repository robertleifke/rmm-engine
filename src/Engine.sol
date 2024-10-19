// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import "forge-std/console2.sol";

import "./lib/RmmLib.sol";
import "./lib/RmmErrors.sol";
import "./lib/RmmEvents.sol";
import "./lib/LiquidityLib.sol";

contract RMM is ERC20 {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;

    using SafeTransferLib for ERC20;

    ERC20 public tokenX;  // Arbitrary ERC-20 token
    ERC20 public tokenY;  // Arbitrary ERC-20 token

    uint256 public sigma;  // Volatility parameter
    uint256 public fee;    // Swap fee
    uint256 public maturity;  // Timestamp of pool expiration

    uint256 public reserveX;  // Reserve of tokenX
    uint256 public reserveY;  // Reserve of tokenY
    uint256 public totalLiquidity;  // Total liquidity in the pool
    uint256 public strike;  // Strike price of the pool

    uint256 public lastTimestamp;
    uint256 public lastImpliedPrice;

    uint256 private _lock = 1;

    modifier lock() {
        if (_lock != 1) revert Reentrancy();
        _lock = 0;
        _;
        _lock = 1;
    }

    modifier evolve() {
        _;
        int256 terminal = tradingFunction();

        if (abs(terminal) > 100) {
            revert OutOfRange(terminal);
        }
    }

    constructor(string memory name_, string memory symbol_, address tokenX_, address tokenY_, uint256 sigma_, uint256 fee_, uint256 maturity_)
        ERC20(name_, symbol_, 18)
    {
        tokenX = ERC20(tokenX_);
        tokenY = ERC20(tokenY_);
        sigma = sigma_;
        maturity = maturity_;
        fee = fee_;
    }

    function init(uint256 priceX, uint256 amountX, uint256 strike_)
        external
        lock
        returns (uint256 totalLiquidity_, uint256 amountY)
    {
        if (strike_ <= 1e18 || strike != 0) revert InvalidStrike();

        (totalLiquidity_, amountY) = prepareInit(priceX, amountX, strike_, sigma);

        _mint(msg.sender, totalLiquidity_ - 1000);
        _mint(address(0), 1000);
        _adjust(int256(amountX), int256(amountY), int256(totalLiquidity_), strike_);

        // Debit token amounts from the sender
        _debit(address(tokenX), reserveX);
        _debit(address(tokenY), reserveY);

        emit Init(msg.sender, address(tokenX), address(tokenY), amountX, amountY, totalLiquidity_, strike_, sigma, fee, maturity);
    }

    receive() external payable {}

    function swapExactXForY(uint256 amountX, uint256 minAmountY, address to)
        external
        lock
        returns (uint256 amountY, int256 deltaLiquidity)
    {
        uint256 amountInWad;
        uint256 amountOutWad;

        // Prepare the swap, calculate delta liquidity
        (amountInWad, amountOutWad, amountY, deltaLiquidity) = prepareSwapXIn(amountX);

        // Ensure the output amount is greater than or equal to the minimum
        if (amountY < minAmountY) revert InsufficientOutput(amountInWad, minAmountY, amountY);

        // Adjust the pool reserves and state
        _adjust(int256(amountInWad), -int256(amountOutWad), deltaLiquidity);

        // Debit tokenX from the user and credit tokenY
        _debit(address(tokenX), amountInWad);
        _credit(address(tokenY), to, amountOutWad);

        emit Swap(msg.sender, to, address(tokenX), address(tokenY), amountX, amountY, deltaLiquidity);
    }

    function swapExactYForX(uint256 amountY, uint256 minAmountX, address to)
        external
        lock
        returns (uint256 amountX, int256 deltaLiquidity)
    {
        uint256 amountInWad;
        uint256 amountOutWad;

        // Prepare the swap, calculate delta liquidity
        (amountInWad, amountOutWad, amountX, deltaLiquidity) = prepareSwapYIn(amountY);

        // Ensure the output amount is greater than or equal to the minimum
        if (amountX < minAmountX) revert InsufficientOutput(amountInWad, minAmountX, amountX);

        // Adjust the pool reserves and state
        _adjust(-int256(amountOutWad), int256(amountInWad), deltaLiquidity);

        // Debit tokenY from the user and credit tokenX
        _debit(address(tokenY), amountInWad);
        _credit(address(tokenX), to, amountOutWad);

        emit Swap(msg.sender, to, address(tokenY), address(tokenX), amountY, amountX, deltaLiquidity);
    }

    function allocate(bool inTermsOfX, uint256 amount, uint256 minLiquidityOut, address to)
        external
        lock
        returns (uint256 deltaLiquidity)
    {
        uint256 deltaXWad;
        uint256 deltaYWad;

        // Prepare the allocation
        (deltaXWad, deltaYWad, deltaLiquidity) = prepareAllocate(inTermsOfX, amount);
        if (deltaLiquidity < minLiquidityOut) revert InsufficientOutput(amount, minLiquidityOut, deltaLiquidity);

        // Mint liquidity tokens
        _mint(to, deltaLiquidity);
        _updateReserves(int256(deltaXWad), int256(deltaYWad), int256(deltaLiquidity));

        // Debit tokens from the user
        _debit(address(tokenX), deltaXWad);
        _debit(address(tokenY), deltaYWad);

        emit Allocate(msg.sender, to, deltaXWad, deltaYWad, deltaLiquidity);
    }

    function deallocate(uint256 deltaLiquidity, uint256 minDeltaXOut, uint256 minDeltaYOut, address to)
        external
        lock
        returns (uint256 deltaX, uint256 deltaY)
    {
        uint256 deltaXWad;
        uint256 deltaYWad;

        // Prepare the deallocation
        (deltaXWad, deltaYWad) = prepareDeallocate(deltaLiquidity);

        deltaX = downscaleDown(deltaXWad);
        deltaY = downscaleDown(deltaYWad);

        if (deltaX < minDeltaXOut) revert InsufficientOutput(deltaLiquidity, minDeltaXOut, deltaX);
        if (deltaY < minDeltaYOut) revert InsufficientOutput(deltaLiquidity, minDeltaYOut, deltaY);

        // Burn liquidity tokens and update reserves
        _burn(msg.sender, deltaLiquidity);
        _updateReserves(-int256(deltaXWad), -int256(deltaYWad), -int256(deltaLiquidity));

        // Credit tokens to the user
        _credit(address(tokenX), to, deltaXWad);
        _credit(address(tokenY), to, deltaYWad);

        emit Deallocate(msg.sender, to, deltaXWad, deltaYWad, deltaLiquidity);
    }

    // Helper functions for handling token transfers
    function _debit(address token, uint256 amountWad) internal {
        ERC20(token).safeTransferFrom(msg.sender, address(this), downscaleDown(amountWad));
    }

    function _credit(address token, address to, uint256 amountWad) internal {
        ERC20(token).safeTransfer(to, downscaleDown(amountWad));
    }

    // Trading function computation (replaces Pendle-specific logic)
    function tradingFunction() public view returns (int256) {
        if (totalLiquidity == 0) return 0; // Pool not initialized
        uint256 totalAsset = reserveX;
        return computeTradingFunction(totalAsset, reserveY, totalLiquidity, strike, sigma, lastTau());
    }

    // Add further functions here, like liquidity preparation, swap calculations, and updates to reserves.
}
