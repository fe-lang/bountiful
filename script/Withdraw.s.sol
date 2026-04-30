// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {IBountyRegistry} from "../src/interfaces/IBountyRegistry.sol";

/// Drains the full ETH balance of a deployed BountyRegistry to its admin.
///
/// Required env vars:
///   REGISTRY_ADDRESS         Address of the BountyRegistry to withdraw from.
///   ETH_RPC_URL              RPC endpoint (consumed by the `mainnet` alias in foundry.toml).
///
/// Signer selection (matches script/Deploy.s.sol):
///   Ledger mode:  set DEPLOYER_ADDRESS to the admin address, pass --ledger on the CLI.
///   Local mode:   set DEPLOYER_PRIVATE_KEY (used when DEPLOYER_ADDRESS is unset), no flag needed.
///
/// 1) Dry-run against a mainnet fork (no on-chain tx, no signature prompt):
///      ETH_RPC_URL=<url> \
///      DEPLOYER_ADDRESS=0x<admin> \
///      REGISTRY_ADDRESS=0x<registry> \
///        forge script script/Withdraw.s.sol --rpc-url mainnet
///
///    In dry-run mode --ledger is NOT required: forge only simulates the call,
///    it never asks the device to sign anything.
///
/// 2) Real broadcast via Ledger:
///      ETH_RPC_URL=<url> \
///      DEPLOYER_ADDRESS=0x<admin> \
///      REGISTRY_ADDRESS=0x<registry> \
///        forge script script/Withdraw.s.sol --rpc-url mainnet --broadcast --ledger
///
///    Add --hd-paths "m/44'/60'/0'/0/0" if the admin sits on a non-default derivation path.
///    Plug in the Ledger, unlock it, open the Ethereum app, and confirm the tx on-device.
///
/// 3) Real broadcast with a local key (e.g. against Anvil):
///      ETH_RPC_URL=http://localhost:8545 \
///      DEPLOYER_PRIVATE_KEY=0x<key> \
///      REGISTRY_ADDRESS=0x<registry> \
///        forge script script/Withdraw.s.sol --rpc-url $ETH_RPC_URL --broadcast
contract Withdraw is Script {
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

        address registryAddr = vm.envAddress("REGISTRY_ADDRESS");
        IBountyRegistry registry = IBountyRegistry(registryAddr);

        uint256 registryBalanceBefore = registryAddr.balance;
        uint256 adminBalanceBefore    = admin.balance;

        console.log("Admin:           ", admin);
        console.log("Registry:        ", registryAddr);
        console.log("Registry balance:", registryBalanceBefore);
        console.log("Admin balance:   ", adminBalanceBefore);

        require(registryBalanceBefore > 0, "registry has zero balance");

        registry.withdraw();

        vm.stopBroadcast();

        uint256 registryBalanceAfter = registryAddr.balance;
        uint256 adminBalanceAfter    = admin.balance;

        console.log("");
        console.log("=== Withdraw simulated/executed ===");
        console.log("Registry balance after:", registryBalanceAfter);
        console.log("Admin balance after:   ", adminBalanceAfter);
        console.log("Drained:               ", registryBalanceBefore - registryBalanceAfter);
    }
}
