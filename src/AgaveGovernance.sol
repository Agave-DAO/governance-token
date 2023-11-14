// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IGovernor, Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {ITimeLock} from "./ITimeLock.sol";
import {IAvatar} from "./utils/IAvatar.sol";
import {MultisendEncoder} from "./MultisendEncoder.sol";
import {Enum} from "./utils/Enum.sol";

contract AgaveGovernance is
    Governor,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction
{
		ITimeLock govToken;

		/// @dev Functions restricted to `onlyGovernance()` are only callable by `owner`.
    address public owner;
    /// @dev Address of the multisend contract that this contract should use to bundle transactions.
    address public multisend;
    /// @dev Address that this module will pass transactions to.
    address public target;

		/// @dev Emitted each time the multisend address is set.
    event MultisendSet(address indexed multisend);
    /// @dev Emitted each time the Target is set.
    event TargetSet(address indexed previousTarget, address indexed newTarget);
    /// @dev Emitted each time ownership is transferred.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    /// @dev Emitted upon successful setup
    event OZGovernorModuleSetUp(address indexed owner, address indexed target);

		/// @dev Transaction execution failed.
    error TransactionsFailed();

    constructor(
				address _owner,
				address _target,
				address _multisend,
        IVotes _token
    ) Governor("Governance") GovernorVotes(_token) GovernorVotesQuorumFraction(4) {
				govToken = ITimeLock(address(_token));
				owner = _owner;
        target = _target;
        multisend = _multisend;
				emit OZGovernorModuleSetUp(_owner, _target);
		}

    function votingDelay() public pure override returns (uint256) {
        return 0; // 1 day
    }

    function votingPeriod() public pure override returns (uint256) {
        return 300; // 1 week
    }

    function proposalThreshold() public pure override returns (uint256) {
        return 0;
    }

		/// @dev Execute via a Zodiac avatar, like a Gnosis Safe.
    function _execute(
        uint256, /* proposalId */
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 /*descriptionHash*/
    ) internal {
        (address to, uint256 value, bytes memory data, Enum.Operation operation) = MultisendEncoder.encodeMultisend(
            multisend,
            targets,
            values,
            calldatas
        );
        bool success = IAvatar(target).execTransactionFromModule(to, value, data, operation);
        if (!success) {
            revert TransactionsFailed();
        }
    }

		/// @dev Transfers ownership of this contract to a new address.
    /// @param _owner Address of the account to be set as the new owner.
    /// @notice Can only be called by `owner`.
    function transferOwnership(address _owner) public onlyGovernance {
        emit OwnershipTransferred(owner, _owner);
        owner = _owner;
    }

    /// @dev Sets the address of the multisend contract to be used for batched of transactions.
    /// @param _multisend Address of the multisend contract to be used.
    /// @notice Can only be called by `owner`.
    function setMultisend(address _multisend) public onlyGovernance {
        multisend = _multisend;
        emit MultisendSet(_multisend);
    }

    /// @dev Sets the address of the target contract, on which this contract will call `execTransactionFromModule()`.
    /// @param _target Address of the target contract to be used.
    /// @notice Can only be called by `owner`.
    function setTarget(address _target) public onlyGovernance {
        emit TargetSet(target, _target);
        target = _target;
    }

    /// @dev Returns this module's version.
    function version() public pure override returns (string memory) {
        return "Zodaic OZ Governor Module: v1.0.0";
    }

    // The functions below are overrides required by Solidity.

    function state(uint256 proposalId) public view override returns (ProposalState) {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(
        uint256 proposalId
    ) public view virtual override returns (bool) {
        return super.proposalNeedsQueuing(proposalId);
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    // function _executor() internal view override returns (address) {
    //     return super._executor();
    // }

		/// @dev Returns `owner`.
    /// @notice This differs slightly from a typical Zodiac mod, where `owner` and `avatar`/`executor` would be distinguished.
    function _executor() internal view override returns (address) {
        return owner;
    }

		function _castVote(
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason
    ) internal override returns (uint256) {
				uint256 proposalDeadline = proposalDeadline(proposalId);
				if (govToken.globalTimeLock() < proposalDeadline){
						govToken.timeLock(proposalDeadline);
				}
        return super._castVote(proposalId, account, support, reason);
    }

		function _castVote(
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason,
        bytes memory params
    ) internal override returns (uint256) {
				uint256 proposalDeadline = proposalDeadline(proposalId);
				if (govToken.globalTimeLock() < proposalDeadline){
						govToken.timeLock(proposalDeadline);
				}
        return super._castVote(proposalId, account, support, reason, params);
    }
}