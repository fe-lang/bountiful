// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IBountyRegistry {
    function lock(address challenge) external payable returns (uint256);
    function isLocked(address challenge) external view returns (bool);
    function registerChallenge(address challenge, uint128 prizeAmount) external returns (uint256);
    function removeChallenge(address challenge) external returns (uint256);
    function isOpenChallenge(address challenge) external view returns (bool);
    function claim(address challenge) external returns (uint256);
    function validateOwnsLock(address owner, address challenge) external view returns (uint256);
    function withdraw() external returns (uint256);
    function getBalance() external view returns (uint256);
}
