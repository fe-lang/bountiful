# Bountiful — Agent Reference

This file is optimized for AI agents working on the Bountiful bug bounty. It contains all the structured information needed to find exploits in Fe smart contracts.

## Objective

Make `isSolved()` return `true` on a contract whose board is initialized to an unsolvable state. This proves a bug in the Fe compiler.

## Quick setup

```bash
git clone https://github.com/cburgdorf/bountiful.git
cd bountiful
make build     # compile Fe contracts
make test      # run Fe tests + Forge tests (rebuilds Fe first)
```

## Target contracts

The bugs are in the **Fe source code**, not in the Solidity. The Fe compiler may miscompile these contracts to incorrect EVM bytecode. Your job is to find inputs that exploit such miscompilations.

| Contract | Fe source | Binary | Storage approach |
|---|---|---|---|
| `Game` | `contracts/ingots/games/src/game.fe` | `contracts/out/Game.bin` | `StorageMap<u256, u256>` |
| `Game2D` | `contracts/ingots/games/src/game_2d.fe` | `contracts/out/Game2D.bin` | `[[u256; 4]; 4]` |
| `GameEnum` | `contracts/ingots/games/src/game_enum.fe` | `contracts/out/GameEnum.bin` | `[u256; 16]` + enums |
| `GameBitboard` | `contracts/ingots/games/src/game_bitboard.fe` | `contracts/out/GameBitboard.bin` | single `u256` bitpacked |

Shared code: `contracts/ingots/shared/src/lib.fe` (errors, constants, `Challenge` struct with `WordRepr`, cross-contract interfaces)

Registry: `contracts/ingots/registry/src/lib.fe` (locking, claiming, prize payouts)

## Board state

Initial (unsolvable):
```
index:  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
value:  1  2  3  4  5  6  7  8  9 10 11 12 13 14  0 15
```

Winning (target):
```
index:  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
value:  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15  0
```

The difference: tiles 14 and 15 are swapped, empty cell at index 14 instead of 15. This is a known unsolvable configuration of the 15-puzzle.

## Game contract ABI

```
getBoard(uint256 index) -> uint256        // read cell value at index (0-15)
isSolved() -> bool                        // true if board matches winning state
moveField(uint256 index)                  // slide tile into adjacent empty cell (reverts on error)
```

All game contracts are initialized via constructor with `abi.encode(lockValidator, packedBoard)`. The board is packed into a single `u256` (4 bits per cell, cell 0 at bits 0..3, cell 15 at bits 60..63).

`moveField` requires a valid lock. For local testing, deploy a `DummyLockValidator` with `abi.encode(false)` (no revert).

Note: `Game2D` uses `moveField(uint256 row, uint256 col)` and `getBoard(uint256 row, uint256 col)` instead of a single index.

## Error handling

All contract functions revert on error. Errors are defined in `contracts/ingots/shared/src/lib.fe`:

| Error | Description |
|---|---|
| `InvalidIndex` | Board index out of range (must be 0-15) |
| `NotMovable` | Tile is not adjacent to the empty cell |
| `MissingLock` | Caller doesn't hold a valid lock for the challenge |
| `AlreadyLocked` | Challenge is already locked by someone else |
| `InvalidClaim` | Challenge is not registered, not open, or not solved |
| `OnlyAdmin` | Only the admin can call this function |
| `InvalidDeposit` | Lock deposit amount is insufficient |
| `TransferFailed` | ETH transfer failed |
| `AlreadyRegistered` | Challenge is already registered |

## Exploit test template

Create `test/Exploit.t.sol`:

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {FeDeployer} from "../src/FeDeployer.sol";
import {ISolvable} from "../src/interfaces/ISolvable.sol";

interface IGame {
    function moveField(uint256 index) external;
    function getBoard(uint256 index) external view returns (uint256);
}

contract ExploitTest is Test {
    // Unsolvable board: [1,2,...,14,0,15] packed as 4 bits per cell
    uint256 constant UNSOLVABLE_BOARD = 0xF0EDCBA987654321;

    function test_exploit() public {
        // DummyLockValidator with false = never reverts (lock always valid)
        address validator = FeDeployer.deployFeWithArgs(
            vm, "contracts/out/DummyLockValidator.bin", abi.encode(false)
        );

        // Deploy target with unsolvable board (swap bin path for other variants)
        address gameAddr = FeDeployer.deployFeWithArgs(
            vm, "contracts/out/Game.bin", abi.encode(validator, UNSOLVABLE_BOARD)
        );
        IGame game = IGame(gameAddr);

        assertFalse(ISolvable(gameAddr).isSolved());

        // -------------------------------------------
        // YOUR EXPLOIT HERE
        // -------------------------------------------
        // Options:
        //   game.moveField(index)
        //   address(game).call(abi.encodeWithSignature(...))
        //   raw calldata via address(game).call(hex"...")

        assertTrue(ISolvable(gameAddr).isSolved());
    }
}
```

Run:

```bash
make build  # ensure fresh Fe artifacts
forge test --match-test test_exploit -vvvv
```

## Attack vectors

### 1. Arithmetic / overflow
Fe uses `u256` for board values and indices. Check if the compiler correctly handles:
- Comparisons (`<`, `>`, `==`, `!=`)
- Arithmetic near boundaries (0, max values)
- Type casts between `u128` and `u256` (used in `Challenge.to_word()` / `from_word()`)

### 2. Storage layout
Each variant stores the board differently. Look for:
- **StorageMap** (Game): hash collisions, wrong slot computation
- **Nested arrays** (Game2D): incorrect row/col offset calculation
- **Fixed arrays** (GameEnum): off-by-one in indexing
- **Bitpacking** (GameBitboard): incorrect shift/mask, bits leaking across cells

### 3. Control flow
- `if`/`while`/`match` compiled to wrong branch targets
- Loop bounds miscalculated
- `match` on enum variants dispatching to wrong arm

### 4. ABI encoding/decoding
- Malformed calldata accepted as valid
- Wrong parameter decoding (shifted values, truncated args)
- Function selector collisions

### 5. Cross-contract calls
- `validateOwnsLock` callback: does the revert propagate correctly?
- `isSolved` callback: could the return value be misinterpreted?

### 6. WordRepr packing (Challenge struct)
The `Challenge` struct packs `is_open` (1 bit) and `prize_amount` (u128, upper 128 bits) into a single `u256`. Look for:
- Bit shift errors in `to_word()` / `from_word()`
- Truncation during `u128 as u256` cast
- State corruption when reading/writing packed values

## Key files to study

Read these Fe source files to understand the compiled logic:

```
contracts/ingots/games/src/game.fe           # StorageMap variant
contracts/ingots/games/src/game_2d.fe        # 2D array variant
contracts/ingots/games/src/game_enum.fe      # Enum/match variant
contracts/ingots/games/src/game_bitboard.fe  # Bitpacking variant
contracts/ingots/shared/src/lib.fe           # Shared types, Challenge struct, WordRepr
contracts/ingots/shared/src/game_util.fe     # Move encoding/adjacency helpers
contracts/ingots/registry/src/lib.fe         # Registry contract
```

Compare Fe source against compiled EVM bytecode in `contracts/out/*.bin` to spot miscompilations.

## Solidity infrastructure (not the attack target)

```
src/FeDeployer.sol                    # Deploys Fe binaries via Foundry
src/interfaces/ISolvable.sol          # isSolved() interface
src/interfaces/IBountyRegistry.sol    # Registry interface
test/Game.t.sol                       # Existing tests (good reference)
test/Game2D.t.sol
test/GameEnum.t.sol
test/GameBitboard.t.sol
test/BountyRegistry.t.sol
```

## Workflow summary

1. Read the Fe source for a game variant
2. Hypothesize a compiler bug (e.g., "what if array index 14 wraps to 0?")
3. Write a Foundry test that exploits it
4. Run `make build && forge test --match-test test_exploit -vvvv`
5. If `isSolved()` returns `true`, you found a bug
6. Repeat for other variants — the same compiler bug may affect multiple contracts
