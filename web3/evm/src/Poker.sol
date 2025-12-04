// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Poker is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Tournament {
        uint256 buyIn;
        uint256 prizePool;
        address[] players;
        uint8 maxPlayers;
        uint8 status; // 0=waiting, 1=active, 2=finished
        address winner;
    }

    mapping(uint256 => Tournament) public tournaments;
    uint256 public tournamentCounter;
    IERC20 public token;

    event TournamentCreated(uint256 indexed tournamentId, uint256 buyIn, uint8 maxPlayers);
    event PlayerJoined(uint256 indexed tournamentId, address indexed player);
    event TournamentStarted(uint256 indexed tournamentId);
    event TournamentEnded(uint256 indexed tournamentId, address indexed winner, uint256 prize);

    constructor(address _owner, address _token) Ownable(_owner) {
        token = IERC20(_token);
    }

    function createTournament(uint256 buyIn, uint8 maxPlayers) external onlyOwner returns (uint256) {
        require(buyIn > 0, "Invalid buy-in");
        require(maxPlayers >= 2 && maxPlayers <= 10, "Invalid max players");

        uint256 tournamentId = ++tournamentCounter;
        tournaments[tournamentId] = Tournament({
            buyIn: buyIn,
            prizePool: 0,
            players: new address[](0),
            maxPlayers: maxPlayers,
            status: 0,
            winner: address(0)
        });

        emit TournamentCreated(tournamentId, buyIn, maxPlayers);
        return tournamentId;
    }

    function joinTournament(uint256 tournamentId) external nonReentrant {
        Tournament storage tournament = tournaments[tournamentId];
        require(tournament.status == 0, "Tournament not open");
        require(tournament.players.length < tournament.maxPlayers, "Tournament full");
        require(tournament.buyIn > 0, "Invalid tournament");

        token.safeTransferFrom(msg.sender, address(this), tournament.buyIn);
        tournament.players.push(msg.sender);
        tournament.prizePool += tournament.buyIn;

        emit PlayerJoined(tournamentId, msg.sender);
    }

    function startTournament(uint256 tournamentId) external onlyOwner {
        Tournament storage tournament = tournaments[tournamentId];
        require(tournament.status == 0, "Invalid status");
        require(tournament.players.length >= 2, "Not enough players");

        tournament.status = 1;
        emit TournamentStarted(tournamentId);
    }

    function endTournament(uint256 tournamentId, uint8 winnerIndex) external onlyOwner {
        Tournament storage tournament = tournaments[tournamentId];
        require(tournament.status == 1, "Invalid status");
        require(winnerIndex < tournament.players.length, "Invalid winner index");

        address winner = tournament.players[winnerIndex];
        tournament.winner = winner;
        tournament.status = 2;

        if (tournament.prizePool > 0) {
            token.safeTransfer(winner, tournament.prizePool);
        }

        emit TournamentEnded(tournamentId, winner, tournament.prizePool);
    }

    function getTournamentPlayers(uint256 tournamentId) external view returns (address[] memory) {
        return tournaments[tournamentId].players;
    }
}

