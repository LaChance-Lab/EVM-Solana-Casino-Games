use anchor_lang::prelude::*;
use crate::errors::CasinoError;

pub fn calculate_payout(bet_amount: u64, multiplier: u64, house_edge_bps: u16) -> Result<u64> {
    let payout = bet_amount
        .checked_mul(multiplier)
        .ok_or(CasinoError::MathOverflow)?
        .checked_div(10000)
        .ok_or(CasinoError::MathOverflow)?;
    
    let house_edge = payout
        .checked_mul(house_edge_bps as u64)
        .ok_or(CasinoError::MathOverflow)?
        .checked_div(10000)
        .ok_or(CasinoError::MathOverflow)?;
    
    payout
        .checked_sub(house_edge)
        .ok_or(CasinoError::MathOverflow)
}

pub fn validate_bet(bet_amount: u64, min_bet: u64, max_bet: u64) -> Result<()> {
    require!(bet_amount >= min_bet, CasinoError::BetTooLow);
    require!(bet_amount <= max_bet, CasinoError::BetTooHigh);
    Ok(())
}

pub fn generate_random_from_seed(seed: &[u8], max: u64) -> u64 {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};
    
    let mut hasher = DefaultHasher::new();
    seed.hash(&mut hasher);
    (hasher.finish() % (max as u64 + 1)) as u64
}

