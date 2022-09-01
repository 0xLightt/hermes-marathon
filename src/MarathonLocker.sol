// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;
import {ERC20MarathonHermes} from "./token/ERC20MarathonHermes.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Auth, Authority} from "./libraries/Auth.sol";
import {HermesDynamicRewards, RewardsDepot} from "./rewards/HermesDynamicRewards.sol";
import {FlywheelCore} from "./FlywheelCore.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

interface ve {
    function create_lock_for(
        uint256 _value,
        uint256 _lock_duration,
        address _to
    ) external returns (uint256);

    function increase_amount(uint256 _tokenId, uint256 _value) external;

    function increase_unlock_time(uint256 _tokenId, uint256 _lock_duration) external;

    function locked__end(uint256 _tokenId) external view returns (uint256);
}

/**
@title Base Contract to keep track and distribute rewards to weekly new veHermes lockers
@author Maia DAO
@notice Each epoch mint's new Non Transfarable ERC20 every week to keep track of new lockers.
        Adds token as new strategy to flywheel core, flywheelRewards and rewardsDepot.
*/

contract MarathonLocker {
    using FixedPointMathLib for uint256;

    /// @notice reward Manager
    FlywheelCore public immutable flywheel;

    /// @notice reward Streamer
    HermesDynamicRewards public immutable flywheelRewards;

    /// @notice RewardsDepot
    RewardsDepot public immutable rewardsDepot;

    /// @notice underlying to lock
    ERC20 public immutable hermes;
    /// @notice locker to lock underlying
    address public immutable veHermes;

    uint256 internal immutable MAX_LOCK = 126144000;
    uint256 internal immutable WEEK = 1 weeks;

    /// @notice this epoch's start
    uint256 public epochStart;
    /// @notice this epoch's strategy to keep track of rewards
    ERC20MarathonHermes public currentStrategy;

    constructor(
        address _hermes,
        address _veHermes,
        ERC20 _rewardToken
    ) {
        hermes = ERC20(_hermes);
        veHermes = _veHermes;
        hermes.approve(veHermes, type(uint256).max);

        Authority authority = Authority(address(0));

        flywheel = new FlywheelCore(_rewardToken, HermesDynamicRewards(address(0)), address(this), authority);

        flywheelRewards = new HermesDynamicRewards(flywheel, uint32(WEEK), authority, address(this));

        flywheel.setFlywheelRewards(flywheelRewards);

        rewardsDepot = new RewardsDepot(_rewardToken, address(flywheelRewards), authority, address(this));

        flywheelRewards.setRewardsDepot(rewardsDepot);

        _newEpoch();
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
                                LOCK
    //////////////////////////////////////////////////////////////*/

    /** 
      @notice Deposit amount HERMES for msg.sender and lock for 4 years
      @param amount Amount to deposit
    */
    function createLock(uint256 amount) external lock {
        _newEpoch();

        hermes.transferFrom(msg.sender, address(this), amount);
        ve(veHermes).create_lock_for(amount, MAX_LOCK, msg.sender);

        currentStrategy.stake(msg.sender, amount);
    }

    /** 
      @notice Deposit amount HERMES for tokenId and increase unlock time for 4 years
      @param tokenId tokenId to deposit and increase unlock time
      @param amount Amount to deposit
    */
    function increaseTimeAndLock(uint256 tokenId, uint256 amount) external lock {
        _newEpoch();

        hermes.transferFrom(msg.sender, address(this), amount);
        ve(veHermes).increase_unlock_time(tokenId, MAX_LOCK);
        ve(veHermes).increase_amount(tokenId, amount);

        currentStrategy.stake(msg.sender, amount);
    }

    /** 
      @notice Deposit amount HERMES for tokenId
      @param tokenId tokenId to deposit
      @param amount Amount to deposit
    */
    function increaseLock(uint256 tokenId, uint256 amount) external lock {
        _newEpoch();

        uint256 _max = ((block.timestamp + MAX_LOCK) / WEEK) * WEEK;
        require(ve(veHermes).locked__end(tokenId) == _max, "Lock is too short");

        hermes.transferFrom(msg.sender, address(this), amount);
        ve(veHermes).increase_amount(tokenId, amount);

        currentStrategy.stake(msg.sender, amount);
    }

    /** 
      @notice if new epoch then start it and create new token to keep track of new weeks' lockers.
              add token as new strategy to flywheel core, flywheelRewards and rewardsDepot.
    */
    function _newEpoch() internal {
        uint256 _thisEpoch = (block.timestamp / WEEK) * WEEK;

        if (_thisEpoch > epochStart) {
            if (address(currentStrategy) != address(0)) currentStrategy.accrue(msg.sender);
            ERC20MarathonHermes _newStrategy = new ERC20MarathonHermes(Authority(address(0)), address(this), flywheel);
            currentStrategy = _newStrategy;
            rewardsDepot.setActiveStrategy(address(_newStrategy));
            flywheel.addStrategyForRewards(_newStrategy);
            rewardsDepot.setActiveStrategy(address(_newStrategy));

            epochStart = _thisEpoch;

            emit AddEpoch(address(_newStrategy), _thisEpoch);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /** 
      @notice Emitted when a new strategy is added to flywheel by the admin
      @param newFlywheel the new added strategy
      @param epochStart the epoch starting timestamp
    */
    event AddEpoch(address indexed newFlywheel, uint256 indexed epochStart);
}
