// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ICasinoGame.sol";
import "./libraries/CasinoMath.sol";

contract Crash is ICasinoGame, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    GameConfig public config;
    mapping(uint256 => GameState) public games;
    uint256 public gameCounter;

    event BetPlaced(address indexed player, uint256 indexed gameId, uint256 betAmount, uint256 autoCashout);
    event Cashout(address indexed player, uint256 indexed gameId, uint256 multiplier, uint256 payout);
    event Crashed(uint256 indexed gameId, uint256 multiplier);

    constructor(address _owner) Ownable(_owner) {}

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

    function placeBet(uint256 betAmount, uint256 autoCashout) external nonReentrant {
        require(!config.paused, "Game paused");
        CasinoMath.validateBet(betAmount, config.minBet, config.maxBet);

        IERC20 token = IERC20(msg.sender); // Assume token passed via context
        token.safeTransferFrom(msg.sender, config.treasury, betAmount);

        uint256 gameId = ++gameCounter;
        games[gameId] = GameState({
            player: msg.sender,
            betAmount: betAmount,
            gameId: gameId,
            timestamp: block.timestamp,
            settled: false,
            result: autoCashout,
            payout: 0
        });

        emit BetPlaced(msg.sender, gameId, betAmount, autoCashout);
    }

    function cashout(uint256 gameId, uint256 currentMultiplier) external nonReentrant {
        GameState storage game = games[gameId];
        require(!game.settled, "Game already settled");
        require(game.player == msg.sender, "Not your game");

        uint256 multiplierBps = currentMultiplier * 100;
        uint256 payout = CasinoMath.calculatePayout(game.betAmount, multiplierBps, config.houseEdgeBps);

        game.settled = true;
        game.result = currentMultiplier;
        game.payout = payout;

        IERC20 token = IERC20(msg.sender);
        token.safeTransferFrom(config.treasury, msg.sender, payout);

        emit Cashout(msg.sender, gameId, currentMultiplier, payout);
    }

    function settleCrashed(uint256 gameId) external onlyOwner {
        GameState storage game = games[gameId];
        require(!game.settled, "Game already settled");

        game.settled = true;
        game.payout = 0;

        emit Crashed(gameId, game.result);
    }

    function pause() external onlyOwner {
        config.paused = true;
    }

    function unpause() external onlyOwner {
        config.paused = false;
    }
}

