// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MockRewards} from "../mocks/MockRewards.sol";
import {FlywheelCore, IFlywheelRewards} from "../../FlywheelCore.sol";

import {FlywheelDynamicRewards, HermesDynamicRewards, RewardsDepot} from "../../rewards/HermesDynamicRewards.sol";

import {Auth, Authority} from "../../libraries/Auth.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";

import {ERC20MarathonHermes} from "../../token/ERC20MarathonHermes.sol";

contract ERC20MarathonHermesTest is DSTestPlus {
    using SafeCastLib for uint256;

    ERC20MarathonHermes marathonHermes;

    FlywheelCore flywheel;
    MockRewards rewards;

    MockERC20 public rewardToken;
    RewardsDepot public depot;
    Authority public authority;

    address constant user = address(0xDEAD);
    address constant user2 = address(0xBEEF);

    function setUp() public {
        rewardToken = new MockERC20("test token", "TKN", 18);

        authority = new Authority();

        flywheel = new FlywheelCore(rewardToken, MockRewards(address(0)), address(this), authority);

        marathonHermes = new ERC20MarathonHermes(authority, address(this), flywheel);

        rewards = new MockRewards(flywheel);

        flywheel.setFlywheelRewards(rewards);
    }

    function testStake(address to, uint256 stakeAmount) public {
        uint256 marathonHermesBal = marathonHermes.balanceOf(to);

        marathonHermes.stake(to, stakeAmount);

        require(marathonHermes.balanceOf(to) - marathonHermesBal == stakeAmount);
    }

    function testStakeFail(address to, uint256 stakeAmount) public {
        hevm.assume(to != address(this));
        hevm.prank(to);
        hevm.expectRevert(bytes("UNAUTHORIZED"));
        marathonHermes.stake(to, stakeAmount);
    }

    function testAccrue(
        uint128 userBalance1,
        uint128 userBalance2,
        uint128 rewardAmount
    ) public {
        hevm.assume(userBalance1 != 0 && userBalance2 != 0 && rewardAmount != 0);

        testStake(user, userBalance1);
        testStake(user2, userBalance2);

        rewardToken.mint(address(rewards), rewardAmount);
        rewards.setRewardsAmount(marathonHermes, rewardAmount);

        flywheel.addStrategyForRewards(marathonHermes);

        uint256 accrued = marathonHermes.accrue(user);

        (uint224 index, ) = flywheel.strategyState(marathonHermes);

        uint256 diff = (rewardAmount * flywheel.ONE()) / (uint256(userBalance1) + userBalance2);

        require(index == flywheel.ONE() + diff);
        require(flywheel.userIndex(marathonHermes, user) == index);
        require(flywheel.rewardsAccrued(user) == (diff * userBalance1) / flywheel.ONE());
        require(accrued == (diff * userBalance1) / flywheel.ONE());
        require(flywheel.rewardsAccrued(user2) == 0 ether);

        require(rewardToken.balanceOf(address(rewards)) == rewardAmount);
    }

    function testAccrueTwoUsers(
        uint128 userBalance1,
        uint128 userBalance2,
        uint128 rewardAmount
    ) public {
        hevm.assume(userBalance1 != 0 && userBalance2 != 0 && rewardAmount != 0);

        testStake(user, userBalance1);
        testStake(user2, userBalance2);

        rewardToken.mint(address(rewards), rewardAmount);
        rewards.setRewardsAmount(marathonHermes, rewardAmount);

        flywheel.addStrategyForRewards(marathonHermes);

        (uint256 accrued1, uint256 accrued2) = marathonHermes.accrue(user, user2);

        (uint224 index, ) = flywheel.strategyState(marathonHermes);

        uint256 diff = (rewardAmount * flywheel.ONE()) / (uint256(userBalance1) + userBalance2);

        require(index == flywheel.ONE() + diff);
        require(flywheel.userIndex(marathonHermes, user) == index);
        require(flywheel.userIndex(marathonHermes, user2) == index);
        require(flywheel.rewardsAccrued(user) == (diff * userBalance1) / flywheel.ONE());
        require(flywheel.rewardsAccrued(user2) == (diff * userBalance2) / flywheel.ONE());
        require(accrued1 == (diff * userBalance1) / flywheel.ONE());
        require(accrued2 == (diff * userBalance2) / flywheel.ONE());

        require(rewardToken.balanceOf(address(rewards)) == rewardAmount);
    }

    function testAccrueBeforeAddStrategy(uint128 mintAmount, uint128 rewardAmount) public {
        testStake(user, mintAmount);

        rewardToken.mint(address(rewards), rewardAmount);
        rewards.setRewardsAmount(marathonHermes, rewardAmount);

        require(marathonHermes.accrue(user) == 0);
    }

    function testAccrueTwoUsersBeforeAddStrategy() public {
        testStake(user, 1 ether);
        testStake(user2, 3 ether);

        rewardToken.mint(address(rewards), 10 ether);
        rewards.setRewardsAmount(marathonHermes, 10 ether);

        (uint256 accrued1, uint256 accrued2) = marathonHermes.accrue(user, user2);

        require(accrued1 == 0);
        require(accrued2 == 0);
    }

    function testAccrueTwoUsersSeparately() public {
        testStake(user, 1 ether);
        testStake(user2, 3 ether);

        rewardToken.mint(address(rewards), 10 ether);
        rewards.setRewardsAmount(marathonHermes, 10 ether);

        flywheel.addStrategyForRewards(marathonHermes);

        uint256 accrued = marathonHermes.accrue(user);

        rewards.setRewardsAmount(marathonHermes, 0);

        uint256 accrued2 = marathonHermes.accrue(user2);

        (uint224 index, ) = flywheel.strategyState(marathonHermes);

        require(index == flywheel.ONE() + 2.5 ether);
        require(flywheel.userIndex(marathonHermes, user) == index);
        require(flywheel.rewardsAccrued(user) == 2.5 ether);
        require(flywheel.rewardsAccrued(user2) == 7.5 ether);
        require(accrued == 2.5 ether);
        require(accrued2 == 7.5 ether);

        require(rewardToken.balanceOf(address(rewards)) == 10 ether);
    }

    function testAccrueSecondUserLater() public {
        marathonHermes.stake(user, 1 ether);

        rewardToken.mint(address(rewards), 10 ether);
        rewards.setRewardsAmount(marathonHermes, 10 ether);

        flywheel.addStrategyForRewards(marathonHermes);

        (uint256 accrued, uint256 accrued2) = marathonHermes.accrue(user, user2);

        (uint224 index, ) = flywheel.strategyState(marathonHermes);

        require(index == flywheel.ONE() + 10 ether);
        require(flywheel.userIndex(marathonHermes, user) == index);
        require(flywheel.rewardsAccrued(user) == 10 ether);
        require(flywheel.rewardsAccrued(user2) == 0);
        require(accrued == 10 ether);
        require(accrued2 == 0);

        require(rewardToken.balanceOf(address(rewards)) == 10 ether);

        rewards.setRewardsAmount(marathonHermes, 0 ether);
        marathonHermes.stake(user2, 3 ether);

        rewardToken.mint(address(rewards), 4 ether);
        rewards.setRewardsAmount(marathonHermes, 4 ether);

        (accrued, accrued2) = marathonHermes.accrue(user, user2);

        (index, ) = flywheel.strategyState(marathonHermes);

        require(index == flywheel.ONE() + 11 ether);
        require(flywheel.userIndex(marathonHermes, user) == index);
        require(flywheel.rewardsAccrued(user) == 11 ether);
        require(flywheel.rewardsAccrued(user2) == 3 ether);
        require(accrued == 11 ether);
        require(accrued2 == 3 ether);

        require(rewardToken.balanceOf(address(rewards)) == 14 ether);
    }
}
