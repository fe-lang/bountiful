// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// Packed board constants (4 bits per cell, cell 0 at bits 0..3)
uint256 constant SOLVED_BOARD = 0x0FEDCBA987654321;
uint256 constant UNSOLVABLE_BOARD = 0x0EFDCBA987654321; // tiles 14 and 15 swapped
uint256 constant ONE_MOVE_BOARD = 0xF0EDCBA987654321;   // one move from solved
uint256 constant TWO_MOVES_BOARD = 0xFE0DCBA987654321;  // two moves from solved
