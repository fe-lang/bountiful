// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IBountyRegistry {
    function lock(address challenge) external payable;
    function isLocked(address challenge) external view returns (bool);
    function registerChallenge(address challenge, uint128 prizeAmount) external;
    function removeChallenge(address challenge) external;
    function isOpenChallenge(address challenge) external view returns (bool);
    function claim(address challenge) external;
    function validateOwnsLock(address owner, address challenge) external view;
    function fund() external payable;
    function withdraw() external;
    function getPrizeAmount(address challenge) external view returns (uint128);
    function getLockInfo(address challenge) external view returns (address claimer, uint256 expiresAt);
    function getLockDeposit() external view returns (uint256);
    function getBalance() external view returns (uint256);
}
