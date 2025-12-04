// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ICasinoGame.sol";
import "./libraries/CasinoMath.sol";

contract Blackjack is ICasinoGame, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    GameConfig public config;
    mapping(uint256 => BlackjackGame) public games;
    uint256 public gameCounter;
    IERC20 public token;

    struct BlackjackGame {
        address player;
        uint256 betAmount;
        uint8[] playerCards;
        uint8[] dealerCards;
        uint8 playerScore;
        uint8 dealerScore;
        uint8 gameState; // 0=betting, 1=playing, 2=settled
        uint256 timestamp;
    }

    event GameStarted(address indexed player, uint256 indexed gameId, uint256 betAmount);
    event CardDealt(address indexed player, uint256 indexed gameId, bool isPlayer, uint8 card);
    event GameSettled(address indexed player, uint256 indexed gameId, uint256 payout);

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

    function placeBet(uint256 betAmount) external nonReentrant {
        require(!config.paused, "Game paused");
        CasinoMath.validateBet(betAmount, config.minBet, config.maxBet);

        token.safeTransferFrom(msg.sender, config.treasury, betAmount);

        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)));
        uint8 playerCard1 = uint8(CasinoMath.generateRandom(seed, 12) + 1);
        uint8 playerCard2 = uint8(CasinoMath.generateRandom(seed + 1, 12) + 1);
        uint8 dealerCard1 = uint8(CasinoMath.generateRandom(seed + 2, 12) + 1);

        uint256 gameId = ++gameCounter;
        BlackjackGame storage game = games[gameId];
        game.player = msg.sender;
        game.betAmount = betAmount;
        game.playerCards.push(playerCard1);
        game.playerCards.push(playerCard2);
        game.dealerCards.push(dealerCard1);
        game.playerScore = calculateScore(game.playerCards);
        game.dealerScore = calculateScore(game.dealerCards);
        game.gameState = 1;
        game.timestamp = block.timestamp;

        // Check for blackjack
        if (game.playerScore == 21) {
            game.gameState = 2;
            uint256 payout = (betAmount * 3) / 2; // 3:2 payout
            token.safeTransferFrom(config.treasury, msg.sender, payout);
            emit GameSettled(msg.sender, gameId, payout);
        }

        emit GameStarted(msg.sender, gameId, betAmount);
    }

    function hit(uint256 gameId) external nonReentrant {
        BlackjackGame storage game = games[gameId];
        require(game.gameState == 1, "Invalid state");
        require(game.player == msg.sender, "Not your game");

        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, gameId)));
        uint8 newCard = uint8(CasinoMath.generateRandom(seed, 12) + 1);
        game.playerCards.push(newCard);
        game.playerScore = calculateScore(game.playerCards);

        if (game.playerScore > 21) {
            game.gameState = 2;
            emit GameSettled(msg.sender, gameId, 0);
        }
    }

    function stand(uint256 gameId) external nonReentrant {
        BlackjackGame storage game = games[gameId];
        require(game.gameState == 1, "Invalid state");
        require(game.player == msg.sender, "Not your game");

        // Dealer draws until 17+
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, gameId)));
        while (game.dealerScore < 17) {
            uint8 newCard = uint8(CasinoMath.generateRandom(seed + game.dealerCards.length, 12) + 1);
            game.dealerCards.push(newCard);
            game.dealerScore = calculateScore(game.dealerCards);
        }

        game.gameState = 2;

        uint256 payout = 0;
        if (game.dealerScore > 21 || game.playerScore > game.dealerScore) {
            payout = game.betAmount * 2; // 1:1 payout
        } else if (game.playerScore == game.dealerScore) {
            payout = game.betAmount; // Push
        }

        if (payout > 0) {
            token.safeTransferFrom(config.treasury, msg.sender, payout);
        }

        emit GameSettled(msg.sender, gameId, payout);
    }

    function calculateScore(uint8[] memory cards) internal pure returns (uint8) {
        uint8 score = 0;
        uint8 aces = 0;

        for (uint i = 0; i < cards.length; i++) {
            uint8 value = cards[i] % 13;
            if (value == 0) {
                aces++;
                score += 11;
            } else if (value >= 10) {
                score += 10;
            } else {
                score += value + 1;
            }
        }

        while (score > 21 && aces > 0) {
            score -= 10;
            aces--;
        }

        return score;
    }

    function pause() external onlyOwner {
        config.paused = true;
    }

    function unpause() external onlyOwner {
        config.paused = false;
    }
}

