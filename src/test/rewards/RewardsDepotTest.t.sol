// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MockERC20NT} from "../mocks/MockERC20NT.sol";

import {RewardsDepot} from "../../rewards/HermesDynamicRewards.sol";

import {Auth, Authority} from "../../libraries/Auth.sol";

contract RewardsDepotTest is DSTestPlus {
    MockERC20NT strategy;
    MockERC20 public rewardToken;
    RewardsDepot public depot;

    Authority public authority;

    function setUp() public {
        rewardToken = new MockERC20("test token", "TKN", 18);
        strategy = new MockERC20NT("strategy", "STRAT", 18);

        authority = new Authority();

        depot = new RewardsDepot(rewardToken, address(this), authority, address(this));

        depot.setActiveStrategy(address(strategy));
    }

    function testGetRewards(uint256 amount) public {
        rewardToken.mint(address(depot), amount);

        depot.getRewards(strategy);

        require(rewardToken.balanceOf(address(this)) == amount);
    }

    function testGetRewardsNoAvailable() public {
        depot.getRewards(strategy);

        require(rewardToken.balanceOf(address(this)) == 0);
    }

    function testGetRewardsNotAllowed(uint256 amount) public {
        rewardToken.mint(address(depot), amount);

        hevm.prank(address(1));
        hevm.expectRevert(bytes("UNAUTHORIZED"));
        depot.getRewards(strategy);

        require(rewardToken.balanceOf(address(this)) == 0);
        require(rewardToken.balanceOf(address(depot)) == amount);
    }

    function testGetRewardsTwice(uint256 amount) public {
        hevm.assume(amount > 0 && amount < type(uint128).max);

        rewardToken.mint(address(depot), amount);

        depot.getRewards(strategy);

        require(rewardToken.balanceOf(address(this)) == amount);

        rewardToken.mint(address(depot), amount);

        depot.getRewards(strategy);

        require(rewardToken.balanceOf(address(this)) == amount * 2);
    }

    function testGetRewardsTwiceFirstHasNothing(uint256 amount) public {
        depot.getRewards(strategy);

        require(rewardToken.balanceOf(address(this)) == 0 ether);

        rewardToken.mint(address(depot), amount);

        depot.getRewards(strategy);

        require(rewardToken.balanceOf(address(this)) == amount);
    }

    function testGetRewardsDifferentStrategy(uint256 amount) public {
        rewardToken.mint(address(depot), amount);

        depot.getRewards(MockERC20NT(address(0)));

        require(rewardToken.balanceOf(address(this)) == 0 ether);
    }
}
