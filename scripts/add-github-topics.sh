#!/bin/bash

# Script to add GitHub topics to repository
# Requires GitHub CLI (gh) to be installed and authenticated

REPO="LaChance-Lab/EVM-Solana-Casino-Games"

TOPICS=(
  "solana"
  "solana-casino-game"
  "solana-smart-contracts"
  "evm"
  "ethereum"
  "casino-games"
  "provably-fair"
  "web3-games"
  "blockchain-games"
  "smart-contracts"
  "anchor"
  "rust"
  "solidity"
  "foundry"
  "hardhat"
  "vrf"
  "chainlink-vrf"
  "orao-vrf"
  "crash-game"
  "plinko"
  "dice-game"
  "blackjack"
  "roulette"
  "poker"
  "slots"
  "coinflip"
  "lottery"
  "multi-chain"
  "defi"
  "web3"
  "crypto-games"
  "decentralized-casino"
  "blockchain-casino"
  "on-chain-games"
)

echo "Adding topics to $REPO..."
echo ""

# Build topic string
TOPIC_STRING=$(IFS=','; echo "${TOPICS[*]}")

# Add topics using GitHub CLI
gh repo edit "$REPO" --add-topic "$TOPIC_STRING"

if [ $? -eq 0 ]; then
  echo "✅ Successfully added topics!"
  echo ""
  echo "Topics added:"
  for topic in "${TOPICS[@]}"; do
    echo "  - $topic"
  done
else
  echo "❌ Failed to add topics. Make sure:"
  echo "  1. GitHub CLI (gh) is installed: https://cli.github.com/"
  echo "  2. You're authenticated: gh auth login"
  echo "  3. You have write access to the repository"
fi
