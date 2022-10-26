// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ERC20MarathonHermes, FlywheelCore, ERC20NT} from "./token/ERC20MarathonHermes.sol";
import {MarathonLocker} from "./MarathonLocker.sol";
import {Encoding} from "./libraries/Encoding.sol";

contract ClaimHelper {
    FlywheelCore private immutable flywheel;
    MarathonLocker private immutable marathonLocker;
    mapping(uint256 => ERC20MarathonHermes) private marathonHermesPerEpoch;

    uint256 internal immutable WEEK = 1 weeks;

    /// @notice this epoch's start
    uint256 public epochStart;
    /// @notice current epoch
    uint256 public currentEpoch;

    constructor(FlywheelCore _flywheel, MarathonLocker _marathonLocker) {
        flywheel = _flywheel;
        marathonLocker = _marathonLocker;
        _newEpoch();
    }

    fallback() external {
        uint256[] memory epochs = abi.decode(Encoding.decodeCallData(msg.data, currentEpoch), (uint256[]));
        _accrueAndClaimRewards(epochs);
    }

    /// @notice accrue and claim outstanding rewards for msg.sender
    function accrueAndClaimRewards(uint256[] memory epochs) external {
        _accrueAndClaimRewards(epochs);
    }

    /// @notice accrue and claim outstanding rewards for msg.sender
    function _accrueAndClaimRewards(uint256[] memory epochs) internal {
        _newEpoch();

        address user = msg.sender;
        uint256 length = epochs.length;
        for (uint256 i = 0; i < length; ) {
            flywheel.accrue(marathonHermesPerEpoch[epochs[i]], user);
            unchecked {
                i++;
            }
        }
        flywheel.claimRewards(user);
    }

    /** 
      @notice if new epoch then start it and create new token to keep track of new weeks' lockers.
              add token as new strategy to flywheel core, flywheelRewards and rewardsDepot.
    */
    function _newEpoch() internal {
        uint256 _thisEpoch = (block.timestamp / WEEK) * WEEK;

        if (_thisEpoch > epochStart) {
            marathonHermesPerEpoch[currentEpoch] = marathonLocker.currentStrategy();

            epochStart = _thisEpoch;

            unchecked {
                currentEpoch++;
            }
        }
    }
}
