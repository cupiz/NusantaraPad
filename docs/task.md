# NusantaraPad IDO Launchpad - Development Tasks

## Phase 1: Smart Contract Core ✅

- [x] Create implementation plan for smart contracts
- [x] Initialize Foundry project with BSC configuration
- [x] Create `MockTKO.sol` - BEP-20 token for testnet simulation
- [x] Create `TKOStaking.sol` - Staking system with tier calculation
- [x] Create `IDOPool.sol` - Individual pool logic with vesting
- [x] **Smart Contracts (Foundry)**
  - [x] Install & Config Foundry
  - [x] Fix Tests (TKOStaking & IDOPool)
  - [x] Deploy to Anvil Local (MockTKO, Staking, Factory)
  - [x] Deploy IDO Pool ($MARS)

## Phase 2: Frontend Configuration ✅

- [x] **Frontend Configuration**
  - [x] Next.js 16 + Wagmi v2 Setup
  - [x] Fix Client/Server Hydration Issues
  - [x] Configure Anvil Chain (ID 31337)

## Phase 3: UI Implementation ✅

- [x] Design System (Deep Space DeFi)
- [x] Staking Page (Integration Verified)
- [x] Pools Listing Page (Factory Integration)
- [x] Pool Details Page (Participation Verified)
- [x] Implement real-time pool progress updates

## Phase 4: Admin Features & Metadata

- [x] **Metadata API**
  - [x] Create Next.js API Route (`/api/pools`)
  - [x] Implement JSON file storage for pool metadata
- [x] **Admin Dashboard**
  - [x] Create `/admin` page
  - [x] Build "Create Pool" form (Token, Price, Caps, Vesting)
  - [x] Integrate `IDOFactory.createPool` write function
  - [x] Add "Project Info" fields and save to Metadata API

### Phase 5: Frontend Enhancements

- [x] Dynamic Pools Page
- [x] Vesting Chart Implementation
- [x] Enhance Pool Details (Metadata + Navbar + Owner Admin)
- [x] Move Description below Grid
  - [x] Debug Address Case Sensitivity
  - [x] Add Diagnostic Messages for Claiming
  - [x] Fix BigInt Serialization in Debuggert to Pool Details

## Phase 6: Release Preparation

- [x] Review Documentation (README.md)
- [x] Clean up Codebase
- [x] Final Manual Verification
- [x] Git Push Updatestlkthrough

## Phase 2: Production Readiness (Next)

- [x] **Metadata & Indexing (Supabase)**
  - [x] Install `@supabase/supabase-js`
  - [x] Rewrite `/api/pools` to use Supabase Client
  - [x] Create Migration SQL
  - [x] Update frontend to fetch pool list from Supabase
  - [x] Verify End-to-End flow (Frontend Configured)
  - [/] Debug User Deployment Error (Address mismatch?)
