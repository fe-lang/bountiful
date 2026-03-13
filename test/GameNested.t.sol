// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {FeDeployer} from "../src/FeDeployer.sol";
import {IBountyRegistry} from "../src/interfaces/IBountyRegistry.sol";
import {SOLVED_BOARD, UNSOLVABLE_BOARD, ONE_MOVE_BOARD, TWO_MOVES_BOARD} from "../src/Constants.sol";

interface IGameNested {
    function getBoard(uint256 index) external view returns (uint256);
    function isSolved() external view returns (bool);
    function moveField(uint256 index) external;
}

contract GameNestedTest is Test {
    string constant GAME_NESTED_BIN = "contracts/out/GameNested.bin";
    string constant DUMMY_LOCK_VALIDATOR_BIN = "contracts/out/DummyLockValidator.bin";
    string constant REGISTRY_BIN = "contracts/out/BountyRegistry.bin";


    function deployGameNested(address lockValidator, uint256 packedBoard) internal returns (IGameNested) {
        address addr = FeDeployer.deployFeWithArgs(
            vm, GAME_NESTED_BIN, abi.encode(lockValidator, packedBoard)
        );
        return IGameNested(addr);
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
        IGameNested game = deployGameNested(validator, SOLVED_BOARD);

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
        IGameNested game = deployGameNested(validator, SOLVED_BOARD);

        assertTrue(game.isSolved(), "winning board should be solved");
    }

    function test_unsolvedBoard() public {
        address validator = deployDummyLockValidator(false);
        IGameNested game = deployGameNested(validator, UNSOLVABLE_BOARD);

        assertFalse(game.isSolved(), "almost-solved board should not be solved");
    }

    // =========================================================================
    // Move and solve
    // =========================================================================

    function test_moveAndSolve() public {
        address validator = deployDummyLockValidator(false);
        IGameNested game = deployGameNested(validator, ONE_MOVE_BOARD);

        game.moveField(15);

        assertTrue(game.isSolved(), "board should be solved after move");
    }

    function test_invalidMove() public {
        address validator = deployDummyLockValidator(false);
        IGameNested game = deployGameNested(validator, UNSOLVABLE_BOARD);

        // Move index 0 — not adjacent to empty at 15
        vm.expectRevert();
        game.moveField(0);
    }

    // =========================================================================
    // MoveField requires lock
    // =========================================================================

    function test_moveFieldRequiresLock() public {
        address validator = deployDummyLockValidator(true);
        IGameNested game = deployGameNested(validator, UNSOLVABLE_BOARD);

        vm.expectRevert();
        game.moveField(14);
    }

    // =========================================================================
    // MoveField invalid index
    // =========================================================================

    function test_moveFieldInvalidIndex() public {
        address validator = deployDummyLockValidator(false);
        IGameNested game = deployGameNested(validator, SOLVED_BOARD);

        vm.expectRevert();
        game.moveField(16);
    }

    // =========================================================================
    // MoveField with real registry as lock validator
    // =========================================================================

    function test_moveFieldWithRealRegistry() public {
        IBountyRegistry registry = deployRegistry(address(this), 0);
        IGameNested game = deployGameNested(address(registry), ONE_MOVE_BOARD);

        // Register the game as a challenge (required for locking)
        registry.registerChallenge(address(game), 0);

        vm.expectRevert();
        game.moveField(15);

        // Lock the challenge (per-challenge lock)
        registry.lock(address(game));

        game.moveField(15);

        assertTrue(game.isSolved(), "board solved after move");
    }

    // =========================================================================
    // Multiple sequential moves
    // =========================================================================

    function test_multipleMovesToSolve() public {
        address validator = deployDummyLockValidator(false);
        IGameNested game = deployGameNested(validator, TWO_MOVES_BOARD);

        assertFalse(game.isSolved(), "should not be solved initially");

        game.moveField(14);
        game.moveField(15);

        assertTrue(game.isSolved(), "board should be solved after 2 moves");
    }

    receive() external payable {}
}
