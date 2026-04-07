// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {FeDeployer} from "../src/FeDeployer.sol";
import {IBountyRegistry} from "../src/interfaces/IBountyRegistry.sol";

contract BountyRegistryTest is Test {
    uint256 constant LOCK_PERIOD = 100;

    string constant REGISTRY_BIN = "contracts/out/BountyRegistry.bin";
    string constant DUMMY_GAME_BIN = "contracts/out/DummyGame.bin";

    address admin;
    address attacker;

    function setUp() public {
        admin = address(this);
        attacker = address(0xBEEF);
    }

    function deployRegistry(uint256 lockDeposit) internal returns (IBountyRegistry) {
        address addr = FeDeployer.deployFeWithArgs(
            vm, REGISTRY_BIN, abi.encode(admin, lockDeposit)
        );
        return IBountyRegistry(addr);
    }

    function deployDummyGame(bool isSolved) internal returns (address) {
        return FeDeployer.deployFeWithArgs(
            vm, DUMMY_GAME_BIN, abi.encode(isSolved)
        );
    }

    // =========================================================================
    // Lock timeout
    // =========================================================================

    function test_lockTimeoutExpires() public {
        IBountyRegistry registry = deployRegistry(0);
        address challenge = address(0x1234);

        registry.registerChallenge(challenge, 0);
        registry.lock(challenge);

        assertTrue(registry.isLocked(challenge), "should be locked");

        // Advance past LOCK_PERIOD
        vm.roll(block.number + LOCK_PERIOD + 1);

        assertFalse(registry.isLocked(challenge), "lock should have expired");
    }

    // =========================================================================
    // Lock with deposit
    // =========================================================================

    function test_lockWithDeposit() public {
        IBountyRegistry registry = deployRegistry(0.1 ether);
        vm.deal(admin, 1 ether);
        address challenge = address(0x1234);

        registry.registerChallenge(challenge, 0);
        registry.lock{value: 0.1 ether}(challenge);

        assertTrue(registry.isLocked(challenge), "should be locked");
    }

    function test_lockRejectedWithoutDeposit() public {
        IBountyRegistry registry = deployRegistry(0.1 ether);
        address challenge = address(0x1234);

        registry.registerChallenge(challenge, 0);

        vm.expectRevert();
        registry.lock{value: 0}(challenge);
    }

    // =========================================================================
    // Admin authorization (register/remove)
    // =========================================================================

    function test_nonAdminRegisterRejected() public {
        IBountyRegistry registry = deployRegistry(0);

        vm.prank(attacker);
        vm.expectRevert();
        registry.registerChallenge(address(0x1234), 0);
    }

    function test_nonAdminRemoveRejected() public {
        IBountyRegistry registry = deployRegistry(0);

        // Register first as admin
        registry.registerChallenge(address(0x1234), 0);

        vm.prank(attacker);
        vm.expectRevert();
        registry.removeChallenge(address(0x1234));
    }

    function test_adminRegistersAndRemovesChallenge() public {
        IBountyRegistry registry = deployRegistry(0);

        // Not open initially
        assertFalse(registry.isOpenChallenge(address(0x1234)), "not open initially");

        // Register
        registry.registerChallenge(address(0x1234), 0);

        assertTrue(registry.isOpenChallenge(address(0x1234)), "should be open after register");

        // Remove (unlocked)
        registry.removeChallenge(address(0x1234));

        assertFalse(registry.isOpenChallenge(address(0x1234)), "should be closed after remove");
    }

    // =========================================================================
    // Remove blocked while locked
    // =========================================================================

    function test_removeBlockedWhileLocked() public {
        IBountyRegistry registry = deployRegistry(0);

        registry.registerChallenge(address(0x1234), 0);
        registry.lock(address(0x1234));

        vm.expectRevert();
        registry.removeChallenge(address(0x1234));
    }

    // =========================================================================
    // Claim tests
    // =========================================================================

    function test_claimRequiresLock() public {
        IBountyRegistry registry = deployRegistry(0);
        address game = deployDummyGame(true); // solved

        registry.registerChallenge(game, 0);

        // Claim without locking
        vm.expectRevert();
        registry.claim(game);
    }

    function test_claimRequiresSolved() public {
        IBountyRegistry registry = deployRegistry(0);
        address game = deployDummyGame(false); // NOT solved

        registry.registerChallenge(game, 0);
        registry.lock(game);

        vm.expectRevert();
        registry.claim(game);
    }

    function test_fullBountyClaimWithETH() public {
        IBountyRegistry registry = deployRegistry(0);
        address game = deployDummyGame(true); // solved

        // Fund the registry with 10 ETH
        vm.deal(address(registry), 10 ether);

        // Register challenge with 3 ETH prize
        registry.registerChallenge(game, uint128(3 ether));

        // Lock
        registry.lock(game);

        uint256 balanceBefore = admin.balance;

        // Claim
        registry.claim(game);

        // Admin should have received only the prize amount (3 ETH), not the full balance
        uint256 balanceAfter = admin.balance;
        assertEq(balanceAfter - balanceBefore, 3 ether, "should receive 3 ETH prize");

        // Registry should still have the remaining 7 ETH
        assertEq(registry.getBalance(), 7 ether, "registry keeps remaining balance");

        // Challenge should be closed
        assertFalse(registry.isOpenChallenge(game), "challenge closed after claim");
    }

    // =========================================================================
    // Withdraw tests
    // =========================================================================

    function test_adminWithdrawWithETH() public {
        IBountyRegistry registry = deployRegistry(0);

        // Fund the registry
        vm.deal(address(registry), 5 ether);

        uint256 balanceBefore = admin.balance;

        registry.withdraw();

        uint256 balanceAfter = admin.balance;
        assertEq(balanceAfter - balanceBefore, 5 ether, "should receive 5 ETH");
    }

    function test_withdrawBlockedWhileLocked() public {
        IBountyRegistry registry = deployRegistry(0);
        address challenge = address(0x1234);

        registry.registerChallenge(challenge, 0);
        registry.lock(challenge);

        vm.expectRevert();
        registry.withdraw();
    }

    function test_nonAdminWithdrawRejected() public {
        IBountyRegistry registry = deployRegistry(0);

        vm.prank(attacker);
        vm.expectRevert();
        registry.withdraw();
    }

    // =========================================================================
    // GetBalance
    // =========================================================================

    function test_getBalance() public {
        IBountyRegistry registry = deployRegistry(0);

        uint256 bal = registry.getBalance();
        assertEq(bal, 0, "initial balance is 0");

        vm.deal(address(registry), 3 ether);
        bal = registry.getBalance();
        assertEq(bal, 3 ether, "balance after funding");
    }

    function test_fundOnDeploy() public {
        vm.deal(admin, 10 ether);
        address addr = FeDeployer.deployFeWithValue(
            vm, REGISTRY_BIN, abi.encode(admin, uint256(0)), 5 ether
        );
        IBountyRegistry registry = IBountyRegistry(addr);

        assertEq(registry.getBalance(), 5 ether, "registry funded on deploy");
    }

    // =========================================================================
    // Claim with expired lock
    // =========================================================================

    function test_claimWithExpiredLock() public {
        IBountyRegistry registry = deployRegistry(0);
        address game = deployDummyGame(true); // solved

        registry.registerChallenge(game, 0);
        registry.lock(game);

        // Advance past LOCK_PERIOD so lock expires
        vm.roll(block.number + LOCK_PERIOD + 1);

        vm.expectRevert();
        registry.claim(game);
    }

    // =========================================================================
    // Re-lock after expiry
    // =========================================================================

    function test_relockAfterExpiry() public {
        IBountyRegistry registry = deployRegistry(0);
        address challenge = address(0x1234);

        registry.registerChallenge(challenge, 0);

        // First lock
        registry.lock(challenge);
        assertTrue(registry.isLocked(challenge), "should be locked");

        // Advance past LOCK_PERIOD
        vm.roll(block.number + LOCK_PERIOD + 1);
        assertFalse(registry.isLocked(challenge), "lock should have expired");

        // Re-lock should succeed
        registry.lock(challenge);
        assertTrue(registry.isLocked(challenge), "should be locked again");
    }

    // =========================================================================
    // Claim by non-lock-holder
    // =========================================================================

    function test_claimByNonLockHolder() public {
        IBountyRegistry registry = deployRegistry(0);
        address game = deployDummyGame(true); // solved

        registry.registerChallenge(game, 0);

        // Admin (this contract) locks the challenge
        registry.lock(game);

        // Attacker tries to claim — not the lock holder
        vm.prank(attacker);
        vm.expectRevert();
        registry.claim(game);
    }

    // =========================================================================
    // ValidateOwnsLock
    // =========================================================================

    function test_validateOwnsLockCorrectOwner() public {
        IBountyRegistry registry = deployRegistry(0);
        address challenge = address(0x1234);

        registry.registerChallenge(challenge, 0);
        registry.lock(challenge);

        registry.validateOwnsLock(address(this), challenge);
    }

    function test_validateOwnsLockWrongOwner() public {
        IBountyRegistry registry = deployRegistry(0);
        address challenge = address(0x1234);

        registry.registerChallenge(challenge, 0);
        registry.lock(challenge);

        vm.expectRevert();
        registry.validateOwnsLock(attacker, challenge);
    }

    function test_validateOwnsLockExpired() public {
        IBountyRegistry registry = deployRegistry(0);
        address challenge = address(0x1234);

        registry.registerChallenge(challenge, 0);
        registry.lock(challenge);

        // Advance past LOCK_PERIOD
        vm.roll(block.number + LOCK_PERIOD + 1);

        vm.expectRevert();
        registry.validateOwnsLock(address(this), challenge);
    }

    function test_validateOwnsLockNoLock() public {
        IBountyRegistry registry = deployRegistry(0);
        address challenge = address(0x1234);

        // No lock acquired
        vm.expectRevert();
        registry.validateOwnsLock(address(this), challenge);
    }

    // =========================================================================
    // Lock with insufficient deposit
    // =========================================================================

    function test_lockWithInsufficientDeposit() public {
        IBountyRegistry registry = deployRegistry(0.1 ether);
        vm.deal(admin, 1 ether);
        address challenge = address(0x1234);

        registry.registerChallenge(challenge, 0);

        // Less than required
        vm.expectRevert();
        registry.lock{value: 0.05 ether}(challenge);
    }

    function test_lockWithExactDeposit() public {
        IBountyRegistry registry = deployRegistry(0.1 ether);
        vm.deal(admin, 1 ether);
        address challenge = address(0x1234);

        registry.registerChallenge(challenge, 0);

        registry.lock{value: 0.1 ether}(challenge);
        assertTrue(registry.isLocked(challenge), "should be locked");
    }

    function test_lockWithExcessDeposit() public {
        IBountyRegistry registry = deployRegistry(0.1 ether);
        vm.deal(admin, 1 ether);
        address challenge = address(0x1234);

        registry.registerChallenge(challenge, 0);

        registry.lock{value: 0.5 ether}(challenge);
        assertTrue(registry.isLocked(challenge), "should be locked");
    }

    // =========================================================================
    // Double register / double claim
    // =========================================================================

    function test_doubleRegisterSameChallenge() public {
        IBountyRegistry registry = deployRegistry(0);

        registry.registerChallenge(address(0x1234), 0);

        vm.expectRevert();
        registry.registerChallenge(address(0x1234), 0);
    }

    function test_claimAlreadyClaimed() public {
        IBountyRegistry registry = deployRegistry(0);
        address game = deployDummyGame(true); // solved

        registry.registerChallenge(game, 0);
        registry.lock(game);

        registry.claim(game);
        assertFalse(registry.isOpenChallenge(game), "challenge should be closed");

        // Try to claim again
        vm.expectRevert();
        registry.claim(game);
    }

    // =========================================================================
    // Remove never-registered challenge
    // =========================================================================

    function test_removeNeverRegistered() public {
        IBountyRegistry registry = deployRegistry(0);

        // Remove a challenge that was never registered
        registry.removeChallenge(address(0x9999));

        assertFalse(registry.isOpenChallenge(address(0x9999)), "should not be open");
    }

    // =========================================================================
    // Remove after lock expires
    // =========================================================================

    function test_removeAfterLockExpires() public {
        IBountyRegistry registry = deployRegistry(0);

        registry.registerChallenge(address(0x1234), 0);
        registry.lock(address(0x1234));

        // Can't remove while locked
        vm.expectRevert();
        registry.removeChallenge(address(0x1234));

        // Advance past LOCK_PERIOD
        vm.roll(block.number + LOCK_PERIOD + 1);

        // Now remove should succeed
        registry.removeChallenge(address(0x1234));

        assertFalse(registry.isOpenChallenge(address(0x1234)), "should be closed");
    }

    // =========================================================================
    // Withdraw after lock expires
    // =========================================================================

    function test_withdrawAfterLockExpires() public {
        IBountyRegistry registry = deployRegistry(0);
        address challenge = address(0x1234);

        vm.deal(address(registry), 5 ether);
        registry.registerChallenge(challenge, 0);
        registry.lock(challenge);

        // Can't withdraw while locked
        vm.expectRevert();
        registry.withdraw();

        // Advance past LOCK_PERIOD
        vm.roll(block.number + LOCK_PERIOD + 1);

        uint256 balanceBefore = admin.balance;
        registry.withdraw();
        assertEq(admin.balance - balanceBefore, 5 ether, "should receive 5 ETH");
    }

    // =========================================================================
    // Lock unregistered challenge
    // =========================================================================

    function test_lockUnregisteredChallenge() public {
        IBountyRegistry registry = deployRegistry(0);

        vm.expectRevert();
        registry.lock(address(0x9999));
    }

    // =========================================================================
    // Multiple simultaneous locks
    // =========================================================================

    function test_multipleSimultaneousLocks() public {
        IBountyRegistry registry = deployRegistry(0);
        address game1 = deployDummyGame(true);
        address game2 = deployDummyGame(true);

        registry.registerChallenge(game1, 0);
        registry.registerChallenge(game2, 0);

        // Lock both
        registry.lock(game1);
        registry.lock(game2);

        // Both locked
        assertTrue(registry.isLocked(game1), "game1 should be locked");
        assertTrue(registry.isLocked(game2), "game2 should be locked");

        // Claim both
        registry.claim(game1);
        registry.claim(game2);

        // Both closed
        assertFalse(registry.isOpenChallenge(game1), "game1 should be closed");
        assertFalse(registry.isOpenChallenge(game2), "game2 should be closed");
    }

    // =========================================================================
    // TransferFailed paths
    // =========================================================================

    function test_claimRevertsWhenReceiverRejects() public {
        // Use a RevertingReceiver as the claimer — it rejects incoming ETH
        RevertingReceiver receiver = new RevertingReceiver();
        IBountyRegistry registry = deployRegistry(0);
        address game = deployDummyGame(true); // solved

        // Fund registry and register with a prize
        vm.deal(address(registry), 10 ether);
        registry.registerChallenge(game, uint128(3 ether));

        // Lock as the reverting receiver
        vm.prank(address(receiver));
        registry.lock(game);

        // Claim as the reverting receiver — ETH transfer should fail
        vm.prank(address(receiver));
        vm.expectRevert();
        registry.claim(game);
    }

    function test_withdrawRevertsWhenAdminRejectsETH() public {
        // Deploy registry with a RevertingReceiver as admin
        RevertingReceiver revertingAdmin = new RevertingReceiver();
        address registryAddr = FeDeployer.deployFeWithArgs(
            vm, REGISTRY_BIN, abi.encode(address(revertingAdmin), uint256(0))
        );
        IBountyRegistry registry = IBountyRegistry(registryAddr);

        // Fund registry
        vm.deal(address(registry), 5 ether);

        // Withdraw as reverting admin — ETH transfer should fail
        vm.prank(address(revertingAdmin));
        vm.expectRevert();
        registry.withdraw();
    }

    function test_claimRevertsWhenRegistryUnderfunded() public {
        IBountyRegistry registry = deployRegistry(0);
        address game = deployDummyGame(true); // solved

        // Register with 5 ETH prize but don't fund the registry
        registry.registerChallenge(game, uint128(5 ether));

        // Lock and claim
        registry.lock(game);

        vm.expectRevert();
        registry.claim(game);
    }

    // Allow receiving ETH (for claim/withdraw transfers back to this contract)
    receive() external payable {}
}

/// Helper contract that rejects all incoming ETH transfers
contract RevertingReceiver {
    receive() external payable {
        revert("no ETH accepted");
    }
}
