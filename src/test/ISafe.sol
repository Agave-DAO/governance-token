// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISafe {

		function SafeMultiSigTransaction (address to, uint256 value, bytes data, uint8 operation, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address refundReceiver, bytes signatures, bytes additionalInfo) external;
		function enableModule(address module) external;
}