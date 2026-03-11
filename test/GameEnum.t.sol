// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {FeDeployer} from "../src/FeDeployer.sol";
import {IBountyRegistry} from "../src/interfaces/IBountyRegistry.sol";

interface IGameEnum {
    function getBoard(uint256 index) external view returns (uint256);
    function isSolved() external view returns (bool);
    function moveField(uint256 index) external;
    function setCell(uint256 index, uint256 value) external;
}

contract GameEnumTest is Test {
    string constant GAME_ENUM_BIN = "contracts/out/GameEnum.bin";
    string constant DUMMY_LOCK_VALIDATOR_BIN = "contracts/out/DummyLockValidator.bin";
    string constant REGISTRY_BIN = "contracts/out/BountyRegistry.bin";

    function deployGameEnum(address lockValidator) internal returns (IGameEnum) {
        address addr = FeDeployer.deployFeWithArgs(
            vm, GAME_ENUM_BIN, abi.encode(lockValidator)
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

    function setupWinningBoard(IGameEnum game) internal {
        for (uint256 i = 0; i < 15; i++) {
            game.setCell(i, i + 1);
        }
        game.setCell(15, 0);
    }

    function setupAlmostSolvedBoard(IGameEnum game) internal {
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
        IGameEnum game = deployGameEnum(validator);

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
        IGameEnum game = deployGameEnum(validator);

        setupWinningBoard(game);

        assertTrue(game.isSolved(), "winning board should be solved");
    }

    function test_unsolvedBoard() public {
        address validator = deployDummyLockValidator(false);
        IGameEnum game = deployGameEnum(validator);

        setupAlmostSolvedBoard(game);

        assertFalse(game.isSolved(), "almost-solved board should not be solved");
    }

    // =========================================================================
    // Move and solve
    // =========================================================================

    function test_moveAndSolve() public {
        address validator = deployDummyLockValidator(false);
        IGameEnum game = deployGameEnum(validator);

        setupAlmostSolvedBoard(game);

        game.moveField(15);

        assertTrue(game.isSolved(), "board should be solved after move");
    }

    function test_invalidMove() public {
        address validator = deployDummyLockValidator(false);
        IGameEnum game = deployGameEnum(validator);

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
        IGameEnum game = deployGameEnum(validator);

        setupAlmostSolvedBoard(game);

        vm.expectRevert();
        game.moveField(15);
    }

    // =========================================================================
    // SetCell edge cases
    // =========================================================================

    function test_setCellAlreadyInitialized() public {
        address validator = deployDummyLockValidator(false);
        IGameEnum game = deployGameEnum(validator);

        setupWinningBoard(game);

        vm.expectRevert();
        game.setCell(0, 99);
    }

    function test_setCellInvalidIndex() public {
        address validator = deployDummyLockValidator(false);
        IGameEnum game = deployGameEnum(validator);

        vm.expectRevert();
        game.setCell(16, 1);
    }

    // =========================================================================
    // MoveField invalid index
    // =========================================================================

    function test_moveFieldInvalidIndex() public {
        address validator = deployDummyLockValidator(false);
        IGameEnum game = deployGameEnum(validator);

        setupWinningBoard(game);

        vm.expectRevert();
        game.moveField(16);
    }

    // =========================================================================
    // MoveField with real registry as lock validator
    // =========================================================================

    function test_moveFieldWithRealRegistry() public {
        IBountyRegistry registry = deployRegistry(address(this), 0);
        IGameEnum game = deployGameEnum(address(registry));

        setupAlmostSolvedBoard(game);

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
        IGameEnum game = deployGameEnum(validator);

        // Board: [1..13, 0, 14, 15] — empty at 13
        for (uint256 i = 0; i < 13; i++) {
            game.setCell(i, i + 1);
        }
        game.setCell(13, 0);
        game.setCell(14, 14);
        game.setCell(15, 15);

        assertFalse(game.isSolved(), "should not be solved initially");

        game.moveField(14);
        game.moveField(15);

        assertTrue(game.isSolved(), "board should be solved after 2 moves");
    }

    receive() external payable {}
}
