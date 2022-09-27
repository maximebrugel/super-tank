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

import {VRFCoordinatorMock} from "chainlink/v0.8/mocks/VRFCoordinatorMock.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {MockERC1155} from "solmate/test/utils/mocks/MockERC1155.sol";
import {LibString} from "solmate/utils/LibString.sol";
import {fromDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {SuperTank} from "../src/SuperTank.sol";

contract SuperTank_Tests is Test {
    address internal deployer;
    address internal artGobblerDeployer;
    address internal feesRecipient;

    Utilities internal utils;
    address payable[] internal users;
    address payable[] internal gobblerOwners;

    ArtGobblers internal gobblers;
    VRFCoordinatorMock internal vrfCoordinator;
    LinkToken internal linkToken;
    Goo internal goo;
    Pages internal pages;
    GobblerReserve internal team;
    GobblerReserve internal community;
    RandProvider internal randProvider;

    bytes32 private keyHash;
    uint256 private fee;

    SuperTank internal superTank;

    error NotDepositor(uint256 gobblerId);

    function setUp() public {
        deployer = addr("deployer");
        artGobblerDeployer = addr("artGobblerDeployer");
        feesRecipient = addr("feesRecipient");

        utils = new Utilities();
        users = utils.createUsers(5);
        gobblerOwners = utils.createUsers(5);
        linkToken = new LinkToken();
        vrfCoordinator = new VRFCoordinatorMock(address(linkToken));

        //gobblers contract will be deployed after 4 contract deploys, and pages after 5
        address gobblerAddress = utils.predictContractAddress(artGobblerDeployer, 4);
        address pagesAddress = utils.predictContractAddress(artGobblerDeployer, 5);

        vm.startPrank(artGobblerDeployer);
        team = new GobblerReserve(ArtGobblers(gobblerAddress), address(this));
        community = new GobblerReserve(ArtGobblers(gobblerAddress), address(this));
        randProvider = new ChainlinkV1RandProvider(
            ArtGobblers(gobblerAddress),
            address(vrfCoordinator),
            address(linkToken),
            keyHash,
            fee
        );

        goo = new Goo(
            // Gobblers:
            gobblerAddress,
            // Pages:
            pagesAddress
        );

        gobblers = new ArtGobblers(
            keccak256(abi.encodePacked(users[0])),
            block.timestamp,
            goo,
            Pages(pagesAddress),
            address(team),
            address(community),
            randProvider,
            "base",
            ""
        );

        pages = new Pages(block.timestamp, goo, address(0xBEEF), gobblers, "");

        vm.stopPrank();
        vm.startPrank(deployer);

        superTank = new SuperTank(ERC20(address(goo)), gobblers, 95, feesRecipient);

        vm.stopPrank();

        // Add goo balances
        deal(address(goo), address(this), 100000 ether);
        deal(address(goo), gobblerOwners[0], 100000 ether);
        deal(address(goo), gobblerOwners[1], 100000 ether);

        vm.startPrank(gobblerOwners[0]);

        // Had half goo balance to gobblers virtual balance
        gobblers.addGoo(50000 ether);
        // Mint a Gobbler with goo virtual balance
        gobblers.mintFromGoo(gobblers.gobblerPrice(), true);

        vm.stopPrank();
        vm.startPrank(gobblerOwners[1]);

        // Had half goo balance to gobblers virtual balance
        gobblers.addGoo(50000 ether);
        // Mint a Gobbler with goo virtual balance
        gobblers.mintFromGoo(gobblers.gobblerPrice(), true);

        vm.stopPrank();
    }

    /// @dev Cannot deposit gobbler if not the owner
    function testDepositNotOwnedGobbler() public {
        gobblers.setApprovalForAll(address(superTank), true);

        vm.expectRevert("WRONG_FROM");
        superTank.depositGobbler(1);
    }

    /// @dev Deposit first Gobbler but NO Goo already deposited
    function testFirstDepositWithoutGoo() public {
        vm.startPrank(gobblerOwners[0]);

        gobblers.setApprovalForAll(address(superTank), true);
        goo.approve(address(superTank), type(uint256).max);

        superTank.depositGobbler(1);
        superTank.deposit(100 ether, gobblerOwners[0]);

        assertEq(gobblers.ownerOf(1), address(superTank));
        assertEq(gobblers.gooBalance(address(superTank)), 100 ether);
        assertEq(goo.balanceOf(address(superTank)), 0);
    }

    /// @dev Deposit first Gobbler with some Goo already deposited
    function testFirstDepositWithGoo() public {
        vm.startPrank(gobblerOwners[0]);

        gobblers.setApprovalForAll(address(superTank), true);
        goo.approve(address(superTank), type(uint256).max);

        superTank.deposit(100 ether, gobblerOwners[0]);

        superTank.depositGobbler(1);

        superTank.deposit(100 ether, gobblerOwners[0]);

        assertEq(gobblers.ownerOf(1), address(superTank));
        assertEq(gobblers.gooBalance(address(superTank)), 200 ether);
        assertEq(goo.balanceOf(address(superTank)), 0);
    }

    /// @dev Deposit second Gobbler with 0 Goo already deposited and gooAmount = 0
    function testSecondDepositWithoutGooAndZeroAmount() public {
        vm.startPrank(gobblerOwners[1]);

        gobblers.setApprovalForAll(address(superTank), true);
        superTank.depositGobbler(2);

        vm.stopPrank();
        vm.startPrank(gobblerOwners[0]);

        gobblers.setApprovalForAll(address(superTank), true);
        goo.approve(address(superTank), type(uint256).max);

        superTank.depositGobbler(1);

        assertEq(gobblers.ownerOf(1), address(superTank));
        assertEq(gobblers.ownerOf(2), address(superTank));
        assertEq(gobblers.gooBalance(address(superTank)), 0);
        assertEq(goo.balanceOf(address(superTank)), 0);
    }

    /// @dev Deposit second Gobbler with 0 Goo already deposited and gooAmount != 0
    function testSecondDepositWithoutGoo() public {
        vm.startPrank(gobblerOwners[1]);

        gobblers.setApprovalForAll(address(superTank), true);
        superTank.depositGobbler(2);

        vm.stopPrank();
        vm.startPrank(gobblerOwners[0]);

        gobblers.setApprovalForAll(address(superTank), true);
        goo.approve(address(superTank), type(uint256).max);

        superTank.depositGobbler(1);
        superTank.deposit(100 ether, gobblerOwners[0]);

        assertEq(gobblers.ownerOf(1), address(superTank));
        assertEq(gobblers.ownerOf(2), address(superTank));
        assertEq(gobblers.gooBalance(address(superTank)), 100 ether);
        assertEq(goo.balanceOf(address(superTank)), 0);
    }

    /// @dev Cannot deposit Gobbler with wrong Goo Amount
    function testCannotDepositWithWrongGooAmount() public {
        vm.startPrank(gobblerOwners[0]);

        gobblers.setApprovalForAll(address(superTank), true);
        goo.approve(address(superTank), type(uint256).max);

        vm.expectRevert("TRANSFER_FROM_FAILED");
        superTank.deposit(type(uint256).max, gobblerOwners[0]);
    }

    /// @dev Cannot withdraw Gobbler if not the initial depositor
    function testCannotWithdrawIfNotDepositor() public {
        vm.startPrank(gobblerOwners[0]);

        gobblers.setApprovalForAll(address(superTank), true);
        goo.approve(address(superTank), type(uint256).max);

        superTank.depositGobbler(1);
        superTank.deposit(100 ether, gobblerOwners[0]);

        vm.stopPrank();

        vm.expectRevert(abi.encodePacked(NotDepositor.selector, uint256(1)));
        superTank.withdrawGobbler(1);
    }

    /// @dev Deposit goo but no gobblers deposited
    function testDepositGooButNoGobbler() public {
        vm.startPrank(gobblerOwners[0]);

        goo.approve(address(superTank), type(uint256).max);

        superTank.deposit(100 ether, gobblerOwners[0]);

        assertEq(gobblers.ownerOf(1), gobblerOwners[0]);
        assertEq(gobblers.gooBalance(address(superTank)), 0);
        assertEq(goo.balanceOf(address(superTank)), 100 ether);
    }

    /// @dev Deposit goo with one Gobbler deposited
    function testDepositGooWithGobblerDeposited() public {
        vm.startPrank(gobblerOwners[1]);

        gobblers.setApprovalForAll(address(superTank), true);
        superTank.depositGobbler(2);

        vm.stopPrank();
        vm.startPrank(gobblerOwners[0]);

        goo.approve(address(superTank), type(uint256).max);

        superTank.deposit(100 ether, gobblerOwners[0]);

        assertEq(gobblers.ownerOf(1), gobblerOwners[0]);
        assertEq(gobblers.ownerOf(2), address(superTank));
        assertEq(gobblers.gooBalance(address(superTank)), 100 ether);
        assertEq(goo.balanceOf(address(superTank)), 0);
    }

    /// @dev Withdraw goo but no gobblers deposited
    function testWithdrawGooButNoGobbler() public {
        testDepositGooButNoGobbler();

        uint256 userBalanceBefore = goo.balanceOf(gobblerOwners[0]);
        uint256 superTankBalanceBefore = goo.balanceOf(address(superTank));

        superTank.withdraw(50 ether, gobblerOwners[0], gobblerOwners[0]);

        assertEq(goo.balanceOf(gobblerOwners[0]), userBalanceBefore + 50 ether);
        assertEq(goo.balanceOf(address(superTank)), superTankBalanceBefore - 50 ether);
        assertEq(gobblers.gooBalance(address(superTank)), 0);
    }

    /// @dev Withdraw goo with one Gobbler deposited
    function testWithdrawGooWithGobblerDeposited() public {
        testDepositGooWithGobblerDeposited();

        uint256 userBalanceBefore = goo.balanceOf(gobblerOwners[0]);
        uint256 superTankVirtualBalanceBefore = gobblers.gooBalance(address(superTank));

        superTank.withdraw(50 ether, gobblerOwners[0], gobblerOwners[0]);

        assertEq(goo.balanceOf(gobblerOwners[0]), userBalanceBefore + 50 ether);
        assertEq(goo.balanceOf(address(superTank)), 0);
        assertEq(gobblers.gooBalance(address(superTank)), superTankVirtualBalanceBefore - 50 ether);
    }

    // Generate address with keccak
    function addr(string memory source) internal returns (address) {
        return address(uint160(uint256(keccak256(abi.encode(source)))));
    }
}
