use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

declare_id!("Plinko1111111111111111111111111111111");

#[program]
pub mod plinko {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>, min_bet: u64, max_bet: u64, house_edge_bps: u16) -> Result<()> {
        let config = &mut ctx.accounts.config;
        config.authority = ctx.accounts.authority.key();
        config.treasury = ctx.accounts.treasury.key();
        config.min_bet = min_bet;
        config.max_bet = max_bet;
        config.house_edge_bps = house_edge_bps;
        config.paused = false;
        config.bump = ctx.bumps.config;
        Ok(())
    }

    pub fn play(ctx: Context<Play>, bet_amount: u64, rows: u8) -> Result<()> {
        let config = &ctx.accounts.config;
        require!(!config.paused, common::CasinoError::GameNotActive);
        require!(rows >= 8 && rows <= 16, common::CasinoError::InvalidBetAmount);
        
        common::validate_bet(bet_amount, config.min_bet, config.max_bet)?;

        // Transfer bet amount from player to treasury
        let cpi_accounts = Transfer {
            from: ctx.accounts.player_token_account.to_account_info(),
            to: ctx.accounts.treasury_token_account.to_account_info(),
            authority: ctx.accounts.player.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);
        token::transfer(cpi_ctx, bet_amount)?;

        // Simulate ball path using randomness
        let seed = Clock::get()?.unix_timestamp.to_le_bytes();
        let mut position: i32 = 0; // Center position
        
        // Each row, ball can go left (-1) or right (+1)
        for _ in 0..rows {
            let random = common::generate_random_from_seed(&seed, 1);
            position += if random == 0 { -1 } else { 1 };
        }

        // Calculate multiplier based on final position
        // Center positions have higher multipliers
        let max_position = rows as i32;
        let multiplier_bps = calculate_multiplier(position, max_position)?;

        let game_state = &mut ctx.accounts.game_state;
        game_state.player = ctx.accounts.player.key();
        game_state.bet_amount = bet_amount;
        game_state.game_id = Clock::get()?.unix_timestamp as u64;
        game_state.timestamp = Clock::get()?.unix_timestamp;
        game_state.settled = false;
        game_state.result = Some(position as u64);
        game_state.bump = ctx.bumps.game_state;

        let payout = common::calculate_payout(bet_amount, multiplier_bps, config.house_edge_bps)?;
        game_state.payout = Some(payout);
        
        // Transfer payout to player
        let seeds = &[
            b"treasury",
            ctx.accounts.config.to_account_info().key.as_ref(),
            &[ctx.accounts.config.bump],
        ];
        let signer = &[&seeds[..]];
        
        let cpi_accounts = Transfer {
            from: ctx.accounts.treasury_token_account.to_account_info(),
            to: ctx.accounts.player_token_account.to_account_info(),
            authority: ctx.accounts.config.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new_with_signer(cpi_program, cpi_accounts, signer);
        token::transfer(cpi_ctx, payout)?;

        game_state.settled = true;
        Ok(())
    }

    fn calculate_multiplier(position: i32, max_position: i32) -> Result<u64> {
        // Center = highest multiplier (up to 1000x = 10000000 bps)
        // Edges = lower multiplier
        let distance_from_center = position.abs();
        let max_distance = max_position;
        
        // Multiplier decreases as distance from center increases
        let multiplier = if distance_from_center == 0 {
            10000000 // 1000x at center
        } else {
            let reduction = (distance_from_center * 500000) / max_distance; // Reduce by distance
            (10000000u64)
                .checked_sub(reduction as u64)
                .unwrap_or(100000) // Minimum 10x
        };
        
        Ok(multiplier)
    }

    pub fn pause(ctx: Context<Pause>) -> Result<()> {
        let config = &mut ctx.accounts.config;
        require!(
            ctx.accounts.authority.key() == config.authority,
            common::CasinoError::Unauthorized
        );
        config.paused = true;
        Ok(())
    }

    pub fn unpause(ctx: Context<Pause>) -> Result<()> {
        let config = &mut ctx.accounts.config;
        require!(
            ctx.accounts.authority.key() == config.authority,
            common::CasinoError::Unauthorized
        );
        config.paused = false;
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(
        init,
        payer = authority,
        space = common::GameConfig::LEN,
        seeds = [b"config", b"plinko"],
        bump
    )]
    pub config: Account<'info, common::GameConfig>,
    
    #[account(mut)]
    pub authority: Signer<'info>,
    
    /// CHECK: Treasury account
    pub treasury: UncheckedAccount<'info>,
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct Play<'info> {
    #[account(
        seeds = [b"config", b"plinko"],
        bump = config.bump
    )]
    pub config: Account<'info, common::GameConfig>,
    
    #[account(mut)]
    pub player: Signer<'info>,
    
    #[account(mut)]
    pub player_token_account: Account<'info, TokenAccount>,
    
    #[account(mut)]
    pub treasury_token_account: Account<'info, TokenAccount>,
    
    /// CHECK: Treasury PDA
    #[account(
        seeds = [b"treasury", config.key().as_ref()],
        bump
    )]
    pub treasury: UncheckedAccount<'info>,
    
    #[account(
        init,
        payer = player,
        space = common::GameState::LEN,
        seeds = [b"game", player.key().as_ref(), &Clock::get()?.unix_timestamp.to_le_bytes()],
        bump
    )]
    pub game_state: Account<'info, common::GameState>,
    
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
    pub clock: Sysvar<'info, Clock>,
}

#[derive(Accounts)]
pub struct Pause<'info> {
    #[account(
        mut,
        seeds = [b"config", b"plinko"],
        bump = config.bump
    )]
    pub config: Account<'info, common::GameConfig>,
    pub authority: Signer<'info>,
}

