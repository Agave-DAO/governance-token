// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract GovToken is ERC20, ERC20Permit, ERC20Votes, Ownable {

		struct WeightedToken{
    		address token;
    		uint256 weight;
				uint256 maxDeposits;
		}

		WeightedToken[] public weightedTokens;
		address[] public allTokens;

		address public governor;
		uint256 public globalTimeLock;

		mapping(address user => mapping(address token => uint256 amount)) public deposits;
		mapping(address user => uint256 oldVirtualBalance) public oldBalances;

		event Deposit(address user, address token, uint depositAmount);
		event Redeem(address user, address token, uint redeemAmount);
		event LockedUntil(uint256 timeToUnlock);
		event TokenAdded(address token, uint256 weight, uint256 maxDeposits);
		event TokenRemoved(address token);
		event TokenUpdated(address token, uint256 weight, uint256 maxDeposits);

		modifier notLocked(address from) {
				require (from == address(0) || globalTimeLock < block.timestamp, "Mint/burn/transfer locked");
				_;
		}

    constructor(address _governor) ERC20("Token", "TK") ERC20Permit("Token") Ownable(msg.sender) {
				governor = _governor;
		}

		function deposit(address token, uint256 amount) external notLocked(msg.sender) {

				(WeightedToken memory tok, ) = getWeightedToken(token);

				require(tok.token != address(0), "Bad token");

				uint256 deposited = ERC20(token).balanceOf(address(this));
				require(deposited + amount <= tok.maxDeposits, "Full");
				require(ERC20(token).transferFrom(msg.sender, address(this), amount), "Token transfer fail");

				deposits[msg.sender][token] += amount;

				updateBalance(msg.sender);

				emit Deposit(msg.sender, token, amount);
		}

		function redeem(address token, uint256 amount) external notLocked(msg.sender) {

				require(amount > 0, "Amount is zero");

				deposits[msg.sender][token] -= amount;

				require(ERC20(token).transfer(msg.sender, amount),"Token transfer fail");

				updateBalance(msg.sender);

				emit Redeem(msg.sender, token, amount);
		}

		function updateBalance(address user) internal {
				uint256 newBalance = balanceOf(user);
				uint256 oldBalance = oldBalances[user];

				if (newBalance > oldBalance){
						emit Transfer(address(0), user, newBalance - oldBalance);
				} else {
					if (oldBalance > newBalance){
						emit Transfer(user, address(0), oldBalance- newBalance);
					}
				}

				oldBalances[user] = newBalance;
		}

		function addToken(address token, uint256 weight, uint256 maxDeposits) external onlyOwner {
				(WeightedToken memory tok, ) = getWeightedToken(token);
				require(tok.token == address(0), "Already exists");

				weightedTokens.push(WeightedToken({token: token, weight: weight, maxDeposits: maxDeposits}));

				// add to allTokens only once
				bool exists;
				for (uint i; i < allTokens.length ; i++){
						if (token == allTokens[i]) {
								exists = true;
								break;
						}
				}
				if (!exists){
					 allTokens.push(token);
				}
				
				emit TokenAdded(token, weight, maxDeposits);
		}

		function removeToken(address token) external onlyOwner {
				(WeightedToken memory tok, uint256 idx) = getWeightedToken(token);
				require(tok.token != address(0), "Does not exist");

				weightedTokens[idx] = weightedTokens[ weightedTokens.length - 1 ];

				weightedTokens.pop();

				emit TokenRemoved(token);
		}

		function updateToken(address token, uint256 weight, uint256 maxDeposits) external onlyOwner {
				(WeightedToken memory tok, uint256 idx) = getWeightedToken(token);
				require(tok.token != address(0), "Does not exist");

				weightedTokens[idx] = WeightedToken( {token: token, weight: weight, maxDeposits: maxDeposits} );

				emit TokenUpdated(token, weight, maxDeposits);
		}

		function setGovernor(address newGovernor) external onlyOwner {
				governor = newGovernor;
		}

		function timeLock(uint256 timeToUnlock) external {
				require(msg.sender == governor,"Not allowed");

				if (timeToUnlock > globalTimeLock) {
						globalTimeLock = timeToUnlock;

						emit LockedUntil(timeToUnlock);
				}
				
		}

		function getWeightedToken(address token) public view returns(WeightedToken memory, uint256 idx) {
				for (uint i; i < weightedTokens.length ; i++){
						if (token == weightedTokens[i].token){
								return ( weightedTokens[i] , i);
						}
				}
				return ( WeightedToken( { token: address(0), weight:0, maxDeposits: 0 } ), type(uint).max );
		}

		// overrides for ERC20

		function balanceOf(address user) public view override returns (uint256 balance){
				for (uint i	; i < weightedTokens.length ; i++) {
						balance += weightedTokens[i].weight * deposits[user][weightedTokens[i].token];
				}
		}

		function depositBalances(address user) public view returns(address[] memory, uint256[] memory) {
				uint256[] memory balances = new uint256[](allTokens.length);

				for (uint i; i < allTokens.length; i++){
						balances[i] = deposits[user][allTokens[i]];
				}

				return (allTokens, balances);
		}

    // The functions below are overrides required by Solidity.

    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) notLocked(from) {
				require(from == address(0) || to == address(0), "Transfers not supported");
        super._update(from, to, amount);
    }

    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

}