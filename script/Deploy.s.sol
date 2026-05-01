// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {FeDeployer} from "../src/FeDeployer.sol";
import {IBountyRegistry} from "../src/interfaces/IBountyRegistry.sol";
import {UNSOLVABLE_BOARD} from "../src/Constants.sol";

/// Deploys the BountyRegistry plus all Game variants and registers each game
/// with a prize on the freshly deployed registry. Writes a manifest JSON to
/// deployments/<chainId>_<block>.json.
///
/// Required env vars:
///   ETH_RPC_URL              RPC endpoint (consumed by the `mainnet` alias in foundry.toml,
///                            or pass --rpc-url <url> directly).
///
/// Optional env vars:
///   LOCK_DEPOSIT             Wei required to lock a challenge (default: 0.01 ether).
///   PRIZE_AMOUNT             Wei prize per registered game (default: 0.25 ether).
///   INITIAL_FUND             Wei sent along with the BountyRegistry constructor
///                            so the registry is funded on deploy (default: 1 ether).
///                            Must be >= sum of prize payouts you expect to settle.
///
/// Signer selection:
///   Ledger mode:  set DEPLOYER_ADDRESS to the deployer address, pass --ledger on the CLI.
///                 The script auto-detects ledger mode when DEPLOYER_ADDRESS is set.
///   Local mode:   set DEPLOYER_PRIVATE_KEY (used when DEPLOYER_ADDRESS is unset), no flag needed.
///
/// 1) Dry-run against a mainnet fork (no on-chain tx, no signature prompt):
///      ETH_RPC_URL=<url> \
///      DEPLOYER_ADDRESS=0x<deployer> \
///        forge script script/Deploy.s.sol --rpc-url mainnet
///
///    In dry-run mode --ledger is NOT required: forge only simulates, it never
///    asks the device to sign anything. Use this to verify gas estimates and
///    that all eight contracts deploy + register cleanly.
///
/// 2) Real broadcast via Ledger (mainnet):
///      ETH_RPC_URL=<url> \
///      DEPLOYER_ADDRESS=0x<deployer> \
///        forge script script/Deploy.s.sol --rpc-url mainnet --broadcast --ledger
///
///    Add --hd-paths "m/44'/60'/0'/0/0" if the deployer sits on a non-default
///    derivation path. Plug in the Ledger, unlock it, open the Ethereum app,
///    and confirm each tx on-device (one per contract + one per registerChallenge).
///
/// 3) Real broadcast with a local key (e.g. against Anvil):
///      ETH_RPC_URL=http://localhost:8545 \
///      DEPLOYER_PRIVATE_KEY=0x<key> \
///        forge script script/Deploy.s.sol --rpc-url $ETH_RPC_URL --broadcast
///
/// The Makefile target `make deploy RPC_URL=... [LEDGER=1 DEPLOYER_ADDRESS=0x...]`
/// wraps the broadcast invocation; see Makefile:24.
contract Deploy is Script {
    string constant REGISTRY_BIN = "contracts/out/BountyRegistry.bin";
    string constant GAME_BIN = "contracts/out/Game.bin";
    string constant GAME_2D_BIN = "contracts/out/Game2D.bin";
    string constant GAME_ENUM_BIN = "contracts/out/GameEnum.bin";
    string constant GAME_BITBOARD_BIN = "contracts/out/GameBitboard.bin";
    string constant GAME_TRAIT_BIN = "contracts/out/GameTrait.bin";
    string constant GAME_NESTED_BIN = "contracts/out/GameNested.bin";
    string constant GAME_MONADIC_BIN = "contracts/out/GameMonadic.bin";

    function run() external {
        address admin;
        bool useLedger = vm.envOr("DEPLOYER_ADDRESS", address(0)) != address(0);
        if (useLedger) {
            admin = vm.envAddress("DEPLOYER_ADDRESS");
            vm.startBroadcast(admin);
        } else {
            uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
            admin = vm.addr(deployerKey);
            vm.startBroadcast(deployerKey);
        }

        uint256 lockDeposit = vm.envOr("LOCK_DEPOSIT", uint256(0.01 ether));
        uint128 prizeAmount = uint128(vm.envOr("PRIZE_AMOUNT", uint256(0.25 ether)));
        uint256 initialFund = vm.envOr("INITIAL_FUND", uint256(1 ether));

        console.log("Deployer / Admin:", admin);
        console.log("Lock deposit:", lockDeposit);
        console.log("Prize per challenge:", prizeAmount);
        console.log("Initial fund:", initialFund);

        // 1. Deploy BountyRegistry (funded on deploy via constructor msg.value)
        address registryAddr = FeDeployer.deployFeWithValue(
            vm, REGISTRY_BIN, abi.encode(admin, lockDeposit), initialFund
        );
        IBountyRegistry registry = IBountyRegistry(registryAddr);
        console.log("BountyRegistry:", registryAddr);

        // 2. Deploy Game (StorageMap variant)
        address gameAddr = FeDeployer.deployFeWithArgs(
            vm, GAME_BIN, abi.encode(registryAddr, UNSOLVABLE_BOARD)
        );
        registry.registerChallenge(gameAddr, prizeAmount);
        console.log("Game:", gameAddr);

        // 3. Deploy Game2D (2D array variant)
        address game2dAddr = FeDeployer.deployFeWithArgs(
            vm, GAME_2D_BIN, abi.encode(registryAddr, UNSOLVABLE_BOARD)
        );
        registry.registerChallenge(game2dAddr, prizeAmount);
        console.log("Game2D:", game2dAddr);

        // 4. Deploy GameEnum (enum variant)
        address gameEnumAddr = FeDeployer.deployFeWithArgs(
            vm, GAME_ENUM_BIN, abi.encode(registryAddr, UNSOLVABLE_BOARD)
        );
        registry.registerChallenge(gameEnumAddr, prizeAmount);
        console.log("GameEnum:", gameEnumAddr);

        // 5. Deploy GameBitboard (bitpacking variant)
        address gameBitboardAddr = FeDeployer.deployFeWithArgs(
            vm, GAME_BITBOARD_BIN, abi.encode(registryAddr, UNSOLVABLE_BOARD)
        );
        registry.registerChallenge(gameBitboardAddr, prizeAmount);
        console.log("GameBitboard:", gameBitboardAddr);

        // 6. Deploy GameTrait (trait variant)
        address gameTraitAddr = FeDeployer.deployFeWithArgs(
            vm, GAME_TRAIT_BIN, abi.encode(registryAddr, UNSOLVABLE_BOARD)
        );
        registry.registerChallenge(gameTraitAddr, prizeAmount);
        console.log("GameTrait:", gameTraitAddr);

        // 7. Deploy GameNested (nested struct variant)
        address gameNestedAddr = FeDeployer.deployFeWithArgs(
            vm, GAME_NESTED_BIN, abi.encode(registryAddr, UNSOLVABLE_BOARD)
        );
        registry.registerChallenge(gameNestedAddr, prizeAmount);
        console.log("GameNested:", gameNestedAddr);

        // 8. Deploy GameMonadic (functional combinator variant)
        address gameMonadicAddr = FeDeployer.deployFeWithArgs(
            vm, GAME_MONADIC_BIN, abi.encode(registryAddr, UNSOLVABLE_BOARD)
        );
        registry.registerChallenge(gameMonadicAddr, prizeAmount);
        console.log("GameMonadic:", gameMonadicAddr);

        vm.stopBroadcast();

        // Write deployment manifest
        string memory json = "manifest";
        vm.serializeAddress(json, "BountyRegistry", registryAddr);
        vm.serializeAddress(json, "Game", gameAddr);
        vm.serializeAddress(json, "Game2D", game2dAddr);
        vm.serializeAddress(json, "GameEnum", gameEnumAddr);
        vm.serializeAddress(json, "GameBitboard", gameBitboardAddr);
        vm.serializeAddress(json, "GameTrait", gameTraitAddr);
        vm.serializeAddress(json, "GameNested", gameNestedAddr);
        string memory output = vm.serializeAddress(json, "GameMonadic", gameMonadicAddr);

        string memory path = string.concat(
            "deployments/",
            vm.toString(block.chainid),
            "_",
            vm.toString(block.number),
            ".json"
        );
        vm.writeJson(output, path);
        console.log("Manifest written to:", path);

        console.log("");
        console.log("=== Deployment complete ===");
        console.log("Registry:     ", registryAddr);
        console.log("Game:         ", gameAddr);
        console.log("Game2D:       ", game2dAddr);
        console.log("GameEnum:     ", gameEnumAddr);
        console.log("GameBitboard: ", gameBitboardAddr);
        console.log("GameTrait:    ", gameTraitAddr);
        console.log("GameNested:   ", gameNestedAddr);
        console.log("GameMonadic:   ", gameMonadicAddr);
    }
}
