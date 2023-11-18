// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITimeLock {
		function timeLock(uint256 timeToUnlock) external;
		function globalTimeLock() external view returns (uint256);
		function updateVotingPower(address user) external;
}