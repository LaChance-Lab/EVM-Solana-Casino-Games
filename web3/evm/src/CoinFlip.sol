// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ICasinoGame.sol";
import "./libraries/CasinoMath.sol";

contract CoinFlip is ICasinoGame, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    GameConfig public config;
    mapping(uint256 => GameState) public games;
    uint256 public gameCounter;
    IERC20 public token;

    event GamePlayed(
        address indexed player,
        uint256 indexed gameId,
        uint256 betAmount,
        uint256 choice,
        uint256 result,
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

    function play(uint256 betAmount, uint8 choice) external nonReentrant {
        require(!config.paused, "Game paused");
        require(choice <= 1, "Invalid choice");
        CasinoMath.validateBet(betAmount, config.minBet, config.maxBet);

        token.safeTransferFrom(msg.sender, config.treasury, betAmount);

        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)));
        uint256 result = CasinoMath.generateRandom(seed, 1);

        uint256 gameId = ++gameCounter;
        bool won = (choice == result);
        uint256 payout = 0;

        if (won) {
            // 1.95x payout = 19500 bps
            payout = CasinoMath.calculatePayout(betAmount, 19500, config.houseEdgeBps);
            token.safeTransferFrom(config.treasury, msg.sender, payout);
        }

        games[gameId] = GameState({
            player: msg.sender,
            betAmount: betAmount,
            gameId: gameId,
            timestamp: block.timestamp,
            settled: true,
            result: result,
            payout: payout
        });

        emit GamePlayed(msg.sender, gameId, betAmount, choice, result, payout);
    }

    function pause() external onlyOwner {
        config.paused = true;
    }

    function unpause() external onlyOwner {
        config.paused = false;
    }
}

