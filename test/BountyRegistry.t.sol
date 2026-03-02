// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {FeDeployer} from "../src/FeDeployer.sol";
import {IBountyRegistry} from "../src/interfaces/IBountyRegistry.sol";

contract BountyRegistryTest is Test {
    // Error codes from shared/src/lib.fe (Error enum, sequential)
    uint256 constant ERR_MISSING_LOCK = 3;
    uint256 constant ERR_ALREADY_LOCKED = 4;
    uint256 constant ERR_INVALID_CLAIM = 5;
    uint256 constant ERR_ONLY_ADMIN = 6;
    uint256 constant ERR_INVALID_DEPOSIT = 8;
    uint256 constant LOCK_PERIOD = 1000;

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

        uint256 res = registry.lock();
        assertEq(res, 0, "lock should succeed");

        assertTrue(registry.isLocked(), "should be locked");

        // Advance past LOCK_PERIOD
        vm.roll(block.number + LOCK_PERIOD + 1);

        assertFalse(registry.isLocked(), "lock should have expired");
    }

    // =========================================================================
    // Lock with deposit
    // =========================================================================

    function test_lockWithDeposit() public {
        IBountyRegistry registry = deployRegistry(0.1 ether);
        vm.deal(admin, 1 ether);

        uint256 res = registry.lock{value: 0.1 ether}();
        assertEq(res, 0, "lock with sufficient deposit should succeed");

        assertTrue(registry.isLocked(), "should be locked");
    }

    function test_lockRejectedWithoutDeposit() public {
        IBountyRegistry registry = deployRegistry(0.1 ether);

        uint256 res = registry.lock{value: 0}();
        assertEq(res, ERR_INVALID_DEPOSIT, "lock without deposit should fail");
    }

    // =========================================================================
    // Admin authorization (register/remove)
    // =========================================================================

    function test_nonAdminRegisterRejected() public {
        IBountyRegistry registry = deployRegistry(0);

        vm.prank(attacker);
        uint256 res = registry.registerChallenge(address(0x1234));
        assertEq(res, ERR_ONLY_ADMIN, "non-admin register should fail");
    }

    function test_nonAdminRemoveRejected() public {
        IBountyRegistry registry = deployRegistry(0);

        // Register first as admin
        registry.registerChallenge(address(0x1234));

        vm.prank(attacker);
        uint256 res = registry.removeChallenge(address(0x1234));
        assertEq(res, ERR_ONLY_ADMIN, "non-admin remove should fail");
    }

    function test_adminRegistersAndRemovesChallenge() public {
        IBountyRegistry registry = deployRegistry(0);

        // Not open initially
        assertFalse(registry.isOpenChallenge(address(0x1234)), "not open initially");

        // Register
        uint256 res = registry.registerChallenge(address(0x1234));
        assertEq(res, 0, "register should succeed");

        assertTrue(registry.isOpenChallenge(address(0x1234)), "should be open after register");

        // Remove (unlocked)
        res = registry.removeChallenge(address(0x1234));
        assertEq(res, 0, "remove should succeed");

        assertFalse(registry.isOpenChallenge(address(0x1234)), "should be closed after remove");
    }

    // =========================================================================
    // Remove blocked while locked
    // =========================================================================

    function test_removeBlockedWhileLocked() public {
        IBountyRegistry registry = deployRegistry(0);

        registry.registerChallenge(address(0x1234));
        registry.lock();

        uint256 res = registry.removeChallenge(address(0x1234));
        assertEq(res, ERR_ALREADY_LOCKED, "remove while locked should fail");
    }

    // =========================================================================
    // Claim tests
    // =========================================================================

    function test_claimRequiresLock() public {
        IBountyRegistry registry = deployRegistry(0);
        address game = deployDummyGame(true); // solved

        registry.registerChallenge(game);

        // Claim without locking
        uint256 res = registry.claim(game);
        assertEq(res, ERR_MISSING_LOCK, "claim without lock should fail");
    }

    function test_claimRequiresSolved() public {
        IBountyRegistry registry = deployRegistry(0);
        address game = deployDummyGame(false); // NOT solved

        registry.registerChallenge(game);
        registry.lock();

        uint256 res = registry.claim(game);
        assertEq(res, ERR_INVALID_CLAIM, "claim unsolved should fail");
    }

    function test_fullBountyClaimWithETH() public {
        IBountyRegistry registry = deployRegistry(0);
        address game = deployDummyGame(true); // solved

        // Fund the registry with 10 ETH
        vm.deal(address(registry), 10 ether);

        // Register challenge
        registry.registerChallenge(game);

        // Lock
        uint256 lockRes = registry.lock();
        assertEq(lockRes, 0, "lock should succeed");

        uint256 balanceBefore = admin.balance;

        // Claim
        uint256 claimRes = registry.claim(game);
        assertEq(claimRes, 0, "claim should succeed");

        // Admin should have received the ETH
        uint256 balanceAfter = admin.balance;
        assertEq(balanceAfter - balanceBefore, 10 ether, "should receive 10 ETH");

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

        uint256 res = registry.withdraw();
        assertEq(res, 0, "admin withdraw should succeed");

        uint256 balanceAfter = admin.balance;
        assertEq(balanceAfter - balanceBefore, 5 ether, "should receive 5 ETH");
    }

    function test_withdrawBlockedWhileLocked() public {
        IBountyRegistry registry = deployRegistry(0);

        registry.lock();

        uint256 res = registry.withdraw();
        assertEq(res, ERR_ALREADY_LOCKED, "withdraw while locked should fail");
    }

    function test_nonAdminWithdrawRejected() public {
        IBountyRegistry registry = deployRegistry(0);

        vm.prank(attacker);
        uint256 res = registry.withdraw();
        assertEq(res, ERR_ONLY_ADMIN, "non-admin withdraw should fail");
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

    // =========================================================================
    // Claim with expired lock
    // =========================================================================

    function test_claimWithExpiredLock() public {
        IBountyRegistry registry = deployRegistry(0);
        address game = deployDummyGame(true); // solved

        registry.registerChallenge(game);
        registry.lock();

        // Advance past LOCK_PERIOD so lock expires
        vm.roll(block.number + LOCK_PERIOD + 1);

        uint256 res = registry.claim(game);
        assertEq(res, ERR_MISSING_LOCK, "claim with expired lock should fail");
    }

    // =========================================================================
    // Re-lock after expiry
    // =========================================================================

    function test_relockAfterExpiry() public {
        IBountyRegistry registry = deployRegistry(0);

        // First lock
        uint256 res1 = registry.lock();
        assertEq(res1, 0, "first lock should succeed");
        assertTrue(registry.isLocked(), "should be locked");

        // Advance past LOCK_PERIOD
        vm.roll(block.number + LOCK_PERIOD + 1);
        assertFalse(registry.isLocked(), "lock should have expired");

        // Re-lock should succeed
        uint256 res2 = registry.lock();
        assertEq(res2, 0, "re-lock should succeed after expiry");
        assertTrue(registry.isLocked(), "should be locked again");
    }

    // =========================================================================
    // Claim by non-lock-holder
    // =========================================================================

    function test_claimByNonLockHolder() public {
        IBountyRegistry registry = deployRegistry(0);
        address game = deployDummyGame(true); // solved

        registry.registerChallenge(game);

        // Admin (this contract) locks
        registry.lock();

        // Attacker tries to claim — not the lock holder
        vm.prank(attacker);
        uint256 res = registry.claim(game);
        assertEq(res, ERR_MISSING_LOCK, "non-lock-holder claim should fail");
    }

    // =========================================================================
    // ValidateOwnsLock
    // =========================================================================

    function test_validateOwnsLockCorrectOwner() public {
        IBountyRegistry registry = deployRegistry(0);

        registry.lock();

        uint256 res = registry.validateOwnsLock(address(this));
        assertEq(res, 0, "correct owner should validate");
    }

    function test_validateOwnsLockWrongOwner() public {
        IBountyRegistry registry = deployRegistry(0);

        registry.lock();

        uint256 res = registry.validateOwnsLock(attacker);
        assertEq(res, ERR_MISSING_LOCK, "wrong owner should fail");
    }

    function test_validateOwnsLockExpired() public {
        IBountyRegistry registry = deployRegistry(0);

        registry.lock();

        // Advance past LOCK_PERIOD
        vm.roll(block.number + LOCK_PERIOD + 1);

        uint256 res = registry.validateOwnsLock(address(this));
        assertEq(res, ERR_MISSING_LOCK, "expired lock should fail validation");
    }

    function test_validateOwnsLockNoLock() public {
        IBountyRegistry registry = deployRegistry(0);

        // No lock acquired
        uint256 res = registry.validateOwnsLock(address(this));
        assertEq(res, ERR_MISSING_LOCK, "no lock should fail validation");
    }

    // =========================================================================
    // Lock with insufficient deposit
    // =========================================================================

    function test_lockWithInsufficientDeposit() public {
        IBountyRegistry registry = deployRegistry(0.1 ether);
        vm.deal(admin, 1 ether);

        // Less than required
        uint256 res = registry.lock{value: 0.05 ether}();
        assertEq(res, ERR_INVALID_DEPOSIT, "insufficient deposit should fail");
    }

    function test_lockWithExactDeposit() public {
        IBountyRegistry registry = deployRegistry(0.1 ether);
        vm.deal(admin, 1 ether);

        uint256 res = registry.lock{value: 0.1 ether}();
        assertEq(res, 0, "exact deposit should succeed");
        assertTrue(registry.isLocked(), "should be locked");
    }

    function test_lockWithExcessDeposit() public {
        IBountyRegistry registry = deployRegistry(0.1 ether);
        vm.deal(admin, 1 ether);

        uint256 res = registry.lock{value: 0.5 ether}();
        assertEq(res, 0, "excess deposit should succeed");
        assertTrue(registry.isLocked(), "should be locked");
    }

    // =========================================================================
    // Double register / double claim
    // =========================================================================

    function test_doubleRegisterSameChallenge() public {
        IBountyRegistry registry = deployRegistry(0);

        uint256 res1 = registry.registerChallenge(address(0x1234));
        assertEq(res1, 0, "first register should succeed");

        uint256 res2 = registry.registerChallenge(address(0x1234));
        assertEq(res2, 0, "second register should succeed (idempotent)");

        assertTrue(registry.isOpenChallenge(address(0x1234)), "should still be open");
    }

    function test_claimAlreadyClaimed() public {
        IBountyRegistry registry = deployRegistry(0);
        address game = deployDummyGame(true); // solved

        registry.registerChallenge(game);
        registry.lock();

        uint256 res1 = registry.claim(game);
        assertEq(res1, 0, "first claim should succeed");
        assertFalse(registry.isOpenChallenge(game), "challenge should be closed");

        // Try to claim again
        uint256 res2 = registry.claim(game);
        assertEq(res2, ERR_INVALID_CLAIM, "second claim should fail");
    }

    // =========================================================================
    // Remove never-registered challenge
    // =========================================================================

    function test_removeNeverRegistered() public {
        IBountyRegistry registry = deployRegistry(0);

        // Remove a challenge that was never registered
        uint256 res = registry.removeChallenge(address(0x9999));
        assertEq(res, 0, "remove non-existent should succeed");

        assertFalse(registry.isOpenChallenge(address(0x9999)), "should not be open");
    }

    // =========================================================================
    // Remove after lock expires
    // =========================================================================

    function test_removeAfterLockExpires() public {
        IBountyRegistry registry = deployRegistry(0);

        registry.registerChallenge(address(0x1234));
        registry.lock();

        // Can't remove while locked
        uint256 res1 = registry.removeChallenge(address(0x1234));
        assertEq(res1, ERR_ALREADY_LOCKED, "remove while locked should fail");

        // Advance past LOCK_PERIOD
        vm.roll(block.number + LOCK_PERIOD + 1);

        // Now remove should succeed
        uint256 res2 = registry.removeChallenge(address(0x1234));
        assertEq(res2, 0, "remove after lock expired should succeed");

        assertFalse(registry.isOpenChallenge(address(0x1234)), "should be closed");
    }

    // =========================================================================
    // Withdraw after lock expires
    // =========================================================================

    function test_withdrawAfterLockExpires() public {
        IBountyRegistry registry = deployRegistry(0);

        vm.deal(address(registry), 5 ether);
        registry.lock();

        // Can't withdraw while locked
        uint256 res1 = registry.withdraw();
        assertEq(res1, ERR_ALREADY_LOCKED, "withdraw while locked should fail");

        // Advance past LOCK_PERIOD
        vm.roll(block.number + LOCK_PERIOD + 1);

        uint256 balanceBefore = admin.balance;
        uint256 res2 = registry.withdraw();
        assertEq(res2, 0, "withdraw after lock expired should succeed");
        assertEq(admin.balance - balanceBefore, 5 ether, "should receive 5 ETH");
    }

    // Allow receiving ETH (for claim/withdraw transfers back to this contract)
    receive() external payable {}
}
