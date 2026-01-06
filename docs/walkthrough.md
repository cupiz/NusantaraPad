# NusantaraPad Implementation Walkthrough

## Completed: All 3 Phases ✅

---

## Phase 1: Smart Contracts

| Contract | Purpose |
|----------|---------|
| [MockTKO.sol](file:///d:/Project/Web3/NusantaraPad/src/mocks/MockTKO.sol) | Testnet BEP-20 with `mint()` |
| [TKOStaking.sol](file:///d:/Project/Web3/NusantaraPad/src/staking/TKOStaking.sol) | Tier-based staking, lock multipliers |
| [IDOPool.sol](file:///d:/Project/Web3/NusantaraPad/src/ido/IDOPool.sol) | Participation, Merkle proofs, vesting |
| [IDOFactory.sol](file:///d:/Project/Web3/NusantaraPad/src/ido/IDOFactory.sol) | CREATE2 pool deployment |
| [TransientReentrancyGuard.sol](file:///d:/Project/Web3/NusantaraPad/src/libraries/TransientReentrancyGuard.sol) | EIP-1153 gas-optimized guard |

**Key Feature:** Uses `TSTORE`/`TLOAD` for ~100 gas savings on reentrancy checks.

---

## Phase 2: Frontend Configuration

| File | Purpose |
|------|---------|
| [wagmi.ts](file:///d:/Project/Web3/NusantaraPad/frontend/src/config/wagmi.ts) | Wagmi v3 + RainbowKit for BSC |
| [abis.ts](file:///d:/Project/Web3/NusantaraPad/frontend/src/config/abis.ts) | Type-safe contract ABIs |
| [useStaking.ts](file:///d:/Project/Web3/NusantaraPad/frontend/src/hooks/useStaking.ts) | Custom hook for staking interactions |
| [useIDOPool.ts](file:///d:/Project/Web3/NusantaraPad/frontend/src/hooks/useIDOPool.ts) | Custom hook for IDO participation |

---

## Phase 3: UI Implementation

| Component | Features |
|-----------|----------|
| [StakingVaultCard](file:///d:/Project/Web3/NusantaraPad/frontend/src/components/StakingVaultCard.tsx) | Lock duration slider, tier display, real-time calc |
| [IDOCard](file:///d:/Project/Web3/NusantaraPad/frontend/src/components/IDOCard.tsx) | Progress bar with phase colors |
| [ProjectDetail](file:///d:/Project/Web3/NusantaraPad/frontend/src/app/pools/%5Baddress%5D/page.tsx) | Approve → Buy two-step flow |

**Design:** "Deep Space DeFi" theme with glassmorphism, neon blue (#2F80ED), and gold tier highlights.

---

## Getting Started

```bash
# Smart Contracts
cd NusantaraPad
forge install OpenZeppelin/openzeppelin-contracts
forge test -vvv

# Frontend
cd frontend
npm run dev
# Open http://localhost:3000
```

## Phase 3: Frontend & Staking Integration

Successfully integrated the frontend with the smart contracts, implementing the "Deep Space DeFi" design system.

### Key Achievements

- **Staking UI**: Implemented `StakingVaultCard` with real-time balance fetching and Tier calculation.
- **Approval Flow**: Added ERC20 `approve` logic for TKO token before staking.
- **Wallet Connection**: Configured RainbowKit with Anvil Local chain for seamless testing.

### Verification

**Staking Interface**
Verified the display of User Balance and the "MAX" button functionality.
![Staking UI w/ Balance](C:/Users/Cupiz/.gemini/antigravity/brain/1c1c8c52-4108-482e-9e94-9a0adc8bb452/staking_ui_verified_1767639400533.png)

**Approval Logic**
Verified that the UI correctly switches to "Approve TKO" when allowance is insufficient.
![Approve Button](C:/Users/Cupiz/.gemini/antigravity/brain/1c1c8c52-4108-482e-9e94-9a0adc8bb452/staking_approve_check_1767640490509.png)

## Phase 4: IDO Launch Simulation

Deployed a test IDO pool for "Project Mars" to demonstrate the launchpad functionality.

### Key Achievements

- **Pool Deployment**: Scripted deployment of `MockTKO` (Project Token) and `IDOPool` via `IDOFactory`.
- **Time Travel**: Advanced local blockchain time to transition pool status from Upcoming to Live.
- **Pools Page**: Implemented `PoolsPage` fetching data directly from the Factory contract.

### Verification

**Live IDO Pool**
Verified that the pool appears on the listing page with the correct "Live" status after time advancement.
![Live IDO Pool](C:/Users/Cupiz/.gemini/antigravity/brain/1c1c8c52-4108-482e-9e94-9a0adc8bb452/pools_page_live_v2_1767645177253.png)

### User Verification

User confirmed successfully participating in the IDO ("Buy" transaction succeeded) after staking TKO properly.

## Phase 5: Admin Dashboard

Implemented a comprehensive Admin Dashboard for deploying new IDO pools without touching code.

### features

- **No-Code Deployment**: Create pools via UI form.
- **Dynamic Metadata**: Project Name, Description, and Logo are saved to a local JSON API.
- **Automatic Listing**: New pools automatically appear on the Pools Page.

**Admin Verification**
Verified that the Admin Page loads correctly and the Metadata API is functioning.
![Admin Dashboard](C:/Users/Cupiz/.gemini/antigravity/brain/1c1c8c52-4108-482e-9e94-9a0adc8bb452/admin_dashboard_verified_1767646507807.png)

### User Deployment Success

User successfully deployed a new pool **"Jonggol"** via the dashboard.
Verified presence on the Pools Page with correct metadata.
![Jonggol Pool](C:/Users/Cupiz/.gemini/antigravity/brain/1c1c8c52-4108-482e-9e94-9a0adc8bb452/pools_page_jonggol_1767647291563.png)

### UI Refinement: Vesting Chart

Added a visual **Vesting Chart** to the Project Details page.

- Displays TGE %, Cliff Duration, and Vesting Period.
- Visual timeline with status markers.
- *Status: Implemented & Integrated.*
![Vesting Chart Verification](C:/Users/Cupiz/.gemini/antigravity/brain/1c1c8c52-4108-482e-9e94-9a0adc8bb452/vesting_chart_verified_1767648167531.png)

## Phase 2: Production Readiness (Supabase)

### Metadata & Indexing

Integrated **Supabase** to replace local JSON storage and act as a "Lite Indexer".

- **Environment**: Configured `.env.local` with project URL.
- **API**: Updated `/api/pools` to read/write from Supabase `pools` table.
- **Frontend**: `PoolsPage` now fetches from the API instead of iterating the blockchain.
- **Status**: Integrated & Verified (Build passing).

![Supabase Integration Verified](C:/Users/Cupiz/.gemini/antigravity/brain/1c1c8c52-4108-482e-9e94-9a0adc8bb452/pools_page_verified_1767677903436.png)

### 4. Admin Controls & Layout Refinement

**Goal**: Empower pool owners and improve readability.

- **Owner Controls**: Added a dedicated panel for the pool creator to:
  - Approve Sale Tokens.
  - Deposit Sale Tokens (Required for claiming).
  - Finalize Pool (Required for vesting start).
- **Layout**: Moved the Project Description below the details grid to accommodate longer text.
- **Debugging**: Added a diagnostic footer to help troubleshoot address mismatches and state issues.
- **Claim**: Fixed issues preventing claim button activation (Debugged address case sensitivity & BigInt serialization).

## Next Steps

1. **Deploy to Testnet**: Run `forge script script/Deploy.s.sol --rpc-url <BSC_TESTNET_RPC>`
2. **Backend Metadata**: Ensure SQL migration is run in Supabase dashboard.
