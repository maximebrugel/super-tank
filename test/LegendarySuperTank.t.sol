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

import {LegendarySuperTank} from "../src/LegendarySuperTank.sol";

contract LegendarySuperTank_Tests is Test {
    address internal deployer;
    address internal artGobblerDeployer;

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

    LegendarySuperTank internal superTank;

    error NotDepositor(uint256 gobblerId);
    error NoGobblerDeposited();

    function setUp() public {
        deployer = addr("deployer");
        artGobblerDeployer = addr("artGobblerDeployer");

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

        superTank = new LegendarySuperTank(ERC20(address(goo)), gobblers, "Goo SuperTank", "GooST");

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
    function testLegendaryDepositNotOwnedGobbler() public {
        gobblers.setApprovalForAll(address(superTank), true);

        vm.expectRevert("WRONG_FROM");
        superTank.depositGobbler(1, 100 ether);
    }

    /// @dev Deposit first Gobbler but NO Goo already deposited
    function testLegendaryFirstDepositWithoutGoo() public {
        vm.startPrank(gobblerOwners[0]);

        gobblers.setApprovalForAll(address(superTank), true);
        goo.approve(address(superTank), type(uint256).max);

        superTank.depositGobbler(1, 100 ether);

        assertEq(gobblers.ownerOf(1), address(superTank));
        assertEq(gobblers.gooBalance(address(superTank)), 100 ether);
        assertEq(goo.balanceOf(address(superTank)), 0);
    }

    /// @dev Deposit second Gobbler with 0 Goo already deposited and gooAmount = 0
    function testLegendarySecondDepositWithoutGooAndZeroAmount() public {
        vm.startPrank(gobblerOwners[1]);

        gobblers.setApprovalForAll(address(superTank), true);
        superTank.depositGobbler(2, 0);

        vm.stopPrank();
        vm.startPrank(gobblerOwners[0]);

        gobblers.setApprovalForAll(address(superTank), true);
        goo.approve(address(superTank), type(uint256).max);

        superTank.depositGobbler(1, 0);

        assertEq(gobblers.ownerOf(1), address(superTank));
        assertEq(gobblers.ownerOf(2), address(superTank));
        assertEq(gobblers.gooBalance(address(superTank)), 0);
        assertEq(goo.balanceOf(address(superTank)), 0);
    }

    /// @dev Deposit second Gobbler with 0 Goo already deposited and gooAmount != 0
    function testLegendarySecondDepositWithoutGoo() public {
        vm.startPrank(gobblerOwners[1]);

        gobblers.setApprovalForAll(address(superTank), true);
        superTank.depositGobbler(2, 0);

        vm.stopPrank();
        vm.startPrank(gobblerOwners[0]);

        gobblers.setApprovalForAll(address(superTank), true);
        goo.approve(address(superTank), type(uint256).max);

        superTank.depositGobbler(1, 100 ether);

        assertEq(gobblers.ownerOf(1), address(superTank));
        assertEq(gobblers.ownerOf(2), address(superTank));
        assertEq(gobblers.gooBalance(address(superTank)), 100 ether);
        assertEq(goo.balanceOf(address(superTank)), 0);
    }

    /// @dev Cannot deposit Gobbler with wrong Goo Amount
    function testLegendaryCannotDepositWithWrongGooAmount() public {
        vm.startPrank(gobblerOwners[0]);

        gobblers.setApprovalForAll(address(superTank), true);
        goo.approve(address(superTank), type(uint256).max);

        vm.expectRevert("TRANSFER_FROM_FAILED");
        superTank.depositGobbler(1, type(uint256).max);
    }

    /// @dev Cannot withdraw Gobbler if not the initial depositor
    function testLegendaryCannotWithdrawIfNotDepositor() public {
        vm.startPrank(gobblerOwners[0]);

        gobblers.setApprovalForAll(address(superTank), true);
        goo.approve(address(superTank), type(uint256).max);

        superTank.depositGobbler(1, 100 ether);

        vm.stopPrank();

        vm.expectRevert(abi.encodePacked(NotDepositor.selector, uint256(1)));
        superTank.withdrawGobbler(1);
    }

    /// @dev Deposit goo but no gobblers deposited
    function testLegendaryDepositGooButNoGobbler() public {
        vm.startPrank(gobblerOwners[0]);

        goo.approve(address(superTank), type(uint256).max);

        vm.expectRevert(NoGobblerDeposited.selector);
        superTank.deposit(100 ether, gobblerOwners[0]);
    }

    /// @dev Deposit goo with one Gobbler deposited
    function testLegendaryDepositGooWithGobblerDeposited() public {
        vm.startPrank(gobblerOwners[1]);

        gobblers.setApprovalForAll(address(superTank), true);
        superTank.depositGobbler(2, 0);

        goo.approve(address(superTank), type(uint256).max);

        superTank.deposit(100 ether, gobblerOwners[0]);

        assertEq(gobblers.ownerOf(1), gobblerOwners[0]);
        assertEq(gobblers.ownerOf(2), address(superTank));
        assertEq(gobblers.gooBalance(address(superTank)), 100 ether);
        assertEq(goo.balanceOf(address(superTank)), 0);
    }

    /// @dev Withdraw goo but no gobblers deposited
    function testLegendaryWithdrawGooButNoGobbler() public {
        testLegendaryFirstDepositWithoutGoo();
        superTank.deposit(100 ether, gobblerOwners[0]);

        uint256 userBalanceBefore = goo.balanceOf(gobblerOwners[0]);
        uint256 superTankBalanceBefore = gobblers.gooBalance(address(superTank));

        superTank.withdraw(50 ether, gobblerOwners[0], gobblerOwners[0]);

        assertEq(goo.balanceOf(gobblerOwners[0]), userBalanceBefore + 50 ether);
        assertEq(gobblers.gooBalance(address(superTank)), superTankBalanceBefore - 50 ether);
        assertEq(goo.balanceOf(address(superTank)), 0);
    }

    /// @dev Withdraw goo with one Gobbler deposited
    ///      TODO
    function testLegendaryWithdrawGooWithGobblerDeposited() public {
        vm.startPrank(gobblerOwners[0]);

        // Deposit a Gobbler and 100 Goo
        gobblers.setApprovalForAll(address(superTank), true);
        goo.approve(address(superTank), type(uint256).max);
        superTank.depositGobbler(1, 100 ether);

        uint256 gooOwnerBalanceBefore = goo.balanceOf(gobblerOwners[0]);
        uint256 gooSuperTankVirtualBalanceBefore = gobblers.gooBalance(address(superTank));
        
        assertEq(goo.balanceOf(address(superTank)), 0);

        // Withdraw goo
        superTank.withdraw(50 ether, gobblerOwners[0], gobblerOwners[0]);
        
        assertEq(goo.balanceOf(gobblerOwners[0]), gooOwnerBalanceBefore + 50 ether);
        assertEq(gobblers.gooBalance(address(superTank)), gooSuperTankVirtualBalanceBefore - 50 ether);
        assertEq(goo.balanceOf(address(superTank)), 0);
    }
    
    // Generate address with keccak
    function addr(string memory source) internal returns (address) {
        return address(uint160(uint256(keccak256(abi.encode(source)))));
    }
}
