// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {SuperTank} from "src/SuperTank.sol";

contract TestContract is Test {
    function setUp() public {}

    // TODO => Cannot deposit gobbler if not the owner

    // TODO => Deposit first Gobbler but NO Goo already deposited

    // TODO => Deposit first Gobbler with some Goo already deposited

    // TODO => Deposit second Gobbler with 0 Goo already deposited and gooAmount = 0

    // TODO => Deposit second Gobbler with 0 Goo already deposited and gooAmount != 0

    // TODO => Cannot deposit Gobbler with wrong Goo Amount

    // TODO => Cannot withdraw Gobbler if not the initial depositor

    // TODO => Deposit goo but no gobblers deposited

    // TODO => Deposit goo with one Gobbler deposited

    // TODO => Withdraw goo but no gobblers deposited

    // TODO => Withdraw goo with one Gobbler deposited
}
