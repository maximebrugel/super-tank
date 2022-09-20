// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {SuperTank} from "src/SuperTank.sol";

contract TestContract is Test {

    function setUp() public {
    }

    function testBar() public {
        assertEq(uint256(1), uint256(1), "ok");
    }
}
