// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IGame {
    function getBoard(uint256 index) external view returns (uint256);
    function isSolved() external view returns (uint256);
    function moveField(uint256 index) external returns (uint256);
    function setCell(uint256 index, uint256 value) external returns (uint256);
}
