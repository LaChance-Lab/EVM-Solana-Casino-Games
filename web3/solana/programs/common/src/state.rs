use anchor_lang::prelude::*;

#[account]
pub struct GameConfig {
    pub authority: Pubkey,
    pub treasury: Pubkey,
    pub min_bet: u64,
    pub max_bet: u64,
    pub house_edge_bps: u16, // Basis points (e.g., 250 = 2.5%)
    pub paused: bool,
    pub bump: u8,
}

impl GameConfig {
    pub const LEN: usize = 8 + 32 + 32 + 8 + 8 + 2 + 1 + 1;
}

#[account]
pub struct GameState {
    pub player: Pubkey,
    pub bet_amount: u64,
    pub game_id: u64,
    pub timestamp: i64,
    pub settled: bool,
    pub result: Option<u64>, // Game-specific result
    pub payout: Option<u64>,
    pub bump: u8,
}

impl GameState {
    pub const LEN: usize = 8 + 32 + 8 + 8 + 8 + 1 + 1 + 8 + 1 + 1;
}

