# NusantaraPad

Production-ready IDO Launchpad on Binance Smart Chain centered around the $TKO token ecosystem.

## Features

- **Tier-Based Staking:** Bronze, Silver, Gold, Platinum tiers with multipliers.
- **IDO Factory:** No-code pool deployment via Admin Dashboard.
- **Vesting:** Flexible schedules with TGE, Cliff, and Linear Vesting.
- **Dynamic Metadata:** Off-chain project info (API/JSON) mapped to on-chain pools.
- **Participation:** Two-step Approve/Buy flow for ERC20 tokens.

## Tech Stack

- **Solidity:** ^0.8.28 with EIP-1153 Transient Storage
- **Framework:** Foundry (Forge)
- **Frontend:** Next.js 16, React 19, Tailwind CSS v4, Wagmi v3
- **Local Chain:** Anvil

## Quick Start

### 1. Smart Contracts (Foundry)

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install dependencies
forge install OpenZeppelin/openzeppelin-contracts

# Build & Test
forge build
forge test -vvv
```

### 2. Frontend (Next.js)

```bash
cd frontend

# Install dependencies
npm install

# Run development server
npm run dev
```

## Local Development Workflow

To run the full stack locally with a simulate blockchain:

1. **Start Anvil Chain**

   ```bash
   anvil --host 0.0.0.0
   ```

2. **Deploy Contracts**
   In a new terminal:

   ```bash
   # Deploy MockTKO, Staking, and Factory
   forge script script/DeployLocal.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
   ```

3. **Deploy Test Pool (Optional)**

   ```bash
   forge script script/DeployPool.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
   ```

4. **Verify Frontend**
   Open [http://localhost:3000](http://localhost:3000).
   - **Admin Dashboard:** [http://localhost:3000/admin](http://localhost:3000/admin) to create new pools.
   - **Pools Page:** [http://localhost:3000/pools](http://localhost:3000/pools) to view listed projects.

## Contracts Overview

| Contract | Description |
|----------|-------------|
| `MockTKO.sol` | BEP-20 token for testnet simulation |
| `TKOStaking.sol` | Staking with tier-based allocation |
| `IDOPool.sol` | Individual IDO with vesting & refunds |
| `IDOFactory.sol` | CREATE2 pool deployment factory |

## Tier System

| Tier | Stake Required | Allocation |
|------|----------------|------------|
| Bronze | 500 TKO | Lottery |
| Silver | 2,000 TKO | 1x Guaranteed |
| Gold | 10,000 TKO | 3x Guaranteed |
| Platinum | 50,000 TKO | 10x + Private |

## License

MIT
