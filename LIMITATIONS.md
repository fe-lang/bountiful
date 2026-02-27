# Fe Compiler Limitations Encountered During Bountiful Migration

Discovered while migrating Bountiful from Fe 0.20.0-alpha to Fe 26.0.0-alpha.8.

## 1. `pub msg` works within an ingot but no fixtures demonstrate cross-ingot msg imports

**Problem:** While `pub msg` is accepted by the compiler (we use it successfully within the bountiful ingot), no fixture in the Fe compiler test suite demonstrates importing `msg` types across ingots. All cross-ingot imports only show `pub fn` items.

**Impact:** It's unclear whether `msg` types can be shared across ingots. Without documented cross-ingot `msg` import patterns, splitting contracts that share `msg` interfaces into separate ingots is risky.

**Evidence:** `pub msg GameMsg { ... }` compiles and can be imported within the same ingot via `use ingot::game::GameMsg`. However, no fixture shows `use other_ingot::SomeMsg` for cross-ingot msg sharing.

**Desired behavior:** Clear documentation/fixtures showing cross-ingot `msg` imports. This would enable clean separation of contracts into independent, composable ingots.

**Workaround:** Keep all contracts that share `msg` interfaces in the same ingot and use multi-file organization (`use ingot::module::MsgType`).

## 2. Structs containing `StorageMap` cannot be passed as function parameters

**Problem:** Any struct that contains a `StorageMap<K, V>` field produces a compiler error (`error[3-0032]: layout hole '_' is not allowed in value position`) when used as a function parameter or return value.

**Impact:** Storage-backed structs can only be used as contract fields and accessed via `uses(...)` effect clauses. Helper functions that operate on the entire store struct are impossible — logic must be inlined in the contract's `recv` handlers or operate on individual primitive fields.

**Evidence:** Attempting `fn helper(mut store: GameStore)` where `GameStore` contains `board: StorageMap<u256, u256>` triggers the error.

**Desired behavior:** Either allow StorageMap-containing structs in function signatures, or provide a borrowing/reference mechanism for storage structs.

**Workaround:** Keep all logic that accesses StorageMap fields inside the contract's `recv` blocks, using `uses (mut store)` effect clauses.

## 3. Constructor argument tuple ABI encoding has an arity limit

**Problem:** When deploying contracts via `evm.create2<Contract>(args: (...))`, the ABI encoding for the constructor arguments fails when the tuple contains more than approximately 12 elements, with error: `failed to resolve trait method 'encode' for (u256 x17): Encode<Sol>`.

**Impact:** Contracts with complex initialization data (e.g., a 4x4 game board = 16 cells) cannot receive all initial state through the constructor.

**Evidence:** Attempting to pass a 17-element tuple as constructor arguments triggered the encoding limit.

**Desired behavior:** Support for larger constructor argument tuples, or an alternative mechanism for bulk initialization (e.g., array parameters).

**Workaround:** Use a minimal constructor and perform initialization through post-deployment setup calls (e.g., a `SetCell` message called repeatedly).

## 4. No cross-file import examples in multi-file ingots

**Problem:** The Fe compiler test suite shows multi-file ingots (multiple `.fe` files in `src/`), but no fixture demonstrates one file importing items from another file within the same ingot. It's unclear how child modules reference items defined in the root module (`lib.fe`) or in sibling modules.

**Impact:** Uncertainty about how to properly organize a multi-file ingot where files depend on shared definitions. The exact `use` syntax for intra-ingot imports is undocumented in the fixture examples.

**Evidence:** The `build_ingots/multi_file` fixture has `src/lib.fe` and `src/bar.fe` that define independent contracts with no cross-file references.

**Desired behavior:** Clear documentation and/or test fixtures showing intra-ingot cross-file imports (e.g., `use crate::shared_fn` or root module items being automatically visible to child modules).

## 5. `fe test` only discovers `#[test]` functions in the root module (`lib.fe`)

**Problem:** When running `fe test` on an ingot (directory with `fe.toml`), the test runner only scans the root module (`src/lib.fe`) for `#[test]` functions. Tests in child modules (e.g., `src/tests.fe`) are silently ignored.

**Impact:** In a multi-file ingot, all test functions must be placed in `lib.fe`. You cannot have a separate `tests.fe` file for test organization.

**Evidence:** The test runner code (`crates/fe/src/test/mod.rs` line 1269) calls `has_test_functions(db, root_mod)` which only checks `root_mod` (i.e., `lib.fe`). `discover_and_run_tests` also only processes the root module.

**Desired behavior:** `fe test` should discover `#[test]` functions across all modules in the ingot, not just the root module.

**Workaround:** Place all `#[test]` functions in `lib.fe`, or use a standalone `.fe` file for tests (outside the ingot structure).

## 6. Compiler panic (ICE) when test in `lib.fe` references contracts from child modules

**Problem:** When `lib.fe` contains `#[test]` functions that use `evm.create2<game::Game>()` or `evm.call(message: game::GameMsg::Variant{})` to reference contracts/msgs defined in child modules, the compiler panics with: `failed to instantiate synthetic MIR for Synthetic(ContractInitCodeLen(...))`.

**Impact:** Even if tests could be discovered in `lib.fe`, they cannot reference contracts defined in child modules. This makes it impossible to write integration tests in a multi-file ingot that test contracts across modules.

**Evidence:** Adding tests to `lib.fe` that call `evm.create2<game::Game>()` and `evm.create2<registry::BountyRegistry>()` triggers the panic in `crates/mir/src/monomorphize.rs:519`.

**Desired behavior:** The MIR monomorphizer should handle cross-module contract references in test functions without panicking.

**Workaround:** Use a standalone `.fe` file (not part of the ingot) for integration tests. The standalone file must contain all contracts and code inline.

---

*Compiler version: Fe 26.0.0-alpha.8*
*Date: 2026-02-27*
