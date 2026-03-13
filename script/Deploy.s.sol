// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {FeDeployer} from "../src/FeDeployer.sol";
import {IBountyRegistry} from "../src/interfaces/IBountyRegistry.sol";
import {UNSOLVABLE_BOARD} from "../src/Constants.sol";

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
        // Ledger mode: set DEPLOYER_ADDRESS (used with --ledger flag)
        // Local mode:  set DEPLOYER_PRIVATE_KEY (used for Anvil / testing)
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
        uint128 prizeAmount = uint128(vm.envOr("PRIZE_AMOUNT", uint256(0.1 ether)));

        console.log("Deployer / Admin:", admin);
        console.log("Lock deposit:", lockDeposit);
        console.log("Prize per challenge:", prizeAmount);

        // 1. Deploy BountyRegistry
        address registryAddr = FeDeployer.deployFeWithArgs(
            vm, REGISTRY_BIN, abi.encode(admin, lockDeposit)
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
