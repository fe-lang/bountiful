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

    // Allow receiving ETH (for claim/withdraw transfers back to this contract)
    receive() external payable {}
}
