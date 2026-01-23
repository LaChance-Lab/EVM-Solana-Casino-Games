# Getting Started Guide

## Quick Start (5 Minutes)

### Prerequisites

**Required:**
- Node.js 18+ ([Download](https://nodejs.org/))
- Rust 1.70+ ([Install](https://www.rust-lang.org/tools/install))
- Solana CLI 1.16+ ([Install](https://docs.solana.com/cli/install-solana-cli-tools))
- Anchor 0.29+ ([Install](https://www.anchor-lang.com/docs/installation))

**For EVM Development:**
- Foundry ([Install](https://book.getfoundry.sh/getting-started/installation)) OR
- Hardhat ([Install](https://hardhat.org/getting-started))

### Step 1: Clone Repository

```bash
git clone https://github.com/LaChance-Lab/EVM-Solana-Casino-Games.git
cd EVM-Solana-Casino-Games
```

### Step 2: Install Dependencies

**Solana:**
```bash
cd web3/solana
npm install
anchor build
```

**EVM:**
```bash
cd web3/evm
npm install
# For Foundry
forge install
forge build
# OR for Hardhat
npx hardhat compile
```

**Frontend:**
```bash
cd frontend
npm install
npm run dev
# Open http://localhost:3000
```

### Step 3: Run Tests

**Solana:**
```bash
cd web3/solana
anchor test
```

**EVM:**
```bash
cd web3/evm
# Foundry
forge test -vvv
# OR Hardhat
npx hardhat test
```

## Deployment

### Deploy to Solana Devnet

```bash
cd web3/solana
anchor deploy --provider.cluster devnet
```

### Deploy to Ethereum Sepolia

```bash
cd web3/evm
forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --verify
```

## Next Steps

1. **Read Documentation:**
   - [Architecture Guide](./ARCHITECTURE.md)
   - [API Documentation](./API.md)
   - [Deployment Guide](./DEPLOYMENT.md)

2. **Explore Examples:**
   - Check `examples/solana/` for Solana examples
   - Check `examples/evm/` for EVM examples

3. **Customize:**
   - Configure your tokens
   - Set up liquidity pools
   - Customize game parameters

4. **Deploy:**
   - Deploy to testnet first
   - Test thoroughly
   - Deploy to mainnet

## Common Issues

### Rust/Anchor Issues
- Ensure Rust is up to date: `rustup update`
- Reinstall Anchor: `avm install latest && avm use latest`

### Node.js Issues
- Use Node.js 18+ (check with `node --version`)
- Clear cache: `npm cache clean --force`

### Solana CLI Issues
- Update Solana CLI: `solana-install update`
- Check config: `solana config get`

## Getting Help

- 📖 [Documentation](./)
- 💬 [GitHub Discussions](https://github.com/LaChance-Lab/EVM-Solana-Casino-Games/discussions)
- 🐛 [Report Issues](https://github.com/LaChance-Lab/EVM-Solana-Casino-Games/issues)
- 📱 [Telegram](https://t.me/lachancelab)

---

**Ready to build?** Start with our [Architecture Guide](./ARCHITECTURE.md)!
