use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

declare_id!("Dice1111111111111111111111111111111111");

#[program]
pub mod dice {
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

    pub fn play(ctx: Context<Play>, bet_amount: u64, target: u8, roll_under: bool) -> Result<()> {
        let config = &ctx.accounts.config;
        require!(!config.paused, common::CasinoError::GameNotActive);
        require!(target > 0 && target < 100, common::CasinoError::InvalidBetAmount);
        
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

        // Generate random roll (1-100)
        let seed = Clock::get()?.unix_timestamp.to_le_bytes();
        let roll = common::generate_random_from_seed(&seed, 99) + 1; // 1-100

        let game_state = &mut ctx.accounts.game_state;
        game_state.player = ctx.accounts.player.key();
        game_state.bet_amount = bet_amount;
        game_state.game_id = Clock::get()?.unix_timestamp as u64;
        game_state.timestamp = Clock::get()?.unix_timestamp;
        game_state.settled = false;
        game_state.result = Some(roll as u64);
        game_state.bump = ctx.bumps.game_state;

        // Calculate win condition and multiplier
        let won = if roll_under {
            roll < target
        } else {
            roll > target
        };

        if won {
            // Calculate multiplier based on probability
            let probability = if roll_under {
                (target - 1) as u64
            } else {
                (100 - target) as u64
            };
            
            // Multiplier = 10000 / probability (with house edge)
            let multiplier = (10000u64)
                .checked_mul(10000)
                .and_then(|x| x.checked_div(probability))
                .ok_or(common::CasinoError::MathOverflow)?;
            
            let payout = common::calculate_payout(bet_amount, multiplier, config.house_edge_bps)?;
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
        } else {
            game_state.payout = Some(0);
        }

        game_state.settled = true;
        Ok(())
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
        seeds = [b"config", b"dice"],
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
        seeds = [b"config", b"dice"],
        bump = config.bump
    )]
    pub config: Account<'info, common::GameConfig>,
    
    #[account(mut)]
    pub player: Signer<'info>,
    
    #[account(
        mut,
        constraint = player_token_account.owner == player.key()
    )]
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
        seeds = [b"config", b"dice"],
        bump = config.bump
    )]
    pub config: Account<'info, common::GameConfig>,
    pub authority: Signer<'info>,
}

