// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.6;

import "./utils/Enum.sol";
import "./utils/MultiSend.sol";

library MultisendEncoder {
    error NoTransactions();
    error UnequalArraysLengths();

    function encodeMultisend(
        address multisend,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    )
        public
        pure
        returns (
            address to,
            uint256 value,
            bytes memory data,
            Enum.Operation operation
        )
    {
        if (targets.length == 0) {
            revert NoTransactions();
        }
        if (targets.length != values.length || values.length != calldatas.length) {
            revert UnequalArraysLengths();
        }

        if (targets.length > 1) {
            to = multisend;
            value = 0;
            data = hex"";
            for (uint256 i; i < targets.length; i++) {
                data = abi.encodePacked(
                    data,
                    abi.encodePacked(
                        uint8(Enum.Operation.Call), /// operation as an uint8.
                        targets[i], /// to as an address.
                        values[i], /// value as an uint256.
                        uint256(calldatas[i].length), /// data length as an uint256.
                        calldatas[i] /// data as bytes.
                    )
                );
            }
            data = abi.encodeWithSignature("multiSend(bytes)", data);
            operation = Enum.Operation.DelegateCall;
        } else {
            to = targets[0];
            value = values[0];
            data = calldatas[0];
            operation = Enum.Operation.Call;
        }
    }
}
