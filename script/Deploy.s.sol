// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {FeDeployer} from "../src/FeDeployer.sol";
import {IBountyRegistry} from "../src/interfaces/IBountyRegistry.sol";

interface IGame {
    function setCell(uint256 index, uint256 value) external returns (uint256);
}

contract Deploy is Script {
    string constant REGISTRY_BIN = "contracts/out/BountyRegistry.bin";
    string constant GAME_BIN = "contracts/out/Game.bin";

    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address admin = vm.addr(deployerKey);
        uint256 lockDeposit = vm.envOr("LOCK_DEPOSIT", uint256(0.01 ether));

        console.log("Deployer / Admin:", admin);
        console.log("Lock deposit:", lockDeposit);

        vm.startBroadcast(deployerKey);

        // 1. Deploy BountyRegistry
        address registryAddr = FeDeployer.deployFeWithArgs(
            vm, REGISTRY_BIN, abi.encode(admin, lockDeposit)
        );
        IBountyRegistry registry = IBountyRegistry(registryAddr);
        console.log("BountyRegistry:", registryAddr);

        // 2. Deploy Game with registry as lock validator
        address gameAddr = FeDeployer.deployFeWithArgs(
            vm, GAME_BIN, abi.encode(registryAddr)
        );
        IGame game = IGame(gameAddr);
        console.log("Game:", gameAddr);

        // 3. Register the game as a challenge with prize amount
        uint128 prizeAmount = uint128(vm.envOr("PRIZE_AMOUNT", uint256(1 ether)));
        uint256 res = registry.registerChallenge(gameAddr, prizeAmount);
        require(res == 0, "registerChallenge failed");
        console.log("Game registered with prize:", prizeAmount);

        // 4. Initialize the board: [1,2,...,14,0,15] — almost solved, one move away
        for (uint256 i = 0; i < 14; i++) {
            game.setCell(i, i + 1);
        }
        game.setCell(14, 0);
        game.setCell(15, 15);
        console.log("Board initialized (one move from solved)");

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployment complete ===");
        console.log("Registry:", registryAddr);
        console.log("Game:    ", gameAddr);
    }
}
