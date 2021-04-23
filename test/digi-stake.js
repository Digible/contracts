const { expectRevert, expectEvent, BN, time } = require('@openzeppelin/test-helpers');
const truffleAssert = require('truffle-assertions');

const DigiStake = artifacts.require("DigiStake");
const DigiToken = artifacts.require("DigiToken");
const StableToken = artifacts.require("StableToken");

contract('DigiStake', function (accounts) {

  beforeEach(async function () {
    // Deploy
    this.digiToken = await DigiToken.new({ from: accounts[0] });
    await this.digiToken.release({ from: accounts[0] });
    this.stableToken = await StableToken.new({ from: accounts[0] });

    this.digiStake = await DigiStake.new(
      this.digiToken.address,
      this.stableToken.address,
      { from: accounts[0] }
    );

    // Transfer
    const digiAmount = '10000000000000000000'; // 100.00
    await this.digiToken.transfer(
      accounts[1],
      digiAmount,
      { from: accounts[0] }
    );
    await this.digiToken.transfer(
      accounts[2],
      digiAmount,
      { from: accounts[0] }
    );

    this.rewardsAmount = '100000000000000000000'; // 1000.00
    await this.stableToken.transfer(
      this.digiStake.address,
      this.rewardsAmount,
      { from: accounts[0] }
    );

    // Permissions
    await this.digiToken.approve(
      this.digiStake.address,
      digiAmount,
      { from: accounts[1] }
    );
    await this.digiToken.approve(
      this.digiStake.address,
      digiAmount,
      { from: accounts[2] }
    );

  });

  describe('Stake', function () {
    
    it('on stake', async function() {
      const digiAmount = '1000000000000000000'; // 10.00
      await this.digiStake.stake(
        digiAmount,
        { from: accounts[1] }
      );

      const stake = await this.digiStake.stakeMap.call(accounts[1]).valueOf();
      assert.equal(
        stake,
        digiAmount,
        'stake value is not correct'
      );
    });

    it('claim', async function() {
      const digiAmount = '1000000000000000000'; // 10.00
      await this.digiStake.stake(
        digiAmount,
        { from: accounts[1] }
      );

      await this.digiStake.distribute();

      await this.digiStake.claim(
        { from: accounts[1] }
      );

      const stableBalanceAfterWithdraw = await this.stableToken.balanceOf(accounts[1]);
      assert.equal(
        stableBalanceAfterWithdraw.toString(),
        this.rewardsAmount,
        'Rewards not received'
      );

      const stake = await this.digiStake.stakeMap.call(accounts[1]).valueOf();
      assert.equal(
        stake.toString(),
        digiAmount.toString(),
        'stake value is not correct'
      );
    });

    it('staked', async function() {
      const digiAmount = '1000000000000000000'; // 10.00
      await this.digiStake.stake(
        digiAmount,
        { from: accounts[1] }
      );

      const staked = await this.digiStake.staked.call(
        accounts[1],
        { from: accounts[1] }
      );

      const stake = await this.digiStake.stakeMap.call(accounts[1]).valueOf();
      assert.equal(
        stake.toString(),
        staked.toString(),
        'stake value is not correct'
      );
    });
  
  });

  describe('Unstake', function () {
    
    it('on withdraw', async function() {
      const digiBalanceBeforeWithdraw = await this.digiToken.balanceOf(accounts[1]);

      const digiAmount = '1000000000000000000'; // 10.00
      await this.digiStake.stake(
        digiAmount,
        { from: accounts[1] }
      );

      await this.digiStake.withdraw(
        { from: accounts[1] }
      );

      const digiBalanceAfterWithdraw = await this.digiToken.balanceOf(accounts[1]);
      assert.equal(
        digiBalanceAfterWithdraw.toString(),
        digiBalanceBeforeWithdraw,
        'Stake not recovered'
      );

      const stableBalanceAfterWithdraw = await this.stableToken.balanceOf(accounts[1]);
      assert.equal(
        stableBalanceAfterWithdraw.toString(),
        '100000000000000000000',
        'Rewards not received'
      );

      const stake = await this.digiStake.stakeMap.call(accounts[1]).valueOf();
      assert.equal(
        stake.toString(),
        0,
        'stake value is not correct'
      );
    });

    it('gets rewards', async function() {
      const digiAmount = '1000000000000000000'; // 10.00
      await this.digiStake.stake(
        digiAmount,
        { from: accounts[1] }
      );

      await this.digiStake.distribute();

      await this.digiStake.withdraw(
        { from: accounts[1] }
      );

      const stableBalanceAfterWithdraw = await this.stableToken.balanceOf(accounts[1]);
      assert.equal(
        stableBalanceAfterWithdraw.toString(),
        this.rewardsAmount,
        'Rewards not received'
      );

      const stake = await this.digiStake.stakeMap.call(accounts[1]).valueOf();
      assert.equal(
        stake,
        0,
        'stake value is not correct'
      );
    });

    it('gets rewards and re-stake', async function() {
      const digiAmount = '1000000000000000000'; // 10.00
      await this.digiStake.stake(
        digiAmount,
        { from: accounts[1] }
      );
      await this.digiStake.stake(
        digiAmount,
        { from: accounts[2] }
      );

      await this.digiStake.distribute();

      await this.digiStake.withdraw(
        { from: accounts[1] }
      );

      await this.digiStake.stake(
        digiAmount,
        { from: accounts[1] }
      );


      const rewards = await this.digiStake.calculateReward.call(accounts[1], { from: accounts[1] });
      assert.equal(
        rewards.toString(),
        '0',
        'Rewards for Account 1 not correct'
      );
    });

    it('gets rewards when two equal deposits', async function() {
      const digiAmount = '1000000000000000000'; // 10.00
      await this.digiStake.stake(
        digiAmount,
        { from: accounts[1] }
      );
      await this.digiStake.stake(
        digiAmount,
        { from: accounts[2] }
      );

      await this.digiStake.distribute();

      await this.digiStake.withdraw(
        { from: accounts[1] }
      );
      await this.digiStake.withdraw(
        { from: accounts[2] }
      );

      const stableBalanceOneAfterWithdraw = await this.stableToken.balanceOf(accounts[1]);
      const stableBalanceTwoAfterWithdraw = await this.stableToken.balanceOf(accounts[2]);
      
      assert.equal(
        stableBalanceOneAfterWithdraw.toString(),
        sumStrings(0, this.rewardsAmount / 2),
        'Rewards for Account 1 not correct'
      );

      assert.equal(
        stableBalanceTwoAfterWithdraw.toString(),
        sumStrings(0, this.rewardsAmount / 2),
        'Rewards for Account 2 not correct'
      );
    });

    it('gets rewards when not equal deposits', async function() {
      const digiAmountOne = '1000000000000000000'; // 10.00
      await this.digiStake.stake(
        digiAmountOne,
        { from: accounts[1] }
      );
      const digiAmountTwo = '500000000000000000'; // 5.00
      await this.digiStake.stake(
        digiAmountTwo,
        { from: accounts[2] }
      );
      
      await this.digiStake.distribute();

      await this.digiStake.withdraw(
        { from: accounts[1] }
      );
      await this.digiStake.withdraw(
        { from: accounts[2] }
      );

      const stableBalanceOneAfterWithdraw = await this.stableToken.balanceOf(accounts[1]);
      const stableBalanceTwoAfterWithdraw = await this.stableToken.balanceOf(accounts[2]);

      assert.equal(
        stableBalanceOneAfterWithdraw.toString(),
        '66666666666666666666',
        'Rewards for Account 1 not correct'
      );

      assert.equal(
        stableBalanceTwoAfterWithdraw.toString(),
        '33333333333333333333',
        'Rewards for Account 2 not correct'
      );
    });

    it('add more rewards and claim', async function() {
      const digiAmountOne = '1000000000000000000'; // 10.00
      await this.digiStake.stake(
        digiAmountOne,
        { from: accounts[1] }
      );
      const digiAmountTwo = '500000000000000000'; // 5.00
      await this.digiStake.stake(
        digiAmountTwo,
        { from: accounts[2] }
      );

      await this.digiStake.distribute();

      await this.stableToken.transfer(
        this.digiStake.address,
        this.rewardsAmount,
        { from: accounts[0] }
      );

      await this.digiStake.distribute();

      await this.digiStake.withdraw(
        { from: accounts[1] }
      );
      await this.digiStake.withdraw(
        { from: accounts[2] }
      );

      const stableBalanceOneAfterWithdraw = await this.stableToken.balanceOf(accounts[1]);
      const stableBalanceTwoAfterWithdraw = await this.stableToken.balanceOf(accounts[2]);

      assert.equal(
        stableBalanceOneAfterWithdraw.toString(),
        sumStrings('66666666666666666666', '66666666666666666666'),
        'Rewards for Account 1 not correct'
      );

      assert.equal(
        stableBalanceTwoAfterWithdraw.toString(),
        sumStrings('33333333333333333333', '33333333333333333333'),
        'Rewards for Account 2 not correct'
      );
    });

  });

});

function sumStrings(a,b) { 
  return ((BigInt(a)) + BigInt(b)).toString();
}

function subStrings(a,b) { 
  return ((BigInt(a)) - BigInt(b)).toString();
}