// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {Auth, Authority} from "../libraries/Auth.sol";

import {FlywheelDynamicRewards} from "./FlywheelDynamicRewards.sol";
import {RewardsDepot} from "./RewardsDepot.sol";
import {FlywheelCore} from "../FlywheelCore.sol";
import {ERC20NT} from "../libraries/ERC20NT.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

/** 
 @title Flywheel Dynamic Reward Stream
 @notice Determines rewards based on a dynamic reward stream.
         Rewards are transferred linearly over a "rewards cycle" to prevent gaming the reward distribution. 
         The reward source can be arbitrary logic, but most common is to "pass through" rewards from some other source.
         The getNextCycleRewards() hook should also transfer the next cycle's rewards to this contract to ensure proper accounting.
*/
contract HermesDynamicRewards is FlywheelDynamicRewards, Auth {
    using SafeTransferLib for ERC20;
    using SafeCastLib for uint256;

    /// @notice RewardsDepot to collect rewards from
    RewardsDepot public rewardsDepot;

    constructor(
        FlywheelCore _flywheel,
        uint32 _rewardsCycleLength,
        Authority _authority,
        address _owner
    ) FlywheelDynamicRewards(_flywheel, _rewardsCycleLength) Auth(_owner, _authority) {}

    /**
     @notice get and transfer next week's rewards
     @param strategy the strategy to accrue rewards for
     @return amount the amount of tokens transferred
     */
    function getNextCycleRewards(ERC20NT strategy) internal override returns (uint192) {
        return uint192(rewardsDepot.getRewards(strategy));
    }

    /**
     @notice set new rewards depot
     @param _rewardsDepot the new rewards depot to set
     */
    function setRewardsDepot(RewardsDepot _rewardsDepot) external requiresAuth {
        rewardsDepot = _rewardsDepot;
    }
}
