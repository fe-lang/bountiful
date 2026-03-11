// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {FeDeployer} from "../src/FeDeployer.sol";
import {IBountyRegistry} from "../src/interfaces/IBountyRegistry.sol";

interface IGame2D {
    function getBoard(uint256 row, uint256 col) external view returns (uint256);
    function isSolved() external view returns (bool);
    function moveField(uint256 row, uint256 col) external;
    function setCell2D(uint256 row, uint256 col, uint256 value) external;
}

contract Game2DTest is Test {
    string constant GAME_2D_BIN = "contracts/out/Game2D.bin";
    string constant DUMMY_LOCK_VALIDATOR_BIN = "contracts/out/DummyLockValidator.bin";
    string constant REGISTRY_BIN = "contracts/out/BountyRegistry.bin";

    function deployGame2D(address lockValidator) internal returns (IGame2D) {
        address addr = FeDeployer.deployFeWithArgs(
            vm, GAME_2D_BIN, abi.encode(lockValidator)
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

    /// Set up a winning board row by row: [1,2,3,4], [5,6,7,8], [9,10,11,12], [13,14,15,0]
    function setupWinningBoard(IGame2D game) internal {
        for (uint256 row = 0; row < 4; row++) {
            for (uint256 col = 0; col < 4; col++) {
                uint256 index = row * 4 + col;
                uint256 value = index == 15 ? 0 : index + 1;
                game.setCell2D(row, col, value);
            }
        }
    }

    /// Set up an almost-solved board: (3,2)=0, (3,3)=15
    function setupAlmostSolvedBoard(IGame2D game) internal {
        for (uint256 row = 0; row < 4; row++) {
            for (uint256 col = 0; col < 4; col++) {
                uint256 index = row * 4 + col;
                uint256 value;
                if (index == 14) value = 0;
                else if (index == 15) value = 15;
                else value = index + 1;
                game.setCell2D(row, col, value);
            }
        }
    }

    // =========================================================================
    // Board init and getBoard
    // =========================================================================

    function test_boardInitAndGetBoard() public {
        address validator = deployDummyLockValidator(false);
        IGame2D game = deployGame2D(validator);

        setupWinningBoard(game);

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
        IGame2D game = deployGame2D(validator);

        setupWinningBoard(game);

        assertTrue(game.isSolved(), "winning board should be solved");
    }

    function test_unsolvedBoard() public {
        address validator = deployDummyLockValidator(false);
        IGame2D game = deployGame2D(validator);

        setupAlmostSolvedBoard(game);

        assertFalse(game.isSolved(), "almost-solved board should not be solved");
    }

    // =========================================================================
    // Move and solve
    // =========================================================================

    function test_moveAndSolve() public {
        address validator = deployDummyLockValidator(false);
        IGame2D game = deployGame2D(validator);

        setupAlmostSolvedBoard(game);

        // Move (3,3) into empty at (3,2) — adjacent
        game.moveField(3, 3);

        assertTrue(game.isSolved(), "board should be solved after move");
    }

    function test_invalidMove() public {
        address validator = deployDummyLockValidator(false);
        IGame2D game = deployGame2D(validator);

        setupAlmostSolvedBoard(game);

        // Move (0,0) — not adjacent to empty at (3,2)
        vm.expectRevert();
        game.moveField(0, 0);
    }

    // =========================================================================
    // MoveField requires lock
    // =========================================================================

    function test_moveFieldRequiresLock() public {
        address validator = deployDummyLockValidator(true);
        IGame2D game = deployGame2D(validator);

        setupAlmostSolvedBoard(game);

        vm.expectRevert();
        game.moveField(3, 3);
    }

    // =========================================================================
    // SetCell2D edge cases
    // =========================================================================

    function test_setCellAlreadyInitialized() public {
        address validator = deployDummyLockValidator(false);
        IGame2D game = deployGame2D(validator);

        setupWinningBoard(game);

        vm.expectRevert();
        game.setCell2D(0, 0, 99);
    }

    function test_setCellInvalidIndex() public {
        address validator = deployDummyLockValidator(false);
        IGame2D game = deployGame2D(validator);

        vm.expectRevert();
        game.setCell2D(4, 0, 1);
    }

    // =========================================================================
    // MoveField invalid index
    // =========================================================================

    function test_moveFieldInvalidIndex() public {
        address validator = deployDummyLockValidator(false);
        IGame2D game = deployGame2D(validator);

        setupWinningBoard(game);

        vm.expectRevert();
        game.moveField(4, 0);
    }

    // =========================================================================
    // MoveField with real registry as lock validator
    // =========================================================================

    function test_moveFieldWithRealRegistry() public {
        IBountyRegistry registry = deployRegistry(address(this), 0);
        IGame2D game = deployGame2D(address(registry));

        setupAlmostSolvedBoard(game);

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
        IGame2D game = deployGame2D(validator);

        // Board: [1..13, 0, 14, 15] — empty at (3,1)
        for (uint256 row = 0; row < 4; row++) {
            for (uint256 col = 0; col < 4; col++) {
                uint256 index = row * 4 + col;
                uint256 value;
                if (index == 13) value = 0;
                else if (index == 14) value = 14;
                else if (index == 15) value = 15;
                else value = index + 1;
                game.setCell2D(row, col, value);
            }
        }

        assertFalse(game.isSolved(), "should not be solved initially");

        // Move 1: move (3,2) value=14 into empty at (3,1)
        game.moveField(3, 2);

        // Move 2: move (3,3) value=15 into empty at (3,2)
        game.moveField(3, 3);

        assertTrue(game.isSolved(), "board should be solved after 2 moves");
    }

    receive() external payable {}
}
