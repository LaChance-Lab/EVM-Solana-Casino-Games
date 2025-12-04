use anchor_lang::prelude::*;

#[error_code]
pub enum CasinoError {
    #[msg("Invalid bet amount")]
    InvalidBetAmount,
    #[msg("Bet amount too low")]
    BetTooLow,
    #[msg("Bet amount too high")]
    BetTooHigh,
    #[msg("Insufficient funds")]
    InsufficientFunds,
    #[msg("Game not active")]
    GameNotActive,
    #[msg("Invalid game state")]
    InvalidGameState,
    #[msg("Unauthorized")]
    Unauthorized,
    #[msg("VRF not ready")]
    VRFNotReady,
    #[msg("Invalid randomness")]
    InvalidRandomness,
    #[msg("Math overflow")]
    MathOverflow,
    #[msg("Invalid multiplier")]
    InvalidMultiplier,
    #[msg("Game already settled")]
    GameAlreadySettled,
}

