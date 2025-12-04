// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ICasinoGame.sol";
import "./libraries/CasinoMath.sol";

contract Slots is ICasinoGame, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    GameConfig public config;
    mapping(uint256 => GameState) public games;
    uint256 public gameCounter;
    IERC20 public token;

    event GamePlayed(
        address indexed player,
        uint256 indexed gameId,
        uint256 betAmount,
        uint8 reel1,
        uint8 reel2,
        uint8 reel3,
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

    function spin(uint256 betAmount) external nonReentrant {
        require(!config.paused, "Game paused");
        CasinoMath.validateBet(betAmount, config.minBet, config.maxBet);

        token.safeTransferFrom(msg.sender, config.treasury, betAmount);

        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)));
        uint8 reel1 = uint8(CasinoMath.generateRandom(seed, 6));
        uint8 reel2 = uint8(CasinoMath.generateRandom(seed + 1, 6));
        uint8 reel3 = uint8(CasinoMath.generateRandom(seed + 2, 6));

        uint256 multiplierBps = calculatePayoutMultiplier(reel1, reel2, reel3);
        uint256 payout = CasinoMath.calculatePayout(betAmount, multiplierBps, config.houseEdgeBps);

        if (payout > 0) {
            token.safeTransferFrom(config.treasury, msg.sender, payout);
        }

        uint256 gameId = ++gameCounter;
        games[gameId] = GameState({
            player: msg.sender,
            betAmount: betAmount,
            gameId: gameId,
            timestamp: block.timestamp,
            settled: true,
            result: (uint256(reel1) << 16) | (uint256(reel2) << 8) | uint256(reel3),
            payout: payout
        });

        emit GamePlayed(msg.sender, gameId, betAmount, reel1, reel2, reel3, payout);
    }

    function calculatePayoutMultiplier(uint8 reel1, uint8 reel2, uint8 reel3) internal pure returns (uint256) {
        // Three of a kind
        if (reel1 == reel2 && reel2 == reel3) {
            if (reel1 == 6) return 250000; // Three Sevens = 25x
            if (reel1 == 5) return 100000; // Three Bars = 10x
            if (reel1 == 4) return 50000;  // Three Bells = 5x
            return 20000; // Three others = 2x
        }
        // Two of a kind
        else if (reel1 == reel2 || reel2 == reel3 || reel1 == reel3) {
            return 10000; // 1x
        }
        // No match
        else {
            return 0;
        }
    }

    function pause() external onlyOwner {
        config.paused = true;
    }

    function unpause() external onlyOwner {
        config.paused = false;
    }
}

