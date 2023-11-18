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

    address public user1 = address(14);
    address public user2 = address(13);

    function setUp() public {
        vm.startPrank(user1);

        tok1 = new TestToken();
        tok2 = new TestToken();
        tok3 = new TestToken();

        tok1.transfer(user2, 10000 ether);
        tok2.transfer(user2, 10000 ether);
        tok3.transfer(user2, 10000 ether);

        govToken = new GovToken(address(0));

        vm.stopPrank();
    }

    function testDepositBalanceRedeem() public {
        vm.startPrank(user1);

        govToken.addToken(address(tok1), 100000, type(uint).max);
        govToken.addToken(address(tok2), 200000, type(uint).max);
        govToken.addToken(address(tok3), 300000, type(uint).max);

        vm.stopPrank();

        vm.startPrank(user2);

        uint amt1 = 1000;
        uint amt2 = 50000000000;
        uint amt3 = 10000000000000;

        tok1.approve(address(govToken), type(uint).max);
        tok2.approve(address(govToken), type(uint).max);
        tok3.approve(address(govToken), type(uint).max);

        govToken.deposit(address(tok1), amt1);
        govToken.deposit(address(tok2), amt2);
        govToken.deposit(address(tok3), amt3);

        assertTrue(amt1 == govToken.deposits(user2, address(tok1)));
        assertTrue(amt2 == govToken.deposits(user2, address(tok2)));
        assertTrue(amt3 == govToken.deposits(user2, address(tok3)));
        assertTrue(
            amt1 * 100000 + amt2 * 200000 + amt3 * 300000 ==
                govToken.balanceOf(user2)
        );

        vm.stopPrank();

        vm.prank(user1);
        govToken.updateToken(address(tok1), 400000, 0);

        assertTrue(
            amt1 * 400000 + amt2 * 200000 + amt3 * 300000 ==
                govToken.balanceOf(user2)
        );

        vm.startPrank(user2);

        govToken.redeem(address(tok1), amt2);
        assertTrue(0 == govToken.deposits(user2, address(tok1)));

        govToken.redeem(address(tok1), amt1);
        govToken.redeem(address(tok2), amt2);
        govToken.redeem(address(tok3), amt3);

        assertTrue(0 == govToken.deposits(user2, address(tok1)));
        assertTrue(0 == govToken.deposits(user2, address(tok2)));
        assertTrue(0 == govToken.deposits(user2, address(tok3)));

        vm.expectRevert(); // due to max limit of 0
        govToken.deposit(address(tok1), 1);

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

        (tok, ) = govToken.getWeightedToken(address(tok1));
        assertTrue(tok.weight == 1);

        govToken.removeToken(address(tok1));

        (tokaddr, , ) = govToken.weightedTokens(0);
        assertTrue(tokaddr == address(tok2));
        vm.expectRevert();
        (tokaddr, , ) = govToken.weightedTokens(1);

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
