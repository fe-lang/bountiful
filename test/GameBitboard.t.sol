// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {FeDeployer} from "../src/FeDeployer.sol";
import {IBountyRegistry} from "../src/interfaces/IBountyRegistry.sol";

interface IGameBitboard {
    function getBoard(uint256 index) external view returns (uint256);
    function isSolved() external view returns (bool);
    function moveField(uint256 index) external returns (uint256);
    function setCell(uint256 index, uint256 value) external returns (uint256);
}

contract GameBitboardTest is Test {
    uint256 constant ERR_INVALID_INDEX = 1;
    uint256 constant ERR_NOT_MOVABLE = 2;
    uint256 constant ERR_MISSING_LOCK = 3;
    uint256 constant ERR_ALREADY_INITIALIZED = 7;

    string constant GAME_BITBOARD_BIN = "contracts/out/GameBitboard.bin";
    string constant DUMMY_LOCK_VALIDATOR_BIN = "contracts/out/DummyLockValidator.bin";
    string constant REGISTRY_BIN = "contracts/out/BountyRegistry.bin";

    function deployGameBitboard(address lockValidator) internal returns (IGameBitboard) {
        address addr = FeDeployer.deployFeWithArgs(
            vm, GAME_BITBOARD_BIN, abi.encode(lockValidator)
        );
        return IGameBitboard(addr);
    }

    function deployDummyLockValidator(uint256 returnValue) internal returns (address) {
        return FeDeployer.deployFeWithArgs(
            vm, DUMMY_LOCK_VALIDATOR_BIN, abi.encode(returnValue)
        );
    }

    function deployRegistry(address admin, uint256 lockDeposit) internal returns (IBountyRegistry) {
        address addr = FeDeployer.deployFeWithArgs(
            vm, REGISTRY_BIN, abi.encode(admin, lockDeposit)
        );
        return IBountyRegistry(addr);
    }

    function setupWinningBoard(IGameBitboard game) internal {
        for (uint256 i = 0; i < 15; i++) {
            game.setCell(i, i + 1);
        }
        game.setCell(15, 0);
    }

    function setupAlmostSolvedBoard(IGameBitboard game) internal {
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
        address validator = deployDummyLockValidator(0);
        IGameBitboard game = deployGameBitboard(validator);

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
        address validator = deployDummyLockValidator(0);
        IGameBitboard game = deployGameBitboard(validator);

        setupWinningBoard(game);

        assertTrue(game.isSolved(), "winning board should be solved");
    }

    function test_unsolvedBoard() public {
        address validator = deployDummyLockValidator(0);
        IGameBitboard game = deployGameBitboard(validator);

        setupAlmostSolvedBoard(game);

        assertFalse(game.isSolved(), "almost-solved board should not be solved");
    }

    // =========================================================================
    // Move and solve
    // =========================================================================

    function test_moveAndSolve() public {
        address validator = deployDummyLockValidator(0);
        IGameBitboard game = deployGameBitboard(validator);

        setupAlmostSolvedBoard(game);

        uint256 res = game.moveField(15);
        assertEq(res, 0, "valid move should succeed");

        assertTrue(game.isSolved(), "board should be solved after move");
    }

    function test_invalidMove() public {
        address validator = deployDummyLockValidator(0);
        IGameBitboard game = deployGameBitboard(validator);

        setupAlmostSolvedBoard(game);

        // Move index 0 — not adjacent to empty at 14
        uint256 res = game.moveField(0);
        assertEq(res, ERR_NOT_MOVABLE, "non-adjacent move should fail");
    }

    // =========================================================================
    // MoveField requires lock
    // =========================================================================

    function test_moveFieldRequiresLock() public {
        address validator = deployDummyLockValidator(ERR_MISSING_LOCK);
        IGameBitboard game = deployGameBitboard(validator);

        setupAlmostSolvedBoard(game);

        uint256 res = game.moveField(15);
        assertEq(res, ERR_MISSING_LOCK, "move without lock should fail");
    }

    // =========================================================================
    // SetCell edge cases
    // =========================================================================

    function test_setCellAlreadyInitialized() public {
        address validator = deployDummyLockValidator(0);
        IGameBitboard game = deployGameBitboard(validator);

        setupWinningBoard(game);

        uint256 res = game.setCell(0, 99);
        assertEq(res, ERR_ALREADY_INITIALIZED, "setCell after init should fail");
    }

    function test_setCellInvalidIndex() public {
        address validator = deployDummyLockValidator(0);
        IGameBitboard game = deployGameBitboard(validator);

        uint256 res = game.setCell(16, 1);
        assertEq(res, ERR_INVALID_INDEX, "index > 15 should fail");
    }

    // =========================================================================
    // MoveField invalid index
    // =========================================================================

    function test_moveFieldInvalidIndex() public {
        address validator = deployDummyLockValidator(0);
        IGameBitboard game = deployGameBitboard(validator);

        setupWinningBoard(game);

        uint256 res = game.moveField(16);
        assertEq(res, ERR_INVALID_INDEX, "index > 15 should fail");
    }

    // =========================================================================
    // MoveField with real registry as lock validator
    // =========================================================================

    function test_moveFieldWithRealRegistry() public {
        IBountyRegistry registry = deployRegistry(address(this), 0);
        IGameBitboard game = deployGameBitboard(address(registry));

        setupAlmostSolvedBoard(game);

        // Register the game as a challenge (required for locking)
        registry.registerChallenge(address(game), 0);

        uint256 res = game.moveField(15);
        assertEq(res, ERR_MISSING_LOCK, "move without registry lock should fail");

        // Lock the challenge (per-challenge lock)
        uint256 lockRes = registry.lock(address(game));
        assertEq(lockRes, 0, "lock should succeed");

        res = game.moveField(15);
        assertEq(res, 0, "move with registry lock should succeed");

        assertTrue(game.isSolved(), "board solved after move");
    }

    // =========================================================================
    // Multiple sequential moves
    // =========================================================================

    function test_multipleMovesToSolve() public {
        address validator = deployDummyLockValidator(0);
        IGameBitboard game = deployGameBitboard(validator);

        // Board: [1..13, 0, 14, 15] — empty at 13
        for (uint256 i = 0; i < 13; i++) {
            game.setCell(i, i + 1);
        }
        game.setCell(13, 0);
        game.setCell(14, 14);
        game.setCell(15, 15);

        assertFalse(game.isSolved(), "should not be solved initially");

        uint256 res1 = game.moveField(14);
        assertEq(res1, 0, "move 1 should succeed");

        uint256 res2 = game.moveField(15);
        assertEq(res2, 0, "move 2 should succeed");

        assertTrue(game.isSolved(), "board should be solved after 2 moves");
    }

    receive() external payable {}
}
