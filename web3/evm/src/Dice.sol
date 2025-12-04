// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ICasinoGame.sol";
import "./libraries/CasinoMath.sol";

contract Dice is ICasinoGame, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    GameConfig public config;
    mapping(uint256 => GameState) public games;
    uint256 public gameCounter;
    IERC20 public token;

    event GamePlayed(
        address indexed player,
        uint256 indexed gameId,
        uint256 betAmount,
        uint8 target,
        bool rollUnder,
        uint256 roll,
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

    function play(uint256 betAmount, uint8 target, bool rollUnder) external nonReentrant {
        require(!config.paused, "Game paused");
        require(target > 0 && target < 100, "Invalid target");
        CasinoMath.validateBet(betAmount, config.minBet, config.maxBet);

        token.safeTransferFrom(msg.sender, config.treasury, betAmount);

        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)));
        uint256 roll = CasinoMath.generateRandom(seed, 99) + 1; // 1-100

        bool won = rollUnder ? (roll < target) : (roll > target);
        uint256 payout = 0;

        if (won) {
            uint256 probability = rollUnder ? (target - 1) : (100 - target);
            uint256 multiplierBps = (10000 * 10000) / probability;
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
            result: roll,
            payout: payout
        });

        emit GamePlayed(msg.sender, gameId, betAmount, target, rollUnder, roll, payout);
    }

    function pause() external onlyOwner {
        config.paused = true;
    }

    function unpause() external onlyOwner {
        config.paused = false;
    }
}

