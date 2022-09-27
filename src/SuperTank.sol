// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

import {ArtGobblers} from "art-gobblers/ArtGobblers.sol";

contract SuperTank is ERC4626, ReentrancyGuard {
    /* -------------------------------------------------------------------------- */
    /*                                   EVENTS                                   */
    /* -------------------------------------------------------------------------- */

    event GobblerDeposited(uint256 gobblerId);
    event GobblerWithdrawn(uint256 gobblerId);

    /* -------------------------------------------------------------------------- */
    /*                                   ERRORS                                   */
    /* -------------------------------------------------------------------------- */

    error NotDepositor(uint256 gobblerId);

    /* -------------------------------------------------------------------------- */
    /*                             CONSTANTS/IMMUTABLE                            */
    /* -------------------------------------------------------------------------- */

    /// @notice The ArtGobblers contract address
    ArtGobblers public immutable artGobblers;

    /* -------------------------------------------------------------------------- */
    /*                                   MEMORY                                   */
    /* -------------------------------------------------------------------------- */

    /// @notice Deposited gobblers (Gobbler ID => Depositor address)
    mapping(uint256 => address) public deposits;

    /// @notice Amount of gobblers deposited in SuperTank
    uint256 public gobblersInSuperTank;

    /* -------------------------------------------------------------------------- */
    /*                                 CONSTRUCTOR                                */
    /* -------------------------------------------------------------------------- */

    constructor(ERC20 _goo, ArtGobblers _artGobblers) ERC4626(_goo, "Goo SuperTank", "GooST") {
        artGobblers = _artGobblers;
    }

    /* -------------------------------------------------------------------------- */
    /*                               GOBBLERS LOGIC                               */
    /* -------------------------------------------------------------------------- */

    /// @notice Allow a Gobbler owner to deposit the Gobbler in the SuperTank
    /// @param gobblerId The gobbler id to withdraw
    function depositGobbler(uint256 gobblerId) external nonReentrant {
        // Transfer the gobbler from the depositor to the SuperTank
        artGobblers.transferFrom(msg.sender, address(this), gobblerId);

        uint256 gooBalance = asset.balanceOf(address(this)); // memory cache

        // If the user is depositing the first Gobbler and that
        // goo tokens are waiting (in the contract) to be deposited,
        // we are adding the tokens to the tank.
        if (gobblersInSuperTank == 0 && gooBalance != 0) {
            artGobblers.addGoo(gooBalance);
        }

        // Update state of deposits
        deposits[gobblerId] = msg.sender;

        // Update state of the counter
        unchecked {
            ++gobblersInSuperTank;
        }

        emit GobblerDeposited(gobblerId);
    }

    /// @notice Allow the depositor to withdraw his Gobbler
    /// @param gobblerId The gobbler id to withdraw
    function withdrawGobbler(uint256 gobblerId) external nonReentrant {
        // To withdraw the msg.sender must be the gobbler depositor
        if (deposits[gobblerId] != msg.sender) {
            revert NotDepositor(gobblerId);
        }

        // Update state of deposits
        delete deposits[gobblerId];

        // Update state of the counter
        unchecked {
            --gobblersInSuperTank;
        }

        // If the depositor is withdrawing the last gobbler
        // we must remove all the Goo tokens.
        if (gobblersInSuperTank == 0) {
            artGobblers.removeGoo(artGobblers.gooBalance(address(this)));
        }

        uint256 depositorShares = balanceOf[msg.sender]; // memory cache

        // Withdrawing all the remaining Goo tokens if the depositor has some shares
        if (depositorShares != 0) {
            redeem(depositorShares, msg.sender, msg.sender);
        }

        // Transfer back the gobbler to the depositor
        artGobblers.transferFrom(address(this), msg.sender, gobblerId);

        emit GobblerWithdrawn(gobblerId);
    }

    /* -------------------------------------------------------------------------- */
    /*                                ERC4626 LOGIC                               */
    /* -------------------------------------------------------------------------- */

    function beforeWithdraw(uint256 assets, uint256 shares) internal override {
        // Remove Goo from Tank if some Gobblers are deposited
        if (gobblersInSuperTank != 0) {
            artGobblers.removeGoo(assets);
        }
    }

    function afterDeposit(uint256 assets, uint256 shares) internal override {
        // Add Goo to tank if some Gobblers are deposited
        if (gobblersInSuperTank != 0) {
            artGobblers.addGoo(assets);
        }
    }

    function totalAssets() public view override returns (uint256) {
        // If 0 gobblers deposited, the totalAssets is the SuperTank balance
        if (gobblersInSuperTank == 0) {
            return asset.balanceOf(address(this));
        } else {
            return artGobblers.gooBalance(address(this));
        }
    }
}
