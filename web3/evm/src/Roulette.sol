// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ICasinoGame.sol";
import "./libraries/CasinoMath.sol";

contract Roulette is ICasinoGame, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    GameConfig public config;
    mapping(uint256 => GameState) public games;
    uint256 public gameCounter;
    IERC20 public token;

    // Bet types: 0=Single, 1=Red/Black, 2=Odd/Even, 3=High/Low, 4=Dozen, 5=Column
    event GamePlayed(
        address indexed player,
        uint256 indexed gameId,
        uint256 betAmount,
        uint8 betType,
        uint8 betValue,
        uint256 winningNumber,
        uint256 payout
    );

    constructor(address _owner, address _token) Ownable(_owner) {
        token = IERC20(_token);
    }

    function initialize(
        address treasury,
        uint256 minBet,
        uint256 maxBet,
        uint16 houseEdgeBps
    ) external onlyOwner {
        config = GameConfig({
            treasury: treasury,
            minBet: minBet,
            maxBet: maxBet,
            houseEdgeBps: houseEdgeBps,
            paused: false
        });
    }

    function placeBet(
        uint256 betAmount,
        uint8 betType,
        uint8 betValue
    ) external nonReentrant {
        require(!config.paused, "Game paused");
        require(betType <= 5, "Invalid bet type");
        CasinoMath.validateBet(betAmount, config.minBet, config.maxBet);

        // Validate bet value based on bet type
        if (betType == 0) {
            require(betValue <= 36, "Invalid number");
        } else if (betType == 1 || betType == 2 || betType == 3) {
            require(betValue <= 1, "Invalid bet value");
        } else if (betType == 4) {
            require(betValue <= 2, "Invalid dozen");
        } else if (betType == 5) {
            require(betValue <= 2, "Invalid column");
        }

        token.safeTransferFrom(msg.sender, config.treasury, betAmount);

        // Spin wheel (0-36 for European roulette)
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)));
        uint256 winningNumber = CasinoMath.generateRandom(seed, 36);

        // Calculate payout based on bet type
        uint256 multiplierBps = getMultiplier(betType);
        bool won = checkWin(winningNumber, betType, betValue);
        
        uint256 payout = 0;
        if (won) {
            payout = CasinoMath.calculatePayout(betAmount, multiplierBps, config.houseEdgeBps);
            token.safeTransferFrom(config.treasury, msg.sender, payout);
        }

        uint256 gameId = ++gameCounter;
        games[gameId] = GameState({
            player: msg.sender,
            betAmount: betAmount,
            gameId: gameId,
            timestamp: block.timestamp,
            settled: true,
            result: winningNumber,
            payout: payout
        });

        emit GamePlayed(msg.sender, gameId, betAmount, betType, betValue, winningNumber, payout);
    }

    function getMultiplier(uint8 betType) internal pure returns (uint256) {
        if (betType == 0) return 360000; // Single number (35:1) = 360000 bps
        if (betType == 1 || betType == 2 || betType == 3) return 20000; // Red/Black, Odd/Even, High/Low (1:1) = 20000 bps
        if (betType == 4 || betType == 5) return 30000; // Dozen, Column (2:1) = 30000 bps
        return 0;
    }

    function checkWin(
        uint256 winningNumber,
        uint8 betType,
        uint8 betValue
    ) internal pure returns (bool) {
        if (betType == 0) {
            // Single number
            return winningNumber == betValue;
        } else if (betType == 1) {
            // Red/Black (0=Black, 1=Red)
            // Red numbers: 1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36
            bool isRed = isRedNumber(winningNumber);
            return (betValue == 1 && isRed) || (betValue == 0 && !isRed && winningNumber != 0);
        } else if (betType == 2) {
            // Odd/Even (0=Even, 1=Odd)
            bool isOdd = (winningNumber % 2 == 1);
            return (betValue == 1 && isOdd) || (betValue == 0 && !isOdd && winningNumber != 0);
        } else if (betType == 3) {
            // High/Low (0=Low 1-18, 1=High 19-36)
            bool isHigh = winningNumber > 18 && winningNumber <= 36;
            return (betValue == 1 && isHigh) || (betValue == 0 && !isHigh && winningNumber != 0);
        } else if (betType == 4) {
            // Dozen (0=1-12, 1=13-24, 2=25-36)
            if (winningNumber == 0) return false;
            uint256 dozen = (winningNumber - 1) / 12;
            return dozen == betValue;
        } else if (betType == 5) {
            // Column (0=1st, 1=2nd, 2=3rd)
            if (winningNumber == 0) return false;
            uint256 column = (winningNumber - 1) % 3;
            return column == betValue;
        }
        return false;
    }

    function isRedNumber(uint256 number) internal pure returns (bool) {
        if (number == 0) return false;
        uint8[18] memory redNumbers = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36];
        for (uint i = 0; i < redNumbers.length; i++) {
            if (number == redNumbers[i]) {
                return true;
            }
        }
        return false;
    }

    function pause() external onlyOwner {
        config.paused = true;
    }

    function unpause() external onlyOwner {
        config.paused = false;
    }
}

