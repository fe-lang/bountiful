# Bounty Hunting Guide

This is a step-by-step guide for developers (and AI agents) who want to participate in the Bountiful bug bounty. The goal: find a bug in the Fe compiler that lets you bring an "unsolvable" puzzle into its solved state — and claim ETH for it.

## Background

Each challenge is a 15-puzzle deployed in an [unsolvable initial state](https://en.wikipedia.org/wiki/15_puzzle#Solvability). The board `[1, 2, ..., 13, 15, 14, 0]` has tiles 14 and 15 swapped with the empty cell at position 15. Under correct puzzle rules this state **cannot** be solved. If you manage to solve it anyway, that means you found a bug in the Fe compiler.

The winning board state is:

```
 1  2  3  4
 5  6  7  8
 9 10 11 12
13 14 15  _
```

Where `_` is the empty cell (value `0`) at index 15.

## Prerequisites

- [Fe compiler](https://fe-lang.org/) installed (must be version [v26.1.0](https://github.com/argotorg/fe/releases/tag/v26.1.0))
- [Foundry](https://book.getfoundry.sh/) installed (`forge`, `cast`)
- GNU Make
- An Ethereum wallet with ETH on mainnet (for the lock deposit and gas)
- An Ethereum mainnet RPC endpoint

## Step 1: Clone and build the project

```bash
git clone https://github.com/cburgdorf/bountiful.git
cd bountiful
make build
```

Verify everything works:

```bash
make test
```

## Step 2: Understand the contracts

There are four game variants, each exercising different Fe features. All implement the same interface:

| Contract | Storage approach | Fe features |
|---|---|---|
| `Game` | `StorageMap<u256, u256>` | Storage maps, encoding |
| `Game2D` | `[[u256; 4]; 4]` | 2D nested arrays |
| `GameEnum` | `[u256; 16]` + enums | Enums, match, struct methods |
| `GameBitboard` | single `u256` | Bitwise ops, bitpacking |
| `GameTrait` | `[u256; 16]` + traits | Trait dispatch, default methods |
| `GameNested` | nested structs | Struct composition, field access |
| `GameMonadic` | single `u256` | Functional combinators |

### Design Philosophy & Attack Surface

**Important Note:** These contracts are **not written for efficiency or gas optimization.** On the contrary, they are intentionally designed to maximize the "surface area" of the Fe language features they exercise.

For example, `Game.fe` searches for the empty cell (`0`) across the entire board every time `moveField` is called, instead of simply storing its index. This is done to force the compiler to repeatedly handle storage maps and loop iterations, increasing the chance of exposing a bug in those subsystems.

As a bounty hunter, you should look for exploits in these "inefficient" patterns, as they are specifically chosen to stress-test the Fe compiler's type system, storage management, and code generation.

Each game contract exposes these messages (Solidity ABI):

| Function | Description |
|---|---|
| `getBoard(uint256 index) -> uint256` | Read the value at a board position (0-15) |
| `isSolved() -> bool` | Returns `true` if the board is in the winning state |
| `moveField(uint256 index)` | Slide the tile at `index` into the adjacent empty cell. Reverts on error |

The board is initialized via the constructor with a packed `u256` (4 bits per cell). There is no external `setCell` function.

Note: `Game2D` uses `moveField(uint256 row, uint256 col)` and `getBoard(uint256 row, uint256 col)` instead of a single index.

**Important:** `moveField` requires that you hold a valid lock on the challenge (see Step 4). The game contract calls back to the registry via `validateOwnsLock(owner, challenge)` to verify this. If the lock validation fails, the transaction reverts.

## Step 3: Find an exploit locally

This is the core of the bounty hunt. You need to find a Fe compiler bug that lets you bring the puzzle from its unsolvable initial state into the solved state.

Possible attack vectors to explore:

- **Arithmetic bugs** — Does the compiler miscompile integer operations, comparisons, or bitwise ops? Could an overflow or underflow go undetected?
- **Storage bugs** — Could there be issues with how `StorageMap`, arrays, or packed storage are read/written? Could you corrupt adjacent storage slots?
- **Control flow bugs** — Are `if`/`while`/`match` compiled correctly? Could a branch go the wrong way?
- **ABI encoding bugs** — Could malformed calldata trick the contract into accepting an invalid move or writing unexpected values?
- **Type system bugs** — Could enum variants, struct fields, or array indexing produce wrong values?

### How to test locally

Write a Foundry test that deploys a game, initializes the unsolvable board, and attempts your exploit. The existing tests in `test/` are a good starting point. Here is a minimal template:

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {FeDeployer} from "../src/FeDeployer.sol";
import {ISolvable} from "../src/interfaces/ISolvable.sol";
import {UNSOLVABLE_BOARD} from "../src/Constants.sol";

interface IGame {
    function moveField(uint256 index) external;
    function getBoard(uint256 index) external view returns (uint256);
}

contract ExploitTest is Test {

    function test_exploit() public {
        // Deploy a DummyLockValidator that never reverts (lock always valid)
        address validator = FeDeployer.deployFeWithArgs(
            vm,
            "contracts/out/DummyLockValidator.bin",
            abi.encode(false)
        );

        // Deploy the game variant you want to attack
        address gameAddr = FeDeployer.deployFeWithArgs(
            vm,
            "contracts/out/Game.bin",  // or Game2D, GameEnum, GameBitboard
            abi.encode(validator, UNSOLVABLE_BOARD)
        );
        IGame game = IGame(gameAddr);

        // Verify not solved
        assertFalse(ISolvable(gameAddr).isSolved());

        // =============================================
        // YOUR EXPLOIT HERE
        // =============================================
        // Try to bring the board into the solved state.
        // e.g., game.moveField(...);
        // or send raw calldata via address(game).call(...)

        // If your exploit works, this should pass:
        assertTrue(ISolvable(gameAddr).isSolved());
    }
}
```

Run it:

```bash
make build  # ensure fresh Fe artifacts
forge test --match-test test_exploit -vvvv
```

The `-vvvv` flag gives you full EVM traces, which is helpful for debugging.

## Step 4: Acquire a lock on-chain

Once you have a working exploit locally, it's time to claim the bounty. But first you need to acquire an exclusive lock to prevent front-running.

```bash
# Set your environment
export ETH_RPC_URL="https://..."
export PRIVATE_KEY="0x..."
export REGISTRY="<registry-contract-address>"
export CHALLENGE="<game-contract-address>"
```

Check if the challenge is open and unlocked:

```bash
cast call $REGISTRY "isOpenChallenge(address)(bool)" $CHALLENGE --rpc-url $ETH_RPC_URL
cast call $REGISTRY "isLocked(address)(bool)" $CHALLENGE --rpc-url $ETH_RPC_URL
```

Acquire the lock (you must send the required deposit, default 0.01 ETH):

```bash
cast send $REGISTRY "lock(address)" $CHALLENGE \
    --value 0.01ether \
    --private-key $PRIVATE_KEY \
    --rpc-url $ETH_RPC_URL
```

The transaction succeeds if the lock is acquired. It reverts if:

| Error | Meaning |
|---|---|
| `AlreadyLocked` | Someone else holds the lock |
| `InvalidClaim` | Challenge is not registered |
| `InvalidDeposit` | You sent less ETH than required |

You now have **100 blocks** (~20 minutes) of exclusive access.

## Step 5: Wait a few blocks before revealing your solution

**Do not submit your exploit transaction immediately after locking.** Your exploit transaction will be visible in the public mempool before it's mined. If your lock hasn't been confirmed yet, an observer could see *how* your exploit works and front--run you by acquiring the lock themselves and claiming the prize before you.

If your exploit applies to multiple game variants, acquire locks for **all** of them before revealing any solution. Each lock is per-challenge, so you can hold multiple locks simultaneously. Otherwise someone watching the mempool could grab the remaining challenges before you get to them.

Wait a few blocks until all your locks are safely on-chain. Only then submit the exploit(s). Monitor the current block number:

```bash
cast block-number --rpc-url $ETH_RPC_URL
```

## Step 6: Execute the exploit on-chain

Replay your exploit against the live challenge contract. For example, if your exploit involves calling `moveField`:

```bash
cast send $CHALLENGE "moveField(uint256)" <tile_index> \
    --private-key $PRIVATE_KEY \
    --rpc-url $ETH_RPC_URL
```

Or if you need to send raw calldata:

```bash
cast send $CHALLENGE <raw-calldata-hex> \
    --private-key $PRIVATE_KEY \
    --rpc-url $ETH_RPC_URL
```

Verify the puzzle is now solved:

```bash
cast call $CHALLENGE "isSolved()(bool)" --rpc-url $ETH_RPC_URL
```

## Step 7: Claim the prize

```bash
cast send $REGISTRY "claim(address)" $CHALLENGE \
    --private-key $PRIVATE_KEY \
    --rpc-url $ETH_RPC_URL
```

The transaction succeeds and the prize is transferred to your address. The challenge is then marked as closed. The transaction reverts if:

| Error | Meaning |
|---|---|
| `MissingLock` | You don't hold a valid lock |
| `InvalidClaim` | Puzzle is not solved or challenge is closed |

## Tips

- **Try all seven game variants.** Each uses different Fe features and may expose different compiler bugs.
- **Read the Fe source code**, not just the Solidity interfaces. The bugs are in how Fe compiles to EVM bytecode.
- **Use `forge test -vvvv`** to get full EVM execution traces when developing your exploit.
- **Use `cast call`** (read-only) before `cast send` (transaction) to verify your calls will succeed.
- **Don't broadcast your exploit** before acquiring a lock. Mempool watchers can front-run unprotected transactions.
- **Your lock deposit is not refunded.** It stays in the registry contract. Only claim if you're confident the exploit works on-chain.
- **Always run `make build`** before Forge tests to ensure you're testing against current Fe bytecode.

## Command Line Cheat Sheet

Set these variables first:
```bash
export RPC_URL="https://..."
export REGISTRY="0x..."
export CHALLENGE="0x..."
export PLAYER="0x..."
export PRIV_KEY="0x..."
```

### Registry Queries
Check if a challenge is open:
```bash
cast call $REGISTRY "isOpenChallenge(address)(bool)" $CHALLENGE --rpc-url $RPC_URL
```

Check if a challenge is currently locked:
```bash
cast call $REGISTRY "isLocked(address)(bool)" $CHALLENGE --rpc-url $RPC_URL
```

Get the prize balance of the entire registry:
```bash
cast call $REGISTRY "getBalance()(uint256)" --rpc-url $RPC_URL
```

### Game Queries
Check if the puzzle is solved:
```bash
cast call $CHALLENGE "isSolved()(bool)" --rpc-url $RPC_URL
```

Read a specific cell (0-15):
```bash
cast call $CHALLENGE "getBoard(uint256)(uint256)" 14 --rpc-url $RPC_URL
```

Read the entire board (helper loop):
```bash
for i in {0..15}; do 
  echo -n "Cell $i: "
  cast call $CHALLENGE "getBoard(uint256)(uint256)" $i --rpc-url $RPC_URL
done
```

### Transactions
Acquire a lock (needs 0.01 ETH deposit):
```bash
cast send $REGISTRY "lock(address)" $CHALLENGE \
  --value 0.01ether --private-key $PRIV_KEY --rpc-url $RPC_URL
```

Move a tile (only if you hold the lock):
```bash
cast send $CHALLENGE "moveField(uint256)" 14 \
  --private-key $PRIV_KEY --rpc-url $RPC_URL
```

Claim the prize (after solving the puzzle):
```bash
cast send $REGISTRY "claim(address)" $CHALLENGE \
  --private-key $PRIV_KEY --rpc-url $RPC_URL
```

### Useful Tools
Convert a decimal error code from a revert to its name:
```bash
# Example: 4 -> AlreadyLocked
# See shared/src/lib.fe for the full enum mapping
```

Decode raw return data:
```bash
cast --decode "isSolved()(bool)" 0x0000000000000000000000000000000000000000000000000000000000000001
```
