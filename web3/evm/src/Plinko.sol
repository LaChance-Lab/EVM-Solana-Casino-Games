// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ICasinoGame.sol";
import "./libraries/CasinoMath.sol";

contract Plinko is ICasinoGame, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    GameConfig public config;
    mapping(uint256 => GameState) public games;
    uint256 public gameCounter;
    IERC20 public token;

    event GamePlayed(
        address indexed player,
        uint256 indexed gameId,
        uint256 betAmount,
        uint8 rows,
        int256 position,
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

    function play(uint256 betAmount, uint8 rows) external nonReentrant {
        require(!config.paused, "Game paused");
        require(rows >= 8 && rows <= 16, "Invalid rows");
        CasinoMath.validateBet(betAmount, config.minBet, config.maxBet);

        token.safeTransferFrom(msg.sender, config.treasury, betAmount);

        // Simulate ball path
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)));
        int256 position = 0;

        for (uint8 i = 0; i < rows; i++) {
            uint256 random = CasinoMath.generateRandom(seed + i, 1);
            position += (random == 0) ? int256(-1) : int256(1);
        }

        uint256 multiplierBps = calculateMultiplier(position, int256(rows));
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
            result: uint256(position >= 0 ? position : -position),
            payout: payout
        });

        emit GamePlayed(msg.sender, gameId, betAmount, rows, position, payout);
    }

    function calculateMultiplier(int256 position, int256 maxPosition) internal pure returns (uint256) {
        int256 distanceFromCenter = position < 0 ? -position : position;
        int256 maxDistance = maxPosition;

        if (distanceFromCenter == 0) {
            return 10000000; // 1000x at center
        } else {
            uint256 reduction = uint256((distanceFromCenter * 500000) / maxDistance);
            uint256 multiplier = 10000000 > reduction ? 10000000 - reduction : 100000; // Min 10x
            return multiplier;
        }
    }

    function pause() external onlyOwner {
        config.paused = true;
    }

    function unpause() external onlyOwner {
        config.paused = false;
    }
}

