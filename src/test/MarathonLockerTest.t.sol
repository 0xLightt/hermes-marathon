// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MarathonLocker} from "../MarathonLocker.sol";
import {FlywheelCore} from "../FlywheelCore.sol";

import {HermesDynamicRewards, RewardsDepot} from "../rewards/HermesDynamicRewards.sol";

import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";

import {ERC20MarathonHermes} from "../token/ERC20MarathonHermes.sol";

import {ve} from "./mocks/ve.sol";

contract MarathonLockerTest is DSTestPlus {
    using SafeCastLib for uint256;

    MarathonLocker marathonLocker;

    ve veHermes;

    MockERC20 public rewardToken;
    MockERC20 public hermes;

    uint256 internal immutable MAX_LOCK = 126144000;
    uint256 internal immutable WEEK = 1 weeks;

    function setUp() public {
        rewardToken = new MockERC20("test token", "TKN", 18);
        hermes = new MockERC20("hermes", "HERMES", 18);

        veHermes = new ve(address(hermes));

        hevm.warp(604800); // initial timestamp needs to be equal or greater than 1 weeks

        marathonLocker = new MarathonLocker(address(hermes), address(veHermes), rewardToken);
    }

    function testCreateLock(address to, uint256 amount) public returns (uint256 tokenId) {
        hevm.assume(to > address(0) && amount > 0 && amount < type(uint64).max); // type(uint64).max == type(int128).max

        ERC20MarathonHermes marathonHermes = marathonLocker.currentStrategy();
        uint256 initBal = marathonHermes.balanceOf(to);
        uint256 numTokens = veHermes.balanceOf(to);

        hermes.mint(to, amount);
        hevm.prank(to);
        hermes.approve(address(marathonLocker), amount);
        hevm.prank(to);
        marathonLocker.createLock(amount);

        uint256 max = ((block.timestamp + MAX_LOCK) / WEEK) * WEEK;
        uint256[] memory newTokens = veHermes.tokensOfOwner(to);
        uint256 len = newTokens.length - 1;
        tokenId = newTokens[len];
        require(len == numTokens);
        require(numTokens + 1 == veHermes.balanceOf(to));
        require(veHermes.locked__end(tokenId) == max);
        (int128 lockedAmount, uint256 end) = veHermes.locked(tokenId);
        require(end == max);
        require(lockedAmount == int256(amount));

        ERC20MarathonHermes newMarathonHermes = marathonLocker.currentStrategy();
        uint256 endBalOld = marathonHermes.balanceOf(to);
        uint256 endBalNew = newMarathonHermes.balanceOf(to);
        uint256 endBal = newMarathonHermes == marathonHermes ? endBalOld : endBalOld + endBalNew;
        require(initBal == endBal - amount);
    }

    function testIncreaseLock(address to, uint256 amount) public returns (uint256 tokenId) {
        hevm.assume(to > address(0) && amount > 0 && amount < type(uint64).max); // type(uint64).max == type(int128).max

        tokenId = testCreateLock(to, amount);
        ERC20MarathonHermes marathonHermes = marathonLocker.currentStrategy();
        uint256 initBal = marathonHermes.balanceOf(to);
        uint256 numTokens = veHermes.balanceOf(to);

        hermes.mint(to, amount);
        hevm.prank(to);
        hermes.approve(address(marathonLocker), amount);
        hevm.prank(to);
        veHermes.approve(address(marathonLocker), tokenId);
        hevm.prank(to);
        marathonLocker.increaseLock(tokenId, amount);

        uint256 max = ((block.timestamp + MAX_LOCK) / WEEK) * WEEK;
        require(numTokens == veHermes.balanceOf(to));
        require(veHermes.locked__end(tokenId) == max);
        (int128 lockedAmount, uint256 end) = veHermes.locked(tokenId);
        require(end == max);
        require(lockedAmount == int256(amount) * 2);

        ERC20MarathonHermes newMarathonHermes = marathonLocker.currentStrategy();
        uint256 endBalOld = marathonHermes.balanceOf(to);
        uint256 endBalNew = newMarathonHermes.balanceOf(to);
        uint256 endBal = newMarathonHermes == marathonHermes ? endBalOld : endBalOld + endBalNew;
        require(initBal == endBal - amount);
    }

    function testIncreaseLockFail(address to, uint256 amount) public returns (uint256 tokenId) {
        hevm.assume(to > address(0) && amount > 0 && amount < type(uint64).max); // type(uint64).max == type(int128).max

        hermes.mint(to, amount);
        hevm.prank(to);
        hermes.approve(address(veHermes), amount);
        hevm.prank(to);
        tokenId = veHermes.create_lock_for(amount, MAX_LOCK / 2, to);

        ERC20MarathonHermes marathonHermes = marathonLocker.currentStrategy();
        uint256 initBal = marathonHermes.balanceOf(to);
        uint256 numTokens = veHermes.balanceOf(to);

        hermes.mint(to, amount);
        hevm.prank(to);
        hermes.approve(address(marathonLocker), amount);
        hevm.prank(to);
        veHermes.approve(address(marathonLocker), tokenId);
        hevm.prank(to);
        hevm.expectRevert(bytes("Lock is too short"));
        marathonLocker.increaseLock(tokenId, amount);

        uint256 time = ((block.timestamp + MAX_LOCK / 2) / WEEK) * WEEK;
        uint256 newNumTokens = veHermes.balanceOf(to);
        (, uint256 end) = veHermes.locked(tokenId);
        uint256 endBal = marathonHermes.balanceOf(to);

        require(numTokens == newNumTokens);
        require(end == time);
        require(initBal == endBal);
    }

    function testIncreaseTimeAndLock(address to, uint256 amount) public returns (uint256 tokenId) {
        hevm.assume(to > address(0) && amount > 0 && amount < type(uint64).max); // type(uint64).max == type(int128).max

        hermes.mint(to, amount);
        hevm.prank(to);
        hermes.approve(address(veHermes), amount);
        hevm.prank(to);
        tokenId = veHermes.create_lock_for(amount, MAX_LOCK / 2, to);

        ERC20MarathonHermes marathonHermes = marathonLocker.currentStrategy();
        uint256 initBal = marathonHermes.balanceOf(to);
        uint256 numTokens = veHermes.balanceOf(to);

        hermes.mint(to, amount);
        hevm.prank(to);
        hermes.approve(address(marathonLocker), amount);
        hevm.prank(to);
        veHermes.approve(address(marathonLocker), tokenId);
        hevm.prank(to);
        marathonLocker.increaseTimeAndLock(tokenId, amount);

        uint256 max = ((block.timestamp + MAX_LOCK) / WEEK) * WEEK;
        require(numTokens == veHermes.balanceOf(to));
        require(veHermes.locked__end(tokenId) == max);
        (int128 lockedAmount, uint256 end) = veHermes.locked(tokenId);
        require(end == max);
        require(lockedAmount == int256(amount) * 2);

        ERC20MarathonHermes newMarathonHermes = marathonLocker.currentStrategy();
        uint256 endBalOld = marathonHermes.balanceOf(to);
        uint256 endBalNew = newMarathonHermes.balanceOf(to);
        uint256 endBal = newMarathonHermes == marathonHermes ? endBalOld : endBalOld + endBalNew;
        require(initBal == endBal - amount);
    }

    function testCreateInNewEpoch(address to, uint256 amount) public {
        hevm.assume(to > address(0) && amount > 0 && amount < type(uint64).max); // type(uint64).max == type(int128).max

        hevm.warp(1209600); // epoch 2

        testCreateLock(to, amount);
    }

    function testLiveExample(
        address user0,
        address user1,
        address user2,
        uint256 amount0,
        uint256 amount1,
        uint256 amount2,
        uint256 rewardAmount
    ) public {
        hevm.assume(user0 != user1 && user1 != user2 && user0 != user2);
        hevm.assume(amount0 > 0 && amount0 < type(uint64).max); // type(uint64).max == type(int128).max
        hevm.assume(amount1 > 0 && amount1 < type(uint64).max); // type(uint64).max == type(int128).max
        hevm.assume(amount2 > 0 && amount2 < type(uint64).max); // type(uint64).max == type(int128).max
        hevm.assume(rewardAmount > 100000 && rewardAmount < type(uint128).max);

        require(marathonLocker.currentStrategy().totalSupply() == 0);

        testCreateLock(user0, amount0);

        rewardToken.mint(address(marathonLocker.rewardsDepot()), rewardAmount);
        ERC20MarathonHermes marathonHermes0 = marathonLocker.currentStrategy();
        hevm.warp(1209600); // epoch 2

        require(marathonHermes0.totalSupply() == amount0);
        require(rewardToken.balanceOf(address(marathonLocker.rewardsDepot())) == rewardAmount);
        testCreateLock(user1, amount1);
        testIncreaseTimeAndLock(user0, amount0);
        require(marathonHermes0.totalSupply() == amount0);
        require(marathonLocker.currentStrategy().totalSupply() == amount0 + amount1);

        require(rewardToken.balanceOf(address(marathonLocker.rewardsDepot())) == 0);
        require(rewardToken.balanceOf(address(marathonLocker.flywheelRewards())) == rewardAmount);

        {
            FlywheelCore flywheel = marathonLocker.flywheel();
            (uint224 index, ) = flywheel.strategyState(marathonHermes0);
            require(flywheel.userIndex(marathonHermes0, user0) == index);
            require(flywheel.rewardsAccrued(user0) == 0 ether);
            require(flywheel.rewardsAccrued(user1) == 0 ether);
            require(flywheel.rewardsAccrued(user2) == 0 ether);
        }

        rewardToken.mint(address(marathonLocker.rewardsDepot()), rewardAmount);
        ERC20MarathonHermes marathonHermes1 = marathonLocker.currentStrategy();
        require(marathonHermes1 != marathonHermes0);
        hevm.warp(1814400); // epoch 3

        {
            uint256 accrued = marathonHermes0.accrue(user0);
            FlywheelCore flywheel = marathonLocker.flywheel();
            (uint224 index, ) = flywheel.strategyState(marathonHermes0);
            require(flywheel.userIndex(marathonHermes0, user0) == index);
            uint256 diff = (rewardAmount * flywheel.ONE()) / amount0;
            require(index == flywheel.ONE() + diff);
            require(flywheel.rewardsAccrued(user0) == (diff * amount0) / flywheel.ONE());
            require(accrued == (diff * amount0) / flywheel.ONE());
            require(flywheel.rewardsAccrued(user0) == accrued);
            require(flywheel.rewardsAccrued(user1) == 0 ether);
            require(flywheel.rewardsAccrued(user2) == 0 ether);
            require(accrued > rewardAmount - (rewardAmount / 10000) && accrued < rewardAmount + (rewardAmount / 10000)); // Accept 0.001% error
        }

        {
            FlywheelCore flywheel = marathonLocker.flywheel();
            (uint224 _index, ) = flywheel.strategyState(marathonHermes1);
            require(flywheel.userIndex(marathonHermes1, user0) == _index);
        }
        testIncreaseLock(user2, amount2);
        require(marathonLocker.currentStrategy().balanceOf(user2) == amount2 * 2);
        require(marathonHermes1 != marathonLocker.currentStrategy());

        hevm.warp(2419200); // epoch 4

        marathonHermes1.accrue(user0, user1);
        require(rewardToken.balanceOf(address(marathonLocker.flywheelRewards())) == rewardAmount * 2);

        {
            FlywheelCore flywheel = marathonLocker.flywheel();
            require(flywheel.rewardsAccrued(user2) == 0 ether);
            (uint224 index, ) = flywheel.strategyState(marathonHermes1);

            require(flywheel.userIndex(marathonHermes1, user0) == index);
            require(flywheel.userIndex(marathonHermes1, user1) == index);

            uint256 diff = (rewardAmount * flywheel.ONE()) / (amount0 + amount1);

            require(index == flywheel.ONE() + diff);

            uint256 accrued1 = marathonHermes1.accrue(user1);
            require(flywheel.rewardsAccrued(user1) == (diff * amount1) / flywheel.ONE());
            require(accrued1 == (diff * amount1) / flywheel.ONE());

            uint256 accrued0 = marathonHermes1.accrue(user0);

            require(
                accrued0 > rewardAmount - (rewardAmount / 10000) + (diff * amount0) / flywheel.ONE() ||
                    accrued0 < rewardAmount + (rewardAmount / 10000) + (diff * amount0) / flywheel.ONE()
            ); // Accept 0.001% error
            require(accrued0 == flywheel.rewardsAccrued(user0));
        }
    }
}
