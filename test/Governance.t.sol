// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../src/test/TestToken.sol";
import "../src/GovToken.sol";
import "../src/AgaveGovernance.sol";
import "../src/test/ISafe.sol";

contract CounterTest is Test {
    TestToken public tok1;
    TestToken public tok2;
    TestToken public tok3;

    GovToken public govToken;
    AgaveGovernance public gov;

    address public user1 = address(0x9eEFf28A000F0C2C1DE7a7F76cd728Bb10557064);
    address public user2 = address(13);

    address public gnosisMultisendCallOnly =
        0x40A2aCCbd92BCA938b02010E17A5b8929b49130D;
    address public gnosisMultisender =
        0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761;
    ISafe public gnosisSafe = ISafe(0xA4c9F93f6cBbad35166A62Fb6b28ED3fc24c717C);

    uint256 gcFork;

    function setUp() public {
        gcFork = vm.createFork("https://rpc.gnosis.gateway.fm/");
        vm.selectFork(gcFork);

        vm.startPrank(user1);

        tok1 = new TestToken();
        tok2 = new TestToken();
        tok3 = new TestToken();

        tok1.transfer(user2, 10000 ether);
        tok2.transfer(user2, 10000 ether);
        tok3.transfer(user2, 10000 ether);

        govToken = new GovToken(address(0));

        govToken.addToken(address(tok1), 100000, type(uint).max);
        govToken.addToken(address(tok2), 200000, type(uint).max);
        govToken.addToken(address(tok3), 300000, type(uint).max);

        gov = new AgaveGovernance(
            user1,
            address(gnosisSafe),
            gnosisMultisender,
            govToken
        );

        vm.stopPrank();
    }

    // function testIncrement() public {
    //     counter.increment();
    //     assertEq(counter.number(), 1);
    // }

    // function testSetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }
}
