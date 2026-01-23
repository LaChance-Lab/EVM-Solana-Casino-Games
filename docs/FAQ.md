# Frequently Asked Questions (FAQ)

## General Questions

### What is this project?
This is a multi-chain casino games platform providing 10 provably fair casino games with smart contracts for Solana and EVM-compatible chains. It enables developers to build decentralized casino platforms with transparent, verifiable outcomes.

### Which blockchains are supported?
Currently supported:
- 🟣 **Solana** (Mainnet Beta)
- 🔵 **Ethereum** (Mainnet)
- 🔷 **Base** (Mainnet)
- 🔴 **Arbitrum** (One)
- 🟣 **Polygon** (PoS)

Planned: Sui, Cardano, Bitcoin

### What games are included?
1. 🎯 **Plinko** - Drop the ball, win multipliers up to 1000x
2. 📈 **Crash** - Cash out before it crashes
3. 🎲 **Dice** - Roll under or over your target
4. 💰 **Jackpot** - Community progressive jackpot
5. 🪙 **CoinFlip** - Simple 50/50 chance, 1.95x payout
6. 🎰 **Slots** - Match 3 symbols, up to 25x payout
7. 🃏 **Poker** - Texas Hold'em tournaments
8. 🂡 **Blackjack** - Beat the dealer to 21
9. 🎡 **Roulette** - European & American variants
10. 🎟️ **Lottery** - Pick 6 numbers, progressive jackpot

### Is this provably fair?
Yes! All games use Verifiable Random Function (VRF) technology:
- **Solana:** ORAO VRF
- **EVM Chains:** Chainlink VRF

All outcomes can be independently verified on-chain.

## Technical Questions

### What programming languages are used?
- **Solana:** Rust with Anchor framework
- **EVM Chains:** Solidity with Foundry/Hardhat

### How do I deploy the contracts?
See our deployment guides:
- [Solana Deployment Guide](./DEPLOYMENT.md#solana)
- [EVM Deployment Guide](./DEPLOYMENT.md#evm)

### Can I use custom tokens?
Yes! The platform supports:
- **Solana:** Any SPL token (USDC, USDT, custom tokens)
- **EVM:** Any ERC-20 token (USDC, USDT, DAI, custom tokens)

### What is the house edge?
Configurable per game and pool. Typical ranges:
- CoinFlip: 2.5%
- Dice: 1-3% (depends on probability)
- Blackjack: 0.5-1% (with optimal play)
- Slots: 2-5% (varies by symbol combinations)

### How does VRF work?
1. Game requests randomness from VRF provider
2. VRF generates verifiable random number
3. Random number is used to determine game outcome
4. Outcome can be verified by anyone using VRF proof

## Security Questions

### Are the contracts audited?
Yes, all contracts undergo security audits before deployment. See [SECURITY.md](../SECURITY.md) for details.

### How are funds secured?
- Multi-signature wallets for treasury
- Time-locks for withdrawals
- Emergency pause mechanisms
- Segregated player funds
- Regular security audits

### Can the house manipulate outcomes?
No. All randomness comes from audited VRF providers (Chainlink, ORAO). The house cannot influence outcomes.

### What happens if there's a bug?
- Emergency pause mechanism can halt all games
- Funds are secured in multi-sig wallets
- Bug bounty program for responsible disclosure
- Regular security audits

## Usage Questions

### Can I use this commercially?
Yes! This is open-source under MIT license. You can:
- Use for commercial projects
- Modify the code
- Deploy your own instance
- White-label for clients

### Do you offer support?
- **Community:** GitHub Discussions
- **Issues:** GitHub Issues
- **Business:** Contact via Telegram @lachancelab

### How do I integrate this into my project?
1. Clone the repository
2. Deploy contracts to your target chain
3. Integrate frontend components
4. Configure your tokens and pools
5. See [GETTING_STARTED.md](./GETTING_STARTED.md) for details

### Is there a Telegram bot?
Yes! The repository includes a Telegram bot for in-chat gaming. See `telegram-bot/` directory.

## Business Questions

### Do you offer white-label solutions?
Yes! Contact us via Telegram @lachancelab for:
- Custom game development
- White-label casino platforms
- Chain integrations
- UI/UX design
- Security audits
- Marketing & launch support

### What are the licensing terms?
MIT License - see [LICENSE](../LICENSE) file.

### Can I contribute?
Absolutely! See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

## Performance Questions

### What are the gas costs?
**EVM Chains:**
- Game play: ~50,000-200,000 gas (depends on game)
- VRF request: ~100,000-300,000 gas
- Total: ~$0.50-$5 per game (varies by chain)

**Solana:**
- Game play: ~5,000-50,000 compute units
- VRF request: Included in transaction
- Total: ~$0.001-$0.01 per game

### How fast are transactions?
- **Solana:** ~400ms confirmation
- **EVM Chains:** ~2-15 seconds (depends on chain)

### Can it handle high traffic?
Yes, the architecture is designed for scalability:
- Stateless smart contracts
- Off-chain RNG service (optional)
- Load-balanced backend
- CDN for frontend assets

## Troubleshooting

### Contracts won't deploy
- Check your RPC endpoint
- Verify you have sufficient funds
- Check network compatibility
- Review error logs

### VRF not working
- Verify VRF provider is configured
- Check subscription/account funding
- Ensure correct network (mainnet/testnet)
- Review VRF provider documentation

### Frontend won't connect
- Check wallet extension is installed
- Verify network configuration
- Check RPC endpoint is accessible
- Review browser console for errors

---

**Have more questions?** Open a GitHub Discussion or contact us via Telegram @lachancelab
