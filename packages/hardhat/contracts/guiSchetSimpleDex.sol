// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

contract guiSchetSimpleDex {
    address public tokenA;
    address public tokenB;
    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public feesTokenA; // Comisiones acumuladas de TokenA
    uint256 public feesTokenB; // Comisiones acumuladas de TokenB
    address public owner; // Address del creador del contrato

    struct LiquidityProvider {
        uint256 amountA; // Tokens A aportados por el usuario
        uint256 amountB; // Tokens B aportados por el usuario
        bool exists;     // Para saber si la dirección ya fue registrada
    }

    mapping(address => LiquidityProvider) public liquidityProviders;
    address[] public providerAddresses;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB);
    event Swap(address indexed trader, address tokenIn, uint256 amountIn, address tokenOut, uint256 amountOut);
    event FeesWithdrawn(address indexed owner, uint256 amountA, uint256 amountB);

    constructor(address _tokenA, address _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        owner = 0x1E2E4c416e51F8a420062500DD37D0B2CcFdDDFB; // El creador del contrato es el propietario
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function");
        _;
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external {
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        if (!liquidityProviders[msg.sender].exists) {
            liquidityProviders[msg.sender].exists = true;
            providerAddresses.push(msg.sender);
        }

        reserveA += amountA;
        reserveB += amountB;

        liquidityProviders[msg.sender].amountA += amountA;
        liquidityProviders[msg.sender].amountB += amountB;

        emit LiquidityAdded(msg.sender, amountA, amountB);
    }

    function removeLiquidity(uint256 amountA, uint256 amountB) external {
        LiquidityProvider storage provider = liquidityProviders[msg.sender];

        require(provider.amountA >= amountA, "Insufficient TokenA liquidity");
        require(provider.amountB >= amountB, "Insufficient TokenB liquidity");

        reserveA -= amountA;
        reserveB -= amountB;

        provider.amountA -= amountA;
        provider.amountB -= amountB;

        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB);
    }

    function swapAforB(uint256 amountAIn) external {
        require(amountAIn > 0, "Invalid amount");
        uint256 amountBOut = getOutputAmount(amountAIn, reserveA, reserveB);

        uint256 feeA = (amountAIn * 3) / 1000; // 0.3% fee
        uint256 netAIn = amountAIn - feeA;

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountAIn);
        IERC20(tokenB).transfer(msg.sender, amountBOut);

        reserveA += netAIn;
        reserveB -= amountBOut;
        feesTokenA += feeA; // Guardamos las comisiones acumuladas para TokenA

        emit Swap(msg.sender, tokenA, amountAIn, tokenB, amountBOut);
    }

    function swapBforA(uint256 amountBIn) external {
        require(amountBIn > 0, "Invalid amount");
        uint256 amountAOut = getOutputAmount(amountBIn, reserveB, reserveA);

        uint256 feeB = (amountBIn * 3) / 1000; // 0.3% fee
        uint256 netBIn = amountBIn - feeB;

        IERC20(tokenB).transferFrom(msg.sender, address(this), amountBIn);
        IERC20(tokenA).transfer(msg.sender, amountAOut);

        reserveB += netBIn;
        reserveA -= amountAOut;
        feesTokenB += feeB; // Guardamos las comisiones acumuladas para TokenB

        emit Swap(msg.sender, tokenB, amountBIn, tokenA, amountAOut);
    }

    function getPrice(address _token) external view returns (uint256) {
        if (_token == tokenA) {
            return (reserveB * 1e18) / reserveA;
        } else if (_token == tokenB) {
            return (reserveA * 1e18) / reserveB;
        } else {
            revert("Invalid token");
        }
    }

    function getOutputAmount(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) private pure returns (uint256) {
        uint256 inputAmountWithFee = inputAmount * 997; // Fee del 0.3%
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 1000) + inputAmountWithFee;
        return numerator / denominator;
    }

    // Devuelve las comisiones acumuladas para cada token
    function getFeeReserves() external view returns (uint256, uint256) {
        return (feesTokenA, feesTokenB);
    }

    // Permite al propietario retirar las comisiones acumuladas
    function withdrawFees() external onlyOwner {
        uint256 amountA = feesTokenA;
        uint256 amountB = feesTokenB;

        require(amountA > 0 || amountB > 0, "No fees to withdraw");

        if (amountA > 0) {
            feesTokenA = 0;
            IERC20(tokenA).transfer(owner, amountA);
        }

        if (amountB > 0) {
            feesTokenB = 0;
            IERC20(tokenB).transfer(owner, amountB);
        }

        emit FeesWithdrawn(owner, amountA, amountB);
    }
}