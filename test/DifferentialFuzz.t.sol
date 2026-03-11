// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {FeDeployer} from "../src/FeDeployer.sol";

interface IGame1D {
    function getBoard(uint256 index) external view returns (uint256);
    function isSolved() external view returns (bool);
    function moveField(uint256 index) external;
}

interface IGame2D {
    function getBoard(uint256 row, uint256 col) external view returns (uint256);
    function isSolved() external view returns (bool);
    function moveField(uint256 row, uint256 col) external;
}

contract DifferentialFuzzTest is Test {
    string constant GAME_BIN = "contracts/out/Game.bin";
    string constant GAME_2D_BIN = "contracts/out/Game2D.bin";
    string constant GAME_ENUM_BIN = "contracts/out/GameEnum.bin";
    string constant GAME_BITBOARD_BIN = "contracts/out/GameBitboard.bin";
    string constant GAME_TRAIT_BIN = "contracts/out/GameTrait.bin";
    string constant GAME_NESTED_BIN = "contracts/out/GameNested.bin";
    string constant DUMMY_LOCK_VALIDATOR_BIN = "contracts/out/DummyLockValidator.bin";

    uint256 constant SOLVED_BOARD = 0x0FEDCBA987654321;
    uint256 constant MAX_ACTIONS = 16;

    struct Games {
        address game;
        address game2d;
        address gameEnum;
        address gameBitboard;
        address gameTrait;
        address gameNested;
    }

    function testFuzz_differentialMoveSequence(uint256 seed, bytes memory actions) public {
        vm.assume(actions.length <= MAX_ACTIONS);

        uint256 referenceBoard = permutedBoard(seed);
        Games memory games = deployGames(referenceBoard);

        assertStateMatchesReference(games, referenceBoard);

        for (uint256 i = 0; i < actions.length; i++) {
            uint256 rawIndex = uint8(actions[i]);
            (bool expectedOk, uint256 nextBoard) = moveReference(referenceBoard, rawIndex);

            (bool gameOk,) = games.game.call(abi.encodeWithSelector(IGame1D.moveField.selector, rawIndex));
            (bool enumOk,) = games.gameEnum.call(abi.encodeWithSelector(IGame1D.moveField.selector, rawIndex));
            (bool bitboardOk,) = games.gameBitboard.call(abi.encodeWithSelector(IGame1D.moveField.selector, rawIndex));
            (bool traitOk,) = games.gameTrait.call(abi.encodeWithSelector(IGame1D.moveField.selector, rawIndex));
            (bool nestedOk,) = games.gameNested.call(abi.encodeWithSelector(IGame1D.moveField.selector, rawIndex));

            uint256 row = rawIndex / 4;
            uint256 col = rawIndex % 4;
            (bool game2dOk,) = games.game2d.call(abi.encodeWithSelector(IGame2D.moveField.selector, row, col));

            assertEq(gameOk, expectedOk, "Game move result diverged from reference");
            assertEq(game2dOk, expectedOk, "Game2D move result diverged from reference");
            assertEq(enumOk, expectedOk, "GameEnum move result diverged from reference");
            assertEq(bitboardOk, expectedOk, "GameBitboard move result diverged from reference");
            assertEq(traitOk, expectedOk, "GameTrait move result diverged from reference");
            assertEq(nestedOk, expectedOk, "GameNested move result diverged from reference");

            if (expectedOk) {
                referenceBoard = nextBoard;
            }

            assertStateMatchesReference(games, referenceBoard);
        }
    }

    function deployGames(uint256 packedBoard) internal returns (Games memory games) {
        address validator = FeDeployer.deployFeWithArgs(
            vm, DUMMY_LOCK_VALIDATOR_BIN, abi.encode(false)
        );

        games.game = FeDeployer.deployFeWithArgs(
            vm, GAME_BIN, abi.encode(validator, packedBoard)
        );
        games.game2d = FeDeployer.deployFeWithArgs(
            vm, GAME_2D_BIN, abi.encode(validator, packedBoard)
        );
        games.gameEnum = FeDeployer.deployFeWithArgs(
            vm, GAME_ENUM_BIN, abi.encode(validator, packedBoard)
        );
        games.gameBitboard = FeDeployer.deployFeWithArgs(
            vm, GAME_BITBOARD_BIN, abi.encode(validator, packedBoard)
        );
        games.gameTrait = FeDeployer.deployFeWithArgs(
            vm, GAME_TRAIT_BIN, abi.encode(validator, packedBoard)
        );
        games.gameNested = FeDeployer.deployFeWithArgs(
            vm, GAME_NESTED_BIN, abi.encode(validator, packedBoard)
        );
    }

    function assertStateMatchesReference(Games memory games, uint256 expectedBoard) internal view {
        uint256 gameBoard = snapshot1D(games.game);
        uint256 game2dBoard = snapshot2D(games.game2d);
        uint256 enumBoard = snapshot1D(games.gameEnum);
        uint256 bitboardBoard = snapshot1D(games.gameBitboard);
        uint256 traitBoard = snapshot1D(games.gameTrait);
        uint256 nestedBoard = snapshot1D(games.gameNested);

        assertEq(gameBoard, expectedBoard, "Game board diverged from reference");
        assertEq(game2dBoard, expectedBoard, "Game2D board diverged from reference");
        assertEq(enumBoard, expectedBoard, "GameEnum board diverged from reference");
        assertEq(bitboardBoard, expectedBoard, "GameBitboard board diverged from reference");
        assertEq(traitBoard, expectedBoard, "GameTrait board diverged from reference");
        assertEq(nestedBoard, expectedBoard, "GameNested board diverged from reference");

        bool expectedSolved = expectedBoard == SOLVED_BOARD;
        assertEq(readSolved1D(games.game), expectedSolved, "Game isSolved diverged from reference");
        assertEq(readSolved2D(games.game2d), expectedSolved, "Game2D isSolved diverged from reference");
        assertEq(readSolved1D(games.gameEnum), expectedSolved, "GameEnum isSolved diverged from reference");
        assertEq(readSolved1D(games.gameBitboard), expectedSolved, "GameBitboard isSolved diverged from reference");
        assertEq(readSolved1D(games.gameTrait), expectedSolved, "GameTrait isSolved diverged from reference");
        assertEq(readSolved1D(games.gameNested), expectedSolved, "GameNested isSolved diverged from reference");
    }

    function snapshot1D(address target) internal view returns (uint256 packedBoard) {
        for (uint256 i = 0; i < 16; i++) {
            packedBoard |= readBoard1D(target, i) << (i * 4);
        }
    }

    function snapshot2D(address target) internal view returns (uint256 packedBoard) {
        for (uint256 i = 0; i < 16; i++) {
            uint256 row = i / 4;
            uint256 col = i % 4;
            packedBoard |= readBoard2D(target, row, col) << (i * 4);
        }
    }

    function readBoard1D(address target, uint256 index) internal view returns (uint256 value) {
        (bool ok, bytes memory data) =
            target.staticcall(abi.encodeWithSelector(IGame1D.getBoard.selector, index));
        assertTrue(ok, "1D getBoard reverted");
        value = abi.decode(data, (uint256));
    }

    function readBoard2D(address target, uint256 row, uint256 col) internal view returns (uint256 value) {
        (bool ok, bytes memory data) =
            target.staticcall(abi.encodeWithSelector(IGame2D.getBoard.selector, row, col));
        assertTrue(ok, "2D getBoard reverted");
        value = abi.decode(data, (uint256));
    }

    function readSolved1D(address target) internal view returns (bool solved) {
        (bool ok, bytes memory data) =
            target.staticcall(abi.encodeWithSelector(IGame1D.isSolved.selector));
        assertTrue(ok, "1D isSolved reverted");
        solved = abi.decode(data, (bool));
    }

    function readSolved2D(address target) internal view returns (bool solved) {
        (bool ok, bytes memory data) =
            target.staticcall(abi.encodeWithSelector(IGame2D.isSolved.selector));
        assertTrue(ok, "2D isSolved reverted");
        solved = abi.decode(data, (bool));
    }

    function permutedBoard(uint256 seed) internal pure returns (uint256 packedBoard) {
        uint256[16] memory cells;
        for (uint256 i = 0; i < 16; i++) {
            cells[i] = i;
        }

        for (uint256 i = 16; i > 1; i--) {
            uint256 swapIndex = uint256(keccak256(abi.encode(seed, i))) % i;
            uint256 lastIndex = i - 1;
            uint256 tmp = cells[lastIndex];
            cells[lastIndex] = cells[swapIndex];
            cells[swapIndex] = tmp;
        }

        for (uint256 i = 0; i < 16; i++) {
            packedBoard |= cells[i] << (i * 4);
        }
    }

    function moveReference(uint256 packedBoard, uint256 rawIndex)
        internal
        pure
        returns (bool ok, uint256 nextBoard)
    {
        nextBoard = packedBoard;
        if (rawIndex > 15) {
            return (false, packedBoard);
        }

        uint256 emptyIndex = findLastZero(packedBoard);
        if (emptyIndex > 15 || !isAdjacent(emptyIndex, rawIndex)) {
            return (false, packedBoard);
        }

        uint256 value = getCell(packedBoard, rawIndex);
        nextBoard = setCell(packedBoard, rawIndex, 0);
        nextBoard = setCell(nextBoard, emptyIndex, value);
        return (true, nextBoard);
    }

    function findLastZero(uint256 packedBoard) internal pure returns (uint256 emptyIndex) {
        emptyIndex = 16;
        for (uint256 i = 0; i < 16; i++) {
            if (getCell(packedBoard, i) == 0) {
                emptyIndex = i;
            }
        }
    }

    function isAdjacent(uint256 a, uint256 b) internal pure returns (bool) {
        uint256 rowA = a / 4;
        uint256 colA = a % 4;
        uint256 rowB = b / 4;
        uint256 colB = b % 4;

        uint256 rowDiff = rowA > rowB ? rowA - rowB : rowB - rowA;
        uint256 colDiff = colA > colB ? colA - colB : colB - colA;
        return (rowDiff == 1 && colDiff == 0) || (rowDiff == 0 && colDiff == 1);
    }

    function getCell(uint256 packedBoard, uint256 index) internal pure returns (uint256) {
        return (packedBoard >> (index * 4)) & 0xF;
    }

    function setCell(uint256 packedBoard, uint256 index, uint256 value)
        internal
        pure
        returns (uint256)
    {
        uint256 shift = index * 4;
        uint256 mask = ~(uint256(0xF) << shift);
        return (packedBoard & mask) | (value << shift);
    }
}
