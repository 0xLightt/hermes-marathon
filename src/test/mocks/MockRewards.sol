// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import "../../rewards/BaseFlywheelRewards.sol";
import {ERC20NT} from "../../libraries/ERC20NT.sol";
import {RewardsDepot} from "../../rewards/RewardsDepot.sol";

contract MockRewards is BaseFlywheelRewards {
    /// @notice rewards amount per strategy
    mapping(ERC20NT => uint256) public rewardsAmount;

    /// @notice RewardsDepot
    RewardsDepot public rewardsDepot;

    constructor(FlywheelCore _flywheel) BaseFlywheelRewards(_flywheel) {}

    function setRewardsAmount(ERC20NT strategy, uint256 amount) external {
        rewardsAmount[strategy] = amount;
    }

    function getAccruedRewards(ERC20NT strategy, uint32) external view override onlyFlywheel returns (uint256 amount) {
        return rewardsAmount[strategy];
    }
}
