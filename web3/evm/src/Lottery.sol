// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./libraries/CasinoMath.sol";

contract Lottery is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Ticket {
        address player;
        uint8[6] numbers;
        uint256 betAmount;
        uint256 drawId;
        uint256 timestamp;
    }

    struct Draw {
        uint256 drawId;
        uint8[6] winningNumbers;
        uint256 prizePool;
        uint256 tickets;
        bool drawn;
        uint256 timestamp;
    }

    uint256 public minBet;
    uint256 public maxBet;
    mapping(uint256 => Draw) public draws;
    mapping(uint256 => Ticket) public tickets;
    mapping(uint256 => uint256[]) public drawTickets; // drawId => ticketIds
    uint256 public ticketCounter;
    uint256 public drawCounter;
    IERC20 public token;

    event TicketBought(
        address indexed player,
        uint256 indexed ticketId,
        uint256 indexed drawId,
        uint8[6] numbers,
        uint256 betAmount
    );
    event NumbersDrawn(uint256 indexed drawId, uint8[6] winningNumbers);
    event PrizeClaimed(address indexed player, uint256 indexed ticketId, uint8 matches, uint256 prize);

    constructor(address _owner, address _token) Ownable(_owner) {
        token = IERC20(_token);
    }

    function initialize(uint256 _minBet, uint256 _maxBet) external onlyOwner {
        minBet = _minBet;
        maxBet = _maxBet;
    }

    function buyTicket(
        uint256 betAmount,
        uint8[6] calldata numbers,
        uint256 drawId
    ) external nonReentrant {
        CasinoMath.validateBet(betAmount, minBet, maxBet);

        // Validate numbers (1-49)
        for (uint i = 0; i < 6; i++) {
            require(numbers[i] >= 1 && numbers[i] <= 49, "Invalid number");
        }

        // Check for duplicates
        for (uint i = 0; i < 6; i++) {
            for (uint j = i + 1; j < 6; j++) {
                require(numbers[i] != numbers[j], "Duplicate numbers");
            }
        }

        token.safeTransferFrom(msg.sender, address(this), betAmount);

        // Initialize draw if needed
        if (draws[drawId].drawId == 0) {
            draws[drawId] = Draw({
                drawId: drawId,
                winningNumbers: [uint8(0), 0, 0, 0, 0, 0],
                prizePool: 0,
                tickets: 0,
                drawn: false,
                timestamp: block.timestamp
            });
        }

        // Update draw pool
        Draw storage draw = draws[drawId];
        draw.prizePool += betAmount;
        draw.tickets++;

        // Create ticket
        uint256 ticketId = ++ticketCounter;
        tickets[ticketId] = Ticket({
            player: msg.sender,
            numbers: numbers,
            betAmount: betAmount,
            drawId: drawId,
            timestamp: block.timestamp
        });

        drawTickets[drawId].push(ticketId);

        emit TicketBought(msg.sender, ticketId, drawId, numbers, betAmount);
    }

    function drawNumbers(uint256 drawId) external onlyOwner {
        Draw storage draw = draws[drawId];
        require(!draw.drawn, "Already drawn");
        require(draw.tickets > 0, "No tickets");

        // Generate 6 unique random numbers (1-49)
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, drawId)));
        uint8[6] memory numbers;
        bool[50] memory used;

        for (uint i = 0; i < 6; i++) {
            uint8 num;
            do {
                num = uint8(CasinoMath.generateRandom(seed + i, 48) + 1);
            } while (used[num]);
            used[num] = true;
            numbers[i] = num;
        }

        // Sort numbers
        for (uint i = 0; i < 6; i++) {
            for (uint j = i + 1; j < 6; j++) {
                if (numbers[i] > numbers[j]) {
                    uint8 temp = numbers[i];
                    numbers[i] = numbers[j];
                    numbers[j] = temp;
                }
            }
        }

        draw.winningNumbers = numbers;
        draw.drawn = true;
        draw.timestamp = block.timestamp;

        emit NumbersDrawn(drawId, numbers);
    }

    function claimPrize(uint256 ticketId) external nonReentrant {
        Ticket storage ticket = tickets[ticketId];
        require(ticket.player == msg.sender, "Not your ticket");

        Draw storage draw = draws[ticket.drawId];
        require(draw.drawn, "Draw not completed");

        // Calculate matches
        uint8 matches = 0;
        for (uint i = 0; i < 6; i++) {
            for (uint j = 0; j < 6; j++) {
                if (ticket.numbers[i] == draw.winningNumbers[j]) {
                    matches++;
                    break;
                }
            }
        }

        // Calculate prize based on matches
        uint256 prize = 0;
        if (matches == 6) {
            prize = draw.prizePool; // Jackpot
        } else if (matches == 5) {
            prize = draw.prizePool / 10;
        } else if (matches == 4) {
            prize = draw.prizePool / 100;
        }

        require(prize > 0, "No prize");

        // Mark ticket as claimed (prevent double claiming)
        delete tickets[ticketId];

        token.safeTransfer(msg.sender, prize);
        emit PrizeClaimed(msg.sender, ticketId, matches, prize);
    }

    function getDrawTickets(uint256 drawId) external view returns (uint256[] memory) {
        return drawTickets[drawId];
    }
}

