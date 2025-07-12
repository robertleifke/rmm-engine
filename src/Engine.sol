// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import "./lib/RmmLib.sol";
import "./lib/RmmErrors.sol";
import "./lib/RmmEvents.sol";
import "./lib/LiquidityLib.sol";

contract RMM is ERC20 {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;

    using SafeTransferLib for ERC20;

    ERC20 public tokenX; // Arbitrary ERC-20 token
    ERC20 public tokenY; // Arbitrary ERC-20 token

    uint256 public sigma; // Volatility parameter
    uint256 public fee; // Swap fee
    uint256 public maturity; // Timestamp of pool expiration

    uint256 public reserveX; // Reserve of tokenX
    uint256 public reserveY; // Reserve of tokenY
    uint256 public totalLiquidity; // Total liquidity in the pool
    uint256 public strike; // Strike price of the pool

    uint256 public lastTimestamp;
    uint256 public lastImpliedPrice;

    uint256 private _lock = 1;

    modifier lock() {
        require(_lock == 1, "Reentrancy");
        _lock = 0;
        _;
        _lock = 1;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        address tokenX_,
        address tokenY_,
        uint256 sigma_,
        uint256 fee_,
        uint256 maturity_
    ) ERC20(name_, symbol_, 18) {
        tokenX = ERC20(tokenX_);
        tokenY = ERC20(tokenY_);
        sigma = sigma_;
        maturity = maturity_;
        fee = fee_;
    }

    // Initialization function for setting up the pool
    function init(uint256 priceX, uint256 amountX, uint256 strike_)
        external
        lock
        returns (uint256 totalLiquidity_, uint256 amountY)
    {
        require(strike_ > 1e18 && strike == 0, "Invalid strike");

        // Simulate initial liquidity calculation (replace with actual logic)
        totalLiquidity_ = amountX;
        amountY = (amountX * priceX) / 1e18;

        reserveX += amountX;
        reserveY += amountY;
        totalLiquidity += totalLiquidity_;

        _mint(msg.sender, totalLiquidity_);
        _adjust(int256(amountX), int256(amountY), int256(totalLiquidity_), strike_);

        // Transfer the tokens from the sender to the contract
        _debit(address(tokenX), amountX);
        _debit(address(tokenY), amountY);

        emit Init(
            msg.sender,
            address(tokenX),
            address(tokenY),
            amountX,
            amountY,
            totalLiquidity_,
            strike_,
            sigma,
            fee,
            maturity
        );
    }

    // Simpler swap function for tokenX to tokenY
    function swapExactXForY(uint256 amountX, uint256 minAmountY, address to)
        external
        lock
        returns (uint256 amountY, int256 deltaLiquidity)
    {
        // Placeholder logic for swapping
        amountY = (amountX * reserveY) / reserveX;
        require(amountY >= minAmountY, "Insufficient output");

        reserveX += amountX;
        reserveY -= amountY;

        // Adjust the pool reserves and state
        _adjust(int256(amountX), -int256(amountY), deltaLiquidity, strike);

        // Perform the token transfers
        _debit(address(tokenX), amountX);
        _credit(address(tokenY), to, amountY);

        emit Swap(msg.sender, to, address(tokenX), address(tokenY), amountX, amountY, deltaLiquidity);
    }

    // Placeholder function to adjust pool state
    function _adjust(int256 deltaX, int256 deltaY, int256 deltaLiquidity, uint256 strike_) internal {
        lastTimestamp = block.timestamp;
        reserveX = uint256(int256(reserveX) + deltaX);
        reserveY = uint256(int256(reserveY) + deltaY);
        totalLiquidity = uint256(int256(totalLiquidity) + deltaLiquidity);
        strike = strike_;
    }

    // Allocate liquidity (add liquidity to the pool)
    function allocate(bool inTermsOfX, uint256 amount, uint256 minLiquidityOut, address to)
        external
        lock
        returns (uint256 deltaLiquidity)
    {
        uint256 deltaXWad;
        uint256 deltaYWad;

        // Placeholder logic to determine the allocation of liquidity
        if (inTermsOfX) {
            deltaXWad = amount;
            deltaYWad = (deltaXWad * reserveY) / reserveX;
        } else {
            deltaYWad = amount;
            deltaXWad = (deltaYWad * reserveX) / reserveY;
        }

        deltaLiquidity = (deltaXWad + deltaYWad) / 2; // Simplified logic

        require(deltaLiquidity >= minLiquidityOut, "Insufficient liquidity");

        // Adjust reserves and mint liquidity tokens
        reserveX += deltaXWad;
        reserveY += deltaYWad;
        totalLiquidity += deltaLiquidity;

        _mint(to, deltaLiquidity);
        emit Allocate(msg.sender, to, deltaXWad, deltaYWad, deltaLiquidity);

        // Debit the user
        _debit(address(tokenX), deltaXWad);
        _debit(address(tokenY), deltaYWad);
    }

    // Placeholder function to calculate the liquidity based on reserves
    function prepareSwapXIn(uint256 amountX) internal view returns (uint256, uint256, uint256, int256) {
        uint256 amountY = (amountX * reserveY) / reserveX;
        int256 deltaLiquidity = int256(amountX + amountY);
        return (amountX, amountY, amountY, deltaLiquidity);
    }

    // Debit function to transfer tokens from the user to the contract
    function _debit(address token, uint256 amount) internal {
        ERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }

    // Credit function to transfer tokens from the contract to the recipient
    function _credit(address token, address to, uint256 amount) internal {
        ERC20(token).safeTransfer(to, amount);
    }
}
