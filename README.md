# Bountiful

Bountiful is an on-chain bug bounty platform for the [Fe programming language](https://fe-lang.org/). It deploys Fe smart contracts that should uphold certain invariants. If a bounty hunter can break those invariants — by exploiting a bug in the Fe compiler or the contract logic — they can claim ETH prize money permissionlessly, directly from the contract.

## Current challenges

Four different implementations of the [15 puzzle game](https://15puzzle.netlify.app/), each initialized to an unsolvable board state. Each variant exercises different Fe language features:

| Contract | Fe features exercised |
|---|---|
| **Game** | `StorageMap<u256, u256>`, encoding utilities |
| **Game2D** | 2D nested arrays (`[[u256; 4]; 4]`), coordinate math |
| **GameEnum** | Enums, `match` expressions, structs with `impl` methods |
| **GameBitboard** | Bitwise operations, single-slot `u256` bitpacking |

All game contracts implement the `ISolvable` interface (`isSolved() -> bool`).

## Tech stack

- **Contracts**: [Fe 26.0.0-alpha.8](https://fe-lang.org/) (primary) + Solidity (interfaces, deployment, tests)
- **Build & test**: [Foundry](https://book.getfoundry.sh/) (forge)
- **Network**: Ethereum mainnet
- **Website**: [Zola](https://www.getzola.org/) static site generator

## Project structure

```
contracts/           Fe workspace (3 ingots)
  ingots/registry/   BountyRegistry contract
  ingots/games/      Four 15-puzzle implementations
  ingots/shared/     Shared types, errors, constants
src/                 Solidity interfaces + FeDeployer helper
test/                Foundry test suite
script/              Foundry deployment script
web/                 Zola-based website with interactive puzzle
```

## Getting started

```bash
git clone https://github.com/cburgdorf/bountiful.git
cd bountiful
```

### Build

```bash
cd contracts && fe build && cd ..
forge build
```

### Test

```bash
forge test
```

### Deploy (Mainnet)

```bash
export DEPLOYER_PRIVATE_KEY=0x...
export MAINNET_RPC_URL=https://...
export LOCK_DEPOSIT=10000000000000000  # optional, defaults to 0.01 ETH
forge script script/Deploy.s.sol --rpc-url $MAINNET_RPC_URL --broadcast
```

### Run the website locally

```bash
cd web && zola serve
```

## How the bounty works

[Ethereum is a dark forest](https://www.paradigm.xyz/2020/08/ethereum-is-a-dark-forest) — any profitable transaction can be front-run by MEV bots. Bountiful uses a per-challenge locking mechanism to prevent this:

1. **Find an exploit locally** — attack the contracts on your own machine first.
2. **Acquire a lock** — call `registry.lock(challengeAddress)` and pay the lock deposit. This gives you exclusive access to that challenge for 100 blocks.
3. **Wait a few blocks** — let your lock settle to be safe.
4. **Solve the challenge** — replay your exploit on-chain. No one else can interact with the locked challenge.
5. **Claim the prize** — call `registry.claim(challengeAddress)`. The registry verifies the challenge is solved and transfers the prize money.

## Administrative operations

### Withdraw funds

When a challenge is not locked, the admin can withdraw funds. This is used to migrate to newer versions of the system.

```bash
# Via the registry contract's withdraw() function
```

### Register / remove challenges

The admin can register new challenge contracts or remove existing ones (when unlocked) through the `BountyRegistry` contract.

## Documentation

- **[Bounty Hunting Guide](doc/bounty-hunting-guide.md)** — Step-by-step walkthrough for finding exploits and claiming prizes
- **[AGENTS.md](AGENTS.md)** — Structured reference for AI agents hunting bounties
- 