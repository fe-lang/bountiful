// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IBountyRegistry {
    function lock() external payable returns (uint256);
    function isLocked() external view returns (uint256);
    function registerChallenge(address challenge) external returns (uint256);
    function removeChallenge(address challenge) external returns (uint256);
    function isOpenChallenge(address challenge) external view returns (uint256);
    function claim(address challenge) external returns (uint256);
    function validateOwnsLock(address owner) external view returns (uint256);
    function withdraw() external returns (uint256);
    function getBalance() external view returns (uint256);
}
