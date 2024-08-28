// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

using SafeMath for uint256;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/utils/math/Math.sol";

contract Dex {
    address public token0;
    address public token1;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    uint256 private unlocked = 1;

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    modifier lock() {
        require(unlocked == 1, "Dex: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function addLiquidity(uint256 amountA, uint256 amountB, uint256 minLPAmount)
        external
        lock
        returns (uint256 liquidity)
    {
        require(amountA > 0 && amountB > 0, "ERC20: insufficient allowance");

        uint256 _totalSupply = totalSupply;

        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amountA.mul(amountB));
        } else {
            uint256 balanceA = IERC20(token0).balanceOf(address(this));
            uint256 balanceB = IERC20(token1).balanceOf(address(this));
            uint256 liquidityA = amountA.mul(_totalSupply) / balanceA;
            uint256 liquidityB = amountB.mul(_totalSupply) / balanceB;
            liquidity = Math.min(liquidityA, liquidityB);
        }

        require(liquidity > 0 && liquidity >= minLPAmount, "ERC20: transfer amount exceeds balance");
        require(IERC20(token0).allowance(msg.sender, address(this)) >= amountA, "ERC20: insufficient allowance");
        require(IERC20(token1).allowance(msg.sender, address(this)) >= amountB, "ERC20: insufficient allowance");
        require(IERC20(token0).balanceOf(msg.sender) >= amountA, "ERC20: transfer amount exceeds balance");
        require(IERC20(token1).balanceOf(msg.sender) >= amountB, "ERC20: transfer amount exceeds balance");

        IERC20(token0).transferFrom(msg.sender, address(this), amountA);
        IERC20(token1).transferFrom(msg.sender, address(this), amountB);

        _mint(msg.sender, liquidity);

        return liquidity;
    }

    function removeLiquidity(uint256 lpAmount, uint256 minAmount0, uint256 minAmount1)
        external
        lock
        returns (uint256 amount0, uint256 amount1)
    {
        require(lpAmount > 0, "Dex: INSUFFICIENT_LIQUIDITY_BURNED");
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 _totalSupply = totalSupply;

        amount0 = lpAmount.mul(balance0) / _totalSupply;
        amount1 = lpAmount.mul(balance1) / _totalSupply;
        require(amount0 >= minAmount0 && amount1 >= minAmount1, "Dex: INSUFFICIENT_LIQUIDITY");

        _burn(msg.sender, lpAmount);
        IERC20(token0).transfer(msg.sender, amount0);
        IERC20(token1).transfer(msg.sender, amount1);

        return (amount0, amount1);
    }

    function swap(uint256 amountAIn, uint256 amountBIn, uint256 minAmountOut)
        external
        lock
        returns (uint256 amountOut)
    {
        require(amountAIn > 0 || amountBIn > 0, "Dex: INSUFFICIENT_INPUT_AMOUNT");
        require(amountAIn == 0 || amountBIn == 0, "Dex: ONLY_ONE_INPUT_ALLOWED");

        (address tokenIn, address tokenOut, uint256 amountIn) =
            amountAIn > 0 ? (token0, token1, amountAIn) : (token1, token0, amountBIn);

        uint256 balanceIn = IERC20(tokenIn).balanceOf(address(this));
        uint256 balanceOut = IERC20(tokenOut).balanceOf(address(this));

        amountOut = getAmountOut(amountIn, balanceIn, balanceOut);
        require(amountOut > 0 && amountOut >= minAmountOut, "Dex: INSUFFICIENT_OUTPUT_AMOUNT");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(msg.sender, amountOut);

        return amountOut;
    }

    function _mint(address to, uint256 value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
    }

    function _burn(address from, uint256 value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "Dex: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "Dex: INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn.mul(999);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }
}

//interface..import하기 귀찮음

interface IERC120 {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

library SafeMath {
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "ds-math-add-overflow");
    }

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "ds-math-sub-underflow");
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "ds-math-mul-overflow");
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return a / b;
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
        // else z = 0 (default value)
    }
}
