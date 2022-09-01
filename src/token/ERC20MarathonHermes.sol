// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {Multicall} from "../../lib/ERC4626/src/external/Multicall.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";

import {FlywheelCore} from "../FlywheelCore.sol";

import {IFlywheelRewards} from "../interfaces/IFlywheelRewards.sol";
import {Auth, Authority} from "../libraries/Auth.sol";
import {ERC20NT} from "../libraries/ERC20NT.sol";

/**
@title Non Transfarable ERC20 to keep track of each week's Locked Hermes
@author Maia DAO
@notice Accrues rewards in before balance change, only when minting in this case. 
        Rewards need to be accrued either through here or flywheel and collected through the flywheel.
*/

contract ERC20MarathonHermes is ERC20NT, Auth {
    using FixedPointMathLib for uint256;

    /// @notice reward manager
    FlywheelCore public flywheel;

    constructor(
        Authority _authority,
        address _owner,
        FlywheelCore _flywheel
    ) ERC20NT("Marathon Hermes", "mHermes", 18) Auth(_owner, _authority) {
        flywheel = _flywheel;
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice simple re-entrancy check
    uint256 internal _unlocked = 1;
    modifier lock() {
        require(_unlocked == 1);
        _unlocked = 2;
        _;
        _unlocked = 1;
    }

    /*//////////////////////////////////////////////////////////////
                               REWARDS LOGIC
    //////////////////////////////////////////////////////////////*/

    /** 
      @notice accrue rewards for a single user
      @param user the user to be accrued
      @return the cumulative amount of rewards accrued to user (including prior)
    */
    function accrue(address user) external lock returns (uint256) {
        return _accrue(user);
    }

    /** 
      @notice accrue rewards for a single user
      @param user the user to be accrued
      @return the cumulative amount of rewards accrued to user (including prior)
    */
    function _accrue(address user) internal returns (uint256) {
        return flywheel.accrue(this, user);
    }

    /** 
      @notice accrue rewards for a two users
      @param user the first user to be accrued
      @param user the second user to be accrued
      @return the cumulative amount of rewards accrued to the first user (including prior)
      @return the cumulative amount of rewards accrued to the second user (including prior)
    */
    function accrue(address user, address secondUser) external returns (uint256, uint256) {
        return flywheel.accrue(this, user, secondUser);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     @notice accrues rewards and mints new amount to address.
     @param to address to receive.
     @param amount amount to mint.
    */
    function stake(address to, uint256 amount) external lock requiresAuth {
        _accrue(to);
        _mint(to, amount);
    }
}
