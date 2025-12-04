// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./libraries/CasinoMath.sol";

contract Jackpot is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public totalPool;
    uint256 public totalBets;
    uint16 public rakeBps; // 500 = 5%
    IERC20 public token;

    event BetPlaced(address indexed player, uint256 betAmount, uint256 poolContribution);
    event WinnerDrawn(address indexed winner, uint256 prize);

    constructor(address _owner, address _token) Ownable(_owner) {
        token = IERC20(_token);
        rakeBps = 500; // 5% default
    }

    function placeBet(uint256 betAmount) external nonReentrant {
        token.safeTransferFrom(msg.sender, address(this), betAmount);

        uint256 rake = (betAmount * rakeBps) / 10000;
        uint256 poolContribution = betAmount - rake;

        totalPool += poolContribution;
        totalBets++;

        emit BetPlaced(msg.sender, betAmount, poolContribution);
    }

    function drawWinner(address winner) external onlyOwner {
        require(totalPool > 0, "No pool");
        require(winner != address(0), "Invalid winner");

        uint256 prize = totalPool;
        totalPool = 0;
        totalBets = 0;

        token.safeTransfer(winner, prize);
        emit WinnerDrawn(winner, prize);
    }

    function setRake(uint16 newRakeBps) external onlyOwner {
        require(newRakeBps <= 1000, "Rake too high"); // Max 10%
        rakeBps = newRakeBps;
    }
}

