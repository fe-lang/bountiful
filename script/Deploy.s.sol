// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {FeDeployer} from "../src/FeDeployer.sol";
import {IBountyRegistry} from "../src/interfaces/IBountyRegistry.sol";

contract Deploy is Script {
    string constant REGISTRY_BIN = "contracts/out/BountyRegistry.bin";
    string constant GAME_BIN = "contracts/out/Game.bin";
    string constant GAME_2D_BIN = "contracts/out/Game2D.bin";
    string constant GAME_ENUM_BIN = "contracts/out/GameEnum.bin";
    string constant GAME_BITBOARD_BIN = "contracts/out/GameBitboard.bin";
    string constant GAME_TRAIT_BIN = "contracts/out/GameTrait.bin";

    // Packed board: [1,2,...,14,0,15] — one move from solved
    uint256 constant UNSOLVABLE_BOARD = 0xF0EDCBA987654321;

    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address admin = vm.addr(deployerKey);
        uint256 lockDeposit = vm.envOr("LOCK_DEPOSIT", uint256(0.01 ether));
        uint128 prizeAmount = uint128(vm.envOr("PRIZE_AMOUNT", uint256(1 ether)));

        console.log("Deployer / Admin:", admin);
        console.log("Lock deposit:", lockDeposit);
        console.log("Prize per challenge:", prizeAmount);

        vm.startBroadcast(deployerKey);

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

        vm.stopBroadcast();

        // Write deployment manifest
        string memory json = "manifest";
        vm.serializeAddress(json, "BountyRegistry", registryAddr);
        vm.serializeAddress(json, "Game", gameAddr);
        vm.serializeAddress(json, "Game2D", game2dAddr);
        vm.serializeAddress(json, "GameEnum", gameEnumAddr);
        vm.serializeAddress(json, "GameBitboard", gameBitboardAddr);
        string memory output = vm.serializeAddress(json, "GameTrait", gameTraitAddr);

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
    }
}
