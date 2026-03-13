// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {FeDeployer} from "../src/FeDeployer.sol";
import {IBountyRegistry} from "../src/interfaces/IBountyRegistry.sol";
import {SOLVED_BOARD, UNSOLVABLE_BOARD, ONE_MOVE_BOARD, TWO_MOVES_BOARD} from "../src/Constants.sol";

interface IGame2D {
    function getBoard(uint256 row, uint256 col) external view returns (uint256);
    function isSolved() external view returns (bool);
    function moveField(uint256 row, uint256 col) external;
}

contract Game2DTest is Test {
    string constant GAME_2D_BIN = "contracts/out/Game2D.bin";
    string constant DUMMY_LOCK_VALIDATOR_BIN = "contracts/out/DummyLockValidator.bin";
    string constant REGISTRY_BIN = "contracts/out/BountyRegistry.bin";


    function deployGame2D(address lockValidator, uint256 packedBoard) internal returns (IGame2D) {
        address addr = FeDeployer.deployFeWithArgs(
            vm, GAME_2D_BIN, abi.encode(lockValidator, packedBoard)
        );
        return IGame2D(addr);
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

    // =========================================================================
    // Board init and getBoard
    // =========================================================================

    function test_boardInitAndGetBoard() public {
        address validator = deployDummyLockValidator(false);
        IGame2D game = deployGame2D(validator, SOLVED_BOARD);

        assertEq(game.getBoard(0, 0), 1, "cell (0,0)");
        assertEq(game.getBoard(1, 2), 7, "cell (1,2)");
        assertEq(game.getBoard(3, 2), 15, "cell (3,2)");
        assertEq(game.getBoard(3, 3), 0, "cell (3,3) empty");
    }

    // =========================================================================
    // Solve check
    // =========================================================================

    function test_solvedBoard() public {
        address validator = deployDummyLockValidator(false);
        IGame2D game = deployGame2D(validator, SOLVED_BOARD);

        assertTrue(game.isSolved(), "winning board should be solved");
    }

    function test_unsolvedBoard() public {
        address validator = deployDummyLockValidator(false);
        IGame2D game = deployGame2D(validator, UNSOLVABLE_BOARD);

        assertFalse(game.isSolved(), "almost-solved board should not be solved");
    }

    // =========================================================================
    // Move and solve
    // =========================================================================

    function test_moveAndSolve() public {
        address validator = deployDummyLockValidator(false);
        IGame2D game = deployGame2D(validator, ONE_MOVE_BOARD);

        // Move (3,3) into empty at (3,2) — adjacent
        game.moveField(3, 3);

        assertTrue(game.isSolved(), "board should be solved after move");
    }

    function test_invalidMove() public {
        address validator = deployDummyLockValidator(false);
        IGame2D game = deployGame2D(validator, UNSOLVABLE_BOARD);

        // Move (0,0) — not adjacent to empty at (3,3)
        vm.expectRevert();
        game.moveField(0, 0);
    }

    // =========================================================================
    // MoveField requires lock
    // =========================================================================

    function test_moveFieldRequiresLock() public {
        address validator = deployDummyLockValidator(true);
        IGame2D game = deployGame2D(validator, UNSOLVABLE_BOARD);

        vm.expectRevert();
        game.moveField(3, 2);
    }

    // =========================================================================
    // MoveField invalid index
    // =========================================================================

    function test_moveFieldInvalidIndex() public {
        address validator = deployDummyLockValidator(false);
        IGame2D game = deployGame2D(validator, SOLVED_BOARD);

        vm.expectRevert();
        game.moveField(4, 0);
    }

    // =========================================================================
    // MoveField with real registry as lock validator
    // =========================================================================

    function test_moveFieldWithRealRegistry() public {
        IBountyRegistry registry = deployRegistry(address(this), 0);
        IGame2D game = deployGame2D(address(registry), ONE_MOVE_BOARD);

        // Register the game as a challenge (required for locking)
        registry.registerChallenge(address(game), 0);

        // Without locking, move should fail
        vm.expectRevert();
        game.moveField(3, 3);

        // Lock the challenge (per-challenge lock)
        registry.lock(address(game));

        // Now move should succeed
        game.moveField(3, 3);

        assertTrue(game.isSolved(), "board solved after move");
    }

    // =========================================================================
    // Multiple sequential moves
    // =========================================================================

    function test_multipleMovesToSolve() public {
        address validator = deployDummyLockValidator(false);
        IGame2D game = deployGame2D(validator, TWO_MOVES_BOARD);

        assertFalse(game.isSolved(), "should not be solved initially");

        // Move (3,2) value=14 into empty at (3,1)
        game.moveField(3, 2);

        // Move (3,3) value=15 into empty at (3,2)
        game.moveField(3, 3);

        assertTrue(game.isSolved(), "board should be solved after 2 moves");
    }

    receive() external payable {}
}
