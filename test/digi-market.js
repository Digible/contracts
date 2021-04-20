const { expectRevert, expectEvent, BN, time } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const DigiToken = artifacts.require("DigiToken");
const DigiNFT = artifacts.require("DigiNFT");
const StableToken = artifacts.require("StableToken");
const DigiMarket = artifacts.require("DigiMarket");

contract('DigiMarket', function (accounts) {

  beforeEach(async function () {
    this.digiToken = await DigiToken.new(
      '1000000000000000000000000',
      { from: accounts[0] }
    );

    await this.digiToken.release({ from: accounts[0] });

    this.digiNFT = await DigiNFT.new(
      'https://digi.com/nft/',
      { from: accounts[0] }
    );

    this.stableToken = await StableToken.new(
      { from: accounts[0] }
    );

    this.digiMarket = await DigiMarket.new(
      this.digiToken.address,
      this.stableToken.address,
      { from: accounts[0] }
    );

    // Presets
    await this.digiToken.approve(
      this.digiMarket.address,
      '1000000000000000000000000000', // 100,000,000
      { from: accounts[2] }
    );
    await this.stableToken.approve(
      this.digiMarket.address,
      '1000000000000000000000000000', // 100,000,000
      { from: accounts[2] }
    );
    await this.digiToken.approve(
      this.digiMarket.address,
      '1000000000000000000000000000', // 100,000,000
      { from: accounts[4] }
    );
    await this.stableToken.approve(
      this.digiMarket.address,
      '1000000000000000000000000000', // 100,000,000
      { from: accounts[4] }
    );

    await this.digiToken.transfer(
      accounts[1],
      '30000000000000000000000', // 3000
      { from: accounts[0] }
    );
    await this.digiToken.transfer(
      accounts[8],
      '30000000000000000000000', // 3000
      { from: accounts[0] }
    );
    await this.digiToken.transfer(
      accounts[2],
      '10000000000000000000000', // 1000
      { from: accounts[0] }
    );
    await this.stableToken.transfer(
      accounts[2],
      '100000000000000000000', // 100
      { from: accounts[0] }
    );
    await this.digiToken.transfer(
      accounts[4],
      '10000000000000000000000', // 1000
      { from: accounts[0] }
    );
    await this.stableToken.transfer(
      accounts[4],
      '100000000000000000000', // 100
      { from: accounts[0] }
    );

    await this.digiNFT.setApprovalForAll(
      this.digiMarket.address,
      true,
      { from: accounts[1] }
    );

    await this.digiNFT.mint(
      accounts[1],
      'Card One',
      'x',
      false,
      { from: accounts[0] }
    );
    this.cardOne = 1;

    await this.digiNFT.mint(
      accounts[1],
      'Card Two',
      'x',
      true,
      { from: accounts[0] }
    );
    this.cardTwo = 2;

    await this.digiNFT.mint(
      accounts[8],
      'Card Three',
      'x',
      true,
      { from: accounts[0] }
    );
    this.cardThree = 3;
  });

  describe('createSale', function () {

    it('OK', async function() {
      const price = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const saleId = await this.digiMarket.createSale.call(
        this.cardTwo,
        this.digiNFT.address,
        price,
        duration,
        { from: accounts[1] }
      );
      await this.digiMarket.createSale(
        this.cardTwo,
        this.digiNFT.address,
        price,
        duration,
        { from: accounts[1] }
      );

      let sale = await this.digiMarket.sales.call(saleId).valueOf();
      assert.equal(
        sale.tokenId,
        this.cardTwo,
        'Created sale has not right value for tokenId'
      );
      assert.equal(
        sale.owner,
        accounts[1],
        'Created sale has not right value for owner'
      );
      assert.equal(
        sale.price,
        price,
        'Created sale has not right value for price'
      );
      assert.equal(
        sale.buyed,
        false,
        'Created sale has not right value for buyed'
      );
    });

    it('with not enought token', async function() {
      const fixedPrice = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      await expectRevert(
        this.digiMarket.createSale(
          this.cardTwo,
          this.digiNFT.address,
          fixedPrice,
          duration,
          { from: accounts[9] }
        ),
        'DigiMarket: User needs more token balance in order to do this action'
      );
    });

    it('when not owner', async function() {
      const fixedPrice = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      await expectRevert(
        this.digiMarket.createSale(
          this.cardTwo,
          this.digiNFT.address,
          fixedPrice,
          duration,
          { from: accounts[9] }
        ),
        'DigiMarket: User needs more token balance in order to do this action'
      );
    });

    it('when not allowed', async function() {
      const fixedPrice = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      await expectRevert(
        this.digiMarket.createSale(
          this.cardThree,
          this.digiNFT.address,
          fixedPrice,
          duration,
          { from: accounts[8] }
        ),
        'DigiMarket: DigiMarket contract address must be approved for transfer'
      );
    });

  });

  describe('cancelSale', function () {

    it('OK', async function() {
      const price = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const saleId = await this.digiMarket.createSale.call(
        this.cardTwo,
        this.digiNFT.address,
        price,
        duration,
        { from: accounts[1] }
      );
      await this.digiMarket.createSale(
        this.cardTwo,
        this.digiNFT.address,
        price,
        duration,
        { from: accounts[1] }
      );

      let originalSale = await this.digiMarket.sales.call(saleId).valueOf();

      await this.digiMarket.cancelSale(
        saleId,
        { from: accounts[1] }
      );

      let canceledSale = await this.digiMarket.sales.call(saleId).valueOf();

      assert.notEqual(
        originalSale.endDate,
        canceledSale.endDate,
        'Canceled sale has same endDate'
      );
    });

    it('when not owner', async function() {
      const price = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const saleId = await this.digiMarket.createSale.call(
        this.cardTwo,
        this.digiNFT.address,
        price,
        duration,
        { from: accounts[1] }
      );
      await this.digiMarket.createSale(
        this.cardTwo,
        this.digiNFT.address,
        price,
        duration,
        { from: accounts[1] }
      );

      //

      await this.digiNFT.transferFrom(
        accounts[1],
        accounts[0],
        this.cardTwo,
        { from: accounts[1] }
      );

      await expectRevert(
        this.digiMarket.cancelSale(
          saleId,
          { from: accounts[1] }
        ),
        'DigiMarket: User is not the token owner'
      );
    });

    it('when ended', async function() {
      const price = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const saleId = await this.digiMarket.createSale.call(
        this.cardTwo,
        this.digiNFT.address,
        price,
        duration,
        { from: accounts[1] }
      );
      await this.digiMarket.createSale(
        this.cardTwo,
        this.digiNFT.address,
        price,
        duration,
        { from: accounts[1] }
      );

      //
      
      await time.increase(time.duration.days(2));

      await expectRevert(
        this.digiMarket.cancelSale(
          saleId,
          { from: accounts[1] }
        ),
        'DigiMarket: Sale ended'
      );
    });

  });

  describe('buy', function () {

    it('when ended', async function() {
      const price = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const saleId = await this.digiMarket.createSale.call(
        this.cardTwo,
        this.digiNFT.address,
        price,
        duration,
        { from: accounts[1] }
      );
      await this.digiMarket.createSale(
        this.cardTwo,
        this.digiNFT.address,
        price,
        duration,
        { from: accounts[1] }
      );

      //

      await time.increase(time.duration.days(2));

      await expectRevert(
        this.digiMarket.buy(
          saleId,
          { from: accounts[2] }
        ),
        'DigiMarket: Sale ended'
      );
    });
    
    it('in progress but NFT moved', async function() {
      const fixedPrice = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const saleId = await this.digiMarket.createSale.call(
        this.cardTwo,
        this.digiNFT.address,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );
      await this.digiMarket.createSale(
        this.cardTwo,
        this.digiNFT.address,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );

      //

      await this.digiNFT.transferFrom(
        accounts[1],
        accounts[0],
        this.cardTwo,
        { from: accounts[1] }
      );

      await expectRevert(
        this.digiMarket.buy(
          saleId,
          { from: accounts[3] }
        ),
        'DigiMarket: Sale creator user is not longer NFT owner'
      );
    });

    it('in progress but not enough balance', async function() {
      const fixedPrice = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const saleId = await this.digiMarket.createSale.call(
        this.cardTwo,
        this.digiNFT.address,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );
      await this.digiMarket.createSale(
        this.cardTwo,
        this.digiNFT.address,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );

      //

      await expectRevert(
        this.digiMarket.buy(
          saleId,
          { from: accounts[3] }
        ),
        'DigiMarket: User does not have enough balance'
      );
    });

    it('in progress and enough balance', async function() {
      const fixedPrice = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const saleId = await this.digiMarket.createSale.call(
        this.cardTwo,
        this.digiNFT.address,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );
      await this.digiMarket.createSale(
        this.cardTwo,
        this.digiNFT.address,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );

      //
      const purchaseFee = Number(await this.digiMarket.purchaseFee.call());
      const userBalanceBefore = await this.stableToken.balanceOf(accounts[2]);

      await this.digiMarket.buy(
        saleId,
        { from: accounts[2] }
      );

      const auctionsBalanceAfter = await this.stableToken.balanceOf(this.digiMarket.address);
      const userBalanceAfter = await this.stableToken.balanceOf(accounts[2]);

      assert.equal(
        userBalanceBefore - userBalanceAfter,
        fixedPrice,
        'User balanceAfter not correct'
      );

      assert.equal(
        auctionsBalanceAfter,
        fixedPrice * (purchaseFee / 10000),
        'Market fees not correct'
      );

      await this.digiNFT.ownerOf(this.cardTwo, { from: accounts[2] });
    });

  });

  describe('feesDestinators and feePercentages', function () {

    it('trying to setFeesDestinatorsWithPercentages() by not owner', async function() {
      await expectRevert(
        this.digiMarket.setFeesDestinatorsWithPercentages(
          [accounts[6]],
          [100],
          { from: accounts[1] }
        ),
        'Ownable: caller is not the owner'
      );
    });

    it('trying to setFeesDestinatorsWithPercentages() without 100%', async function() {
      await expectRevert(
        this.digiMarket.setFeesDestinatorsWithPercentages(
          [accounts[6]],
          [99],
          { from: accounts[0] }
        ),
        'DigiMarket: Percentages sum must be 100'
      );
    });

    it('setted after setFeesDestinatorsWithPercentages() calls with 1 address', async function() {
      await this.digiMarket.setFeesDestinatorsWithPercentages(
        [accounts[6]],
        [100],
        { from: accounts[0] }
      );

      assert.equal(
        await this.digiMarket.feesDestinators.call(0).valueOf(),
        accounts[6],
        'feesDestinators has not been setted correctly' 
      );
      assert.equal(
        await this.digiMarket.feesPercentages.call(0).valueOf(),
        100,
        'feesPercentages has not been setted correctly' 
      );
    });

    it('setted after setFeesDestinatorsWithPercentages() calls with 3 address', async function() {
      await this.digiMarket.setFeesDestinatorsWithPercentages(
        [accounts[6], accounts[7], accounts[8]],
        [50, 25, 25],
        { from: accounts[0] }
      );

      assert.equal(
        await this.digiMarket.feesDestinators.call(0).valueOf(),
        accounts[6],
        'feesDestinators has not been setted correctly' 
      );
      assert.equal(
        await this.digiMarket.feesDestinators.call(1).valueOf(),
        accounts[7],
        'feesDestinators has not been setted correctly' 
      );
      assert.equal(
        await this.digiMarket.feesDestinators.call(2).valueOf(),
        accounts[8],
        'feesDestinators has not been setted correctly' 
      );
      assert.equal(
        await this.digiMarket.feesPercentages.call(0).valueOf(),
        50,
        'feesPercentages has not been setted correctly' 
      );
      assert.equal(
        await this.digiMarket.feesPercentages.call(1).valueOf(),
        25,
        'feesPercentages has not been setted correctly' 
      );
      assert.equal(
        await this.digiMarket.feesPercentages.call(2).valueOf(),
        25,
        'feesPercentages has not been setted correctly' 
      );
    });

    it('withdrawAcumulatedFees() when no fees', async function() {
      await this.digiMarket.setFeesDestinatorsWithPercentages(
        [accounts[6]],
        [100],
        { from: accounts[0] }
      );

      await this.digiMarket.withdrawAcumulatedFees({ from: accounts[0] });
      
      assert.equal(
        (await this.stableToken.balanceOf(accounts[6])).toString(),
        '0',
        'withdrawAcumulatedFees() has withdrawal fees when no fees' 
      );
    });

    it('getAcumulatedFees() works', async function() {
      const fixedPrice = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const saleId = await this.digiMarket.createSale.call(
        this.cardTwo,
        this.digiNFT.address,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );
      await this.digiMarket.createSale(
        this.cardTwo,
        this.digiNFT.address,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );

      //

      await this.digiMarket.setFeesDestinatorsWithPercentages(
        [accounts[6], accounts[7], accounts[8]],
        [50, 25, 25],
        { from: accounts[0] }
      );

      await this.digiMarket.buy(
        saleId,
        { from: accounts[2] }
      );

      await this.digiMarket.withdrawAcumulatedFees({ from: accounts[0] });
      
      //

      const purchaseFee = Number(await this.digiMarket.purchaseFee.call());

      assert.equal(
        (await this.stableToken.balanceOf(accounts[6])).toString(),
        ((fixedPrice * (purchaseFee / 10000)) / 100 * 50),
        'accounts[6] has withdrawal wrong fees amounts' 
      );
      assert.equal(
        (await this.stableToken.balanceOf(accounts[7])).toString(),
        ((fixedPrice * (purchaseFee / 10000)) / 100 * 25),
        'accounts[7] has withdrawal wrong fees amounts' 
      );
      assert.equal(
        (await this.stableToken.balanceOf(accounts[8])).toString(),
        ((fixedPrice * (purchaseFee / 10000)) / 100 * 25),
        'accounts[8] has withdrawal wrong fees amounts' 
      );

    });
  });
  
  describe('setFee', function () {

    it('purchaseFee setted after setFee()', async function() {
      await this.digiMarket.setFee(
        100,
        { from: accounts[0] }
      );

      const purchaseFee = Number(await this.digiMarket.purchaseFee.call());

      assert.equal(
        purchaseFee,
        100,
        'purchaseFee has not been setted correctly' 
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