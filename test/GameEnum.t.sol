// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {FeDeployer} from "../src/FeDeployer.sol";
import {IBountyRegistry} from "../src/interfaces/IBountyRegistry.sol";

interface IGameEnum {
    function getBoard(uint256 index) external view returns (uint256);
    function isSolved() external view returns (bool);
    function moveField(uint256 index) external;
}

contract GameEnumTest is Test {
    string constant GAME_ENUM_BIN = "contracts/out/GameEnum.bin";
    string constant DUMMY_LOCK_VALIDATOR_BIN = "contracts/out/DummyLockValidator.bin";
    string constant REGISTRY_BIN = "contracts/out/BountyRegistry.bin";

    // Packed board constants (4 bits per cell, cell 0 at bits 0..3)
    uint256 constant SOLVED_BOARD = 0x0FEDCBA987654321;
    uint256 constant UNSOLVABLE_BOARD = 0xF0EDCBA987654321;
    uint256 constant TWO_MOVES_BOARD = 0xFE0DCBA987654321;

    function deployGameEnum(address lockValidator, uint256 packedBoard) internal returns (IGameEnum) {
        address addr = FeDeployer.deployFeWithArgs(
            vm, GAME_ENUM_BIN, abi.encode(lockValidator, packedBoard)
        );
        return IGameEnum(addr);
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
        IGameEnum game = deployGameEnum(validator, SOLVED_BOARD);

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
        IGameEnum game = deployGameEnum(validator, SOLVED_BOARD);

        assertTrue(game.isSolved(), "winning board should be solved");
    }

    function test_unsolvedBoard() public {
        address validator = deployDummyLockValidator(false);
        IGameEnum game = deployGameEnum(validator, UNSOLVABLE_BOARD);

        assertFalse(game.isSolved(), "almost-solved board should not be solved");
    }

    // =========================================================================
    // Move and solve
    // =========================================================================

    function test_moveAndSolve() public {
        address validator = deployDummyLockValidator(false);
        IGameEnum game = deployGameEnum(validator, UNSOLVABLE_BOARD);

        game.moveField(15);

        assertTrue(game.isSolved(), "board should be solved after move");
    }

    function test_invalidMove() public {
        address validator = deployDummyLockValidator(false);
        IGameEnum game = deployGameEnum(validator, UNSOLVABLE_BOARD);

        // Move index 0 — not adjacent to empty at 14
        vm.expectRevert();
        game.moveField(0);
    }

    // =========================================================================
    // MoveField requires lock
    // =========================================================================

    function test_moveFieldRequiresLock() public {
        address validator = deployDummyLockValidator(true);
        IGameEnum game = deployGameEnum(validator, UNSOLVABLE_BOARD);

        vm.expectRevert();
        game.moveField(15);
    }

    // =========================================================================
    // MoveField invalid index
    // =========================================================================

    function test_moveFieldInvalidIndex() public {
        address validator = deployDummyLockValidator(false);
        IGameEnum game = deployGameEnum(validator, SOLVED_BOARD);

        vm.expectRevert();
        game.moveField(16);
    }

    // =========================================================================
    // MoveField with real registry as lock validator
    // =========================================================================

    function test_moveFieldWithRealRegistry() public {
        IBountyRegistry registry = deployRegistry(address(this), 0);
        IGameEnum game = deployGameEnum(address(registry), UNSOLVABLE_BOARD);

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
        IGameEnum game = deployGameEnum(validator, TWO_MOVES_BOARD);

        assertFalse(game.isSolved(), "should not be solved initially");

        game.moveField(14);
        game.moveField(15);

        assertTrue(game.isSolved(), "board should be solved after 2 moves");
    }

    receive() external payable {}
}
