// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {FeDeployer} from "../src/FeDeployer.sol";
import {IBountyRegistry} from "../src/interfaces/IBountyRegistry.sol";

interface IGame {
    function getBoard(uint256 index) external view returns (uint256);
    function isSolved() external view returns (bool);
    function moveField(uint256 index) external;
    function setCell(uint256 index, uint256 value) external;
}

contract GameTest is Test {
    string constant GAME_BIN = "contracts/out/Game.bin";
    string constant DUMMY_LOCK_VALIDATOR_BIN = "contracts/out/DummyLockValidator.bin";
    string constant REGISTRY_BIN = "contracts/out/BountyRegistry.bin";

    function deployGame(address lockValidator) internal returns (IGame) {
        address addr = FeDeployer.deployFeWithArgs(
            vm, GAME_BIN, abi.encode(lockValidator)
        );
        return IGame(addr);
    }

    function deployDummyLockValidator(bool shouldRevert) internal returns (address) {
        return FeDeployer.deployFeWithArgs(
            vm, DUMMY_LOCK_VALIDATOR_BIN, abi.encode(shouldRevert)
        );
    }

    function deployRegistry(address admin, uint256 lockDeposit) internal returns (IBountyRegistry) {
        address addr = FeDeployer.deployFeWithArgs(
            vm, REGISTRY_BIN, abi.encode(admin, lockDeposit)
        );
        return IBountyRegistry(addr);
    }

    /// Set up a winning board: [1,2,3,...,15,0]
    function setupWinningBoard(IGame game) internal {
        for (uint256 i = 0; i < 15; i++) {
            game.setCell(i, i + 1);
        }
        game.setCell(15, 0);
    }

    /// Set up an almost-solved board: [1,2,...,14,0,15] — empty at 14
    function setupAlmostSolvedBoard(IGame game) internal {
        for (uint256 i = 0; i < 14; i++) {
            game.setCell(i, i + 1);
        }
        game.setCell(14, 0);
        game.setCell(15, 15);
    }

    // =========================================================================
    // Board init and getBoard
    // =========================================================================

    function test_boardInitAndGetBoard() public {
        address validator = deployDummyLockValidator(false);
        IGame game = deployGame(validator);

        setupWinningBoard(game);

        assertEq(game.getBoard(0), 1, "cell 0");
        assertEq(game.getBoard(7), 8, "cell 7");
        assertEq(game.getBoard(14), 15, "cell 14");
        assertEq(game.getBoard(15), 0, "cell 15 (empty)");
    }

    // =========================================================================
    // Solve check
    // =========================================================================

    function test_solvedBoard() public {
        address validator = deployDummyLockValidator(false);
        IGame game = deployGame(validator);

        setupWinningBoard(game);

        assertTrue(game.isSolved(), "winning board should be solved");
    }

    function test_unsolvedBoard() public {
        address validator = deployDummyLockValidator(false);
        IGame game = deployGame(validator);

        setupAlmostSolvedBoard(game);

        assertFalse(game.isSolved(), "almost-solved board should not be solved");
    }

    // =========================================================================
    // Move and solve
    // =========================================================================

    function test_moveAndSolve() public {
        address validator = deployDummyLockValidator(false);
        IGame game = deployGame(validator);

        setupAlmostSolvedBoard(game);

        // Move 15 into the empty slot at 14 (they are adjacent)
        game.moveField(15);

        assertTrue(game.isSolved(), "board should be solved after move");
    }

    function test_invalidMove() public {
        address validator = deployDummyLockValidator(false);
        IGame game = deployGame(validator);

        setupAlmostSolvedBoard(game);

        // Move index 0 — not adjacent to empty at 14
        vm.expectRevert();
        game.moveField(0);
    }

    // =========================================================================
    // MoveField requires lock
    // =========================================================================

    function test_moveFieldRequiresLock() public {
        address validator = deployDummyLockValidator(true);
        IGame game = deployGame(validator);

        setupAlmostSolvedBoard(game);

        vm.expectRevert();
        game.moveField(15);
    }

    // =========================================================================
    // MoveField with real registry as lock validator
    // =========================================================================

    function test_moveFieldWithRealRegistry() public {
        IBountyRegistry registry = deployRegistry(address(this), 0);
        IGame game = deployGame(address(registry));

        setupAlmostSolvedBoard(game);

        // Register the game as a challenge (required for locking)
        registry.registerChallenge(address(game), 0);

        // Without locking, move should fail
        vm.expectRevert();
        game.moveField(15);

        // Lock the challenge (per-challenge lock)
        registry.lock(address(game));

        // Now move should succeed
        game.moveField(15);

        assertTrue(game.isSolved(), "board solved after move");
    }

    // Allow receiving ETH
    receive() external payable {}
}
