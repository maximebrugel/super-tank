// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "art-gobblers-test/utils/Utilities.sol";
import {LinkToken} from "art-gobblers-test/utils/mocks/LinkToken.sol";

import {ArtGobblers, FixedPointMathLib} from "art-gobblers/ArtGobblers.sol";
import {Goo} from "art-gobblers/Goo.sol";
import {Pages} from "art-gobblers/Pages.sol";
import {GobblerReserve} from "art-gobblers/utils/GobblerReserve.sol";
import {RandProvider} from "art-gobblers/utils/rand/RandProvider.sol";
import {ChainlinkV1RandProvider} from "art-gobblers/utils/rand/ChainlinkV1RandProvider.sol";


// TODO import {VRFCoordinatorMock} from "chainlink/v0.8/mocks/VRFCoordinatorMock.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {MockERC1155} from "solmate/test/utils/mocks/MockERC1155.sol";
import {LibString} from "solmate/utils/LibString.sol";
import {fromDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";

import {Test} from "forge-std/Test.sol";

import {SuperTank} from "src/SuperTank.sol";

contract TestContract is Test {
    address internal deployer;
    address internal artGobblerDeployer;

    Utilities internal utils;
    address payable[] internal users;

    ArtGobblers internal gobblers;
    // VRFCoordinatorMock internal vrfCoordinator;
    LinkToken internal linkToken;
    Goo internal goo;
    Pages internal pages;
    GobblerReserve internal team;
    GobblerReserve internal community;
    RandProvider internal randProvider;

    bytes32 private keyHash;
    uint256 private fee;

    function setUp() public {
        deployer = addr("deployer");
        artGobblerDeployer = addr("artGobblerDeployer");
    }

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

    // Generate address with keccak
    function addr(string memory source) internal returns (address) {
        return address(uint160(uint256(keccak256(abi.encode(source)))));
    }
}
