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

		WeightedToken[] weightedTokens;

		address public governor;
		uint256 public globalTimeLock;

		mapping(address user => mapping(address token => uint256 amount)) public deposits;

		event Deposit(address user, address token, uint depositAmount, uint govAmount);
		event Redeem(address user, address token, uint redeemAmount);
		event LockedUntil(uint256 timeToUnlock);
		event TokenAdded(address token);
		event TokenRemoved(address token);

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

				uint256 govTokens = tok.weight * amount;

				_mint(msg.sender, govTokens);

				emit Deposit(msg.sender, token, amount, govTokens);
		}

		function redeem(address token, uint256 amount) external notLocked(msg.sender) {

				require(amount > 0, "Amount is zero");

				deposits[msg.sender][token] -= amount;

				(WeightedToken memory tok, ) = getWeightedToken(token);

				uint256 govTokens = tok.weight * amount;

				_burn(msg.sender, govTokens);

				require(ERC20(token).transfer(msg.sender, amount),"Token transfer fail");

				emit Redeem(msg.sender, token, amount);
		}

		function addToken(address token, uint256 weight, uint256 maxDeposits) external onlyOwner {
				(WeightedToken memory tok, uint256 idx) = getWeightedToken(token);
				require(tok.maxDeposits == 0, "Already active");

				if (idx == type(uint).max){
						weightedTokens.push(WeightedToken({token: token, weight: weight, maxDeposits: maxDeposits}));
				} else {
						weightedTokens[idx] = WeightedToken({token: token, weight: weight, maxDeposits: maxDeposits});
				}
				

				emit TokenAdded(token);
		}

		function removeToken(address token) external onlyOwner {
				(WeightedToken memory tok, uint256 idx) = getWeightedToken(token);
				require(idx != type(uint).max && tok.maxDeposits > 0, "Already inactive");

				weightedTokens[idx] = WeightedToken({ token: tok.token, weight: tok.weight, maxDeposits: 0 });

				emit TokenRemoved(token);
		}

		function setGovernor(address newGovernor) external onlyOwner {
				governor = newGovernor;
		}

		function timeLock(uint256 timeToUnlock) external {
				require(msg.sender == governor,"Not allowed");
				globalTimeLock = timeToUnlock;

				emit LockedUntil(timeToUnlock);
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
						if (weightedTokens[i].maxDeposits > 0){
								unchecked { balance += weightedTokens[i].weight * deposits[user][weightedTokens[i].token]; }
						}
				}
		}

    // The functions below are overrides required by Solidity.

    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) notLocked(from) {
        super._update(from, to, amount);
    }

    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

}