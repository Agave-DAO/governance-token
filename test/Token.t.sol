// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../src/test/TestToken.sol";
import "../src/GovToken.sol";
import "../src/AgaveGovernance.sol";

contract TokenTests is Test {

    TestToken public tok1;
		TestToken public tok2;
		TestToken public tok3;

		GovToken public govToken;

		address public user1 = address(2);
		address public user2 = address(3);

    function setUp() public {
				vm.startPrank(user1);

        tok1 = new TestToken();
				tok2 = new TestToken();
				tok3 = new TestToken();

				govToken = new GovToken(address(0));

				vm.stopPrank();
    }

		function testAddRemoveChangeTokens() public {
				vm.startPrank(user1);

				address tokaddr;
				GovToken.WeightedToken memory tok;

        govToken.addToken(address(tok1), 100000, type(uint).max);
				assertTrue(govToken.allTokens(0) == address(tok1));

				govToken.addToken(address(tok2), 200000, type(uint).max);
				assertTrue(govToken.allTokens(1) == address(tok2));

				vm.expectRevert("Already exists");
				govToken.addToken(address(tok1), 100000, type(uint).max);

				govToken.updateToken(address(tok1), 1, type(uint).max);

				(tok,) = govToken.getWeightedToken(address(tok1));
				assertTrue(tok.weight == 1);

				govToken.removeToken(address(tok1));

				(tokaddr,,) = govToken.weightedTokens(0);
				assertTrue(tokaddr == address(tok2));
				vm.expectRevert();
				(tokaddr,,) = govToken.weightedTokens(1);

				vm.stopPrank();
    }

		function testOnlyOwnerLock() public {
				vm.expectRevert();
				govToken.addToken(address(tok1), 100000, type(uint).max);

				vm.expectRevert();
				govToken.removeToken(address(tok1));

				vm.expectRevert();
				govToken.updateToken(address(tok1), 100000, type(uint).max);

				vm.expectRevert();
				govToken.setGovernor(user2);
		}


    function testDepositBalance() public {
        assertEq(govToken.balanceOf(user1), 0);
    }

}
