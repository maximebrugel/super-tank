// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {SuperTank} from "./SuperTank.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {ArtGobblers} from "art-gobblers/ArtGobblers.sol";

contract LegendarySuperTank is SuperTank {

    /* -------------------------------------------------------------------------- */
    /*                                   ERRORS                                   */
    /* -------------------------------------------------------------------------- */

    error NoGobblerDeposited();

    /* -------------------------------------------------------------------------- */
    /*                                   MEMORY                                   */
    /* -------------------------------------------------------------------------- */

    /// @notice Gobbler accounts balances (address => deposited Gobbler amount)
    mapping(address => uint256) public gobblerBalanceOf;


    /* -------------------------------------------------------------------------- */
    /*                                 CONSTRUCTOR                                */
    /* -------------------------------------------------------------------------- */

    constructor(
        ERC20 _goo,
        ArtGobblers _artGobblers,
        string memory _assetName,
        string memory _assetSymbol
    ) SuperTank(_goo, _artGobblers, _assetName, _assetSymbol) {}

    /* -------------------------------------------------------------------------- */
    /*                               GOBBLERS LOGIC                               */
    /* -------------------------------------------------------------------------- */

    /// @notice Allow a Gobbler owner to deposit the Gobbler in the SuperTank
    /// @param gobblerId The gobbler id to withdraw
    /// @param gooAmount The goo tokens to deposit
    function depositGobbler(uint256 gobblerId, uint256 gooAmount)
        public
        override 
    {
        unchecked{
            ++gobblerBalanceOf[msg.sender];
        }
        super.depositGobbler(gobblerId, gooAmount);
    }

    /// @notice Allow the depositor to withdraw his Gobbler
    /// @param gobblerId The gobbler id to withdraw
    function withdrawGobbler(uint256 gobblerId) public override {
        if(gobblerBalanceOf[msg.sender] > 0) {
            unchecked{
                --gobblerBalanceOf[msg.sender];
            }
        }
        super.withdrawGobbler(gobblerId);
    }

    /* -------------------------------------------------------------------------- */
    /*                                ERC4626 LOGIC                               */
    /* -------------------------------------------------------------------------- */

    function beforeDeposit(uint256 assets, address receiver) internal virtual override {
        if(gobblerBalanceOf[msg.sender] == 0) revert NoGobblerDeposited();
    }

    function afterWithdraw(
        uint256 assets,
        address receiver,
        address owner
    ) internal virtual override {}
}