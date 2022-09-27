// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";


import {ArtGobblers} from "art-gobblers/ArtGobblers.sol";

contract SuperTank is ERC4626, ReentrancyGuard {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

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

    /// @notice Fees sent to the Gobblers depositors
    /// Must be between 0 and 100
    uint256 public immutable performanceFees;

    /// @notice Address receiving the performance fees
    address public immutable feesRecipient;

    /* -------------------------------------------------------------------------- */
    /*                                   MEMORY                                   */
    /* -------------------------------------------------------------------------- */

    /// @notice Deposited gobblers (Gobbler ID => Depositor address)
    mapping(uint256 => address) public deposits;

    /// @notice Amount of gobblers deposited in SuperTank
    uint256 public gobblersInSuperTank;

    /// @notice Amount deposited by goo holders (user address => amount)
    mapping(address => uint256) public amountDeposited;

    /* -------------------------------------------------------------------------- */
    /*                                 CONSTRUCTOR                                */
    /* -------------------------------------------------------------------------- */

    constructor(ERC20 _goo, ArtGobblers _artGobblers, uint256 _performanceFees, address _feesRecipient)
        ERC4626(_goo, "Goo SuperTank", "GooST")
    {
        require(_performanceFees < 100 && _performanceFees != 0, "Invalid amount");
        artGobblers = _artGobblers;
        performanceFees = _performanceFees;
        feesRecipient = _feesRecipient;
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

        // Transfer back the gobbler to the depositor
        artGobblers.transferFrom(address(this), msg.sender, gobblerId);

        emit GobblerWithdrawn(gobblerId);
    }

    /* -------------------------------------------------------------------------- */
    /*                                ERC4626 LOGIC                               */
    /* -------------------------------------------------------------------------- */

    /// @notice Withdraw and send performance fees
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256 shares) {
        shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.

        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        beforeWithdraw(assets, shares);

        // Must be computed before burning shares
        (uint256 fees, uint256 performance) = getAmounts(assets);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        amountDeposited[msg.sender] -= (assets - performance);

        asset.safeTransfer(receiver, assets - fees);
        asset.safeTransfer(feesRecipient, fees);
    }

    /// @notice Redeem and send performance fees
    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        // Check for rounding error since we round down in previewRedeem.
        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

        beforeWithdraw(assets, shares);

        // Must be computed before burning shares
        (uint256 fees, uint256 performance) = getAmounts(assets);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        amountDeposited[msg.sender] -= (assets - performance);

        asset.safeTransfer(receiver, assets - fees);
        asset.safeTransfer(feesRecipient, fees);
    }

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
        amountDeposited[msg.sender] += assets;
    }

    function totalAssets() public view override returns (uint256) {
        // If 0 gobblers deposited, the totalAssets is the SuperTank balance
        if (gobblersInSuperTank == 0) {
            return asset.balanceOf(address(this));
        } else {
            return artGobblers.gooBalance(address(this));
        }
    }

    /// @notice Compute fees and performance amounts
    /// @param assets Amount of assets
    /// @return fees Amount of fees sent to Gobbler depositors
    /// @return performance Amount of performance based on the initial deposit (fees included)
    function getAmounts(uint256 assets) public view returns (uint256 fees, uint256 performance) {
        uint256 deposited = amountDeposited[msg.sender];
        uint256 total = previewRedeem(balanceOf[msg.sender]);
        require(assets <= total, "total overflow");

        if (total > deposited) {
            performance = assets - (assets.mulDivDown(deposited, total));
            fees = performance.mulDivDown(performanceFees, 100);
        } else {
            fees = 0;
            performance = 0;
        }
    }
}
