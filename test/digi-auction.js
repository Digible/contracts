const { expectRevert, expectEvent, BN, time } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const DigiToken = artifacts.require("DigiToken");
const DigiNFT = artifacts.require("DigiNFT");
const StableToken = artifacts.require("StableToken");
const DigiAuction = artifacts.require("DigiAuction");

contract('DigiAuction', function (accounts) {

  beforeEach(async function () {
    this.digiToken = await DigiToken.new(
      '1000000000000000000000000',
      { from: accounts[0] }
    );

    this.digiNFT = await DigiNFT.new(
      'https://digi.com/nft/',
      { from: accounts[0] }
    );

    this.stableToken = await StableToken.new(
      { from: accounts[0] }
    );

    this.digiAuction = await DigiAuction.new(
      this.digiToken.address,
      this.digiNFT.address,
      this.stableToken.address,
      { from: accounts[0] }
    );

    // Presets
    await this.digiToken.approve(
      this.digiAuction.address,
      '1000000000000000000000000000', // 100,000,000
      { from: accounts[2] }
    );
    await this.stableToken.approve(
      this.digiAuction.address,
      '1000000000000000000000000000', // 100,000,000
      { from: accounts[2] }
    );
    await this.digiToken.approve(
      this.digiAuction.address,
      '1000000000000000000000000000', // 100,000,000
      { from: accounts[4] }
    );
    await this.stableToken.approve(
      this.digiAuction.address,
      '1000000000000000000000000000', // 100,000,000
      { from: accounts[4] }
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
      this.digiAuction.address,
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
  });

  describe('createAuction', function () {

    it('for physical card', async function() {
      const minPrice = '1000000000000000000'; // 1.0 $
      const fixedPrice = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const auctionId = await this.digiAuction.createAuction.call(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );
      await this.digiAuction.createAuction(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );

      assert.equal(
        await this.digiNFT.ownerOf(this.cardTwo),
        this.digiAuction.address,
        'Auction contract is not the owner of the NFT'
      );

      let auction = await this.digiAuction.auctions.call(auctionId).valueOf();
      assert.equal(
        auction.tokenId,
        this.cardTwo,
        'Created auction has not right value for tokenId'
      );
      assert.equal(
        auction.owner,
        accounts[1],
        'Created auction has not right value for owner'
      );
      assert.equal(
        auction.minPrice,
        minPrice,
        'Created auction has not right value for minPrice'
      );
      assert.equal(
        auction.fixedPrice,
        fixedPrice,
        'Created auction has not right value for fixedPrice'
      );
      assert.equal(
        auction.buyed,
        false,
        'Created auction has not right value for buyed'
      );
    });

  });

  describe('directBuy', function () {

    it('when ended', async function() {
      const minPrice = '1000000000000000000'; // 1.0 $
      const fixedPrice = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const auctionId = await this.digiAuction.createAuction.call(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );
      await this.digiAuction.createAuction(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );

      //

      await time.increase(time.duration.days(2));

      await expectRevert(
        this.digiAuction.directBuy(
          auctionId,
          { from: accounts[2] }
        ),
        'DigiAuction: Auction closed'
      );
    });

    it('in progress but not enough balance', async function() {
      const minPrice = '1000000000000000000'; // 1.0 $
      const fixedPrice = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const auctionId = await this.digiAuction.createAuction.call(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );
      await this.digiAuction.createAuction(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );

      //

      await expectRevert(
        this.digiAuction.directBuy(
          auctionId,
          { from: accounts[3] }
        ),
        'DigiAuction: User does not have enough balance'
      );
    });

    it('in progress and enough balance', async function() {
      const minPrice = '1000000000000000000'; // 1.0 $
      const fixedPrice = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const auctionId = await this.digiAuction.createAuction.call(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );
      await this.digiAuction.createAuction(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );

      //
      const purchaseFee = Number(await this.digiAuction.purchaseFee.call());
      const userBalanceBefore = await this.stableToken.balanceOf(accounts[2]);

      await this.digiAuction.directBuy(
        auctionId,
        { from: accounts[2] }
      );

      const auctionsBalanceAfter = await this.stableToken.balanceOf(this.digiAuction.address);
      const userBalanceAfter = await this.stableToken.balanceOf(accounts[2]);

      assert.equal(
        userBalanceBefore - userBalanceAfter,
        fixedPrice,
        'User balanceAfter not correct'
      );

      assert.equal(
        auctionsBalanceAfter,
        fixedPrice * (purchaseFee / 10000),
        'Auctions fees not correct'
      );

      await this.digiNFT.ownerOf(this.cardTwo, { from: accounts[2] });
    });

    it('when already someone has participated', async function() {
      const minPrice = '1000000000000000000'; // 1.0 $
      const fixedPrice = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const auctionId = await this.digiAuction.createAuction.call(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );
      await this.digiAuction.createAuction(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );

      //
      const purchaseFee = Number(await this.digiAuction.purchaseFee.call());

      const firstUserBalanceBefore = await this.stableToken.balanceOf(accounts[2]);
      const auctionsBalanceBefore = await this.stableToken.balanceOf(this.digiAuction.address);
      await this.digiAuction.participateAuction(
        auctionId,
        '1000000000000000000',
        { from: accounts[2] }
      );

      const userTwoBalanceBefore = await this.stableToken.balanceOf(accounts[4]);
      await this.digiAuction.directBuy(
        auctionId,
        { from: accounts[4] }
      );

      assert.equal(
        (await this.stableToken.balanceOf(accounts[2])).toString(),
        firstUserBalanceBefore.toString(),
        'First user participation has not been returned'
      );
      assert.equal(
        (await this.stableToken.balanceOf(accounts[4])).toString(),
        subStrings(userTwoBalanceBefore, fixedPrice),
        'Second user participation has not been charged'
      );
      assert.equal(
        (await this.stableToken.balanceOf(this.digiAuction.address)).toString(),
        sumStrings(auctionsBalanceBefore, fixedPrice * (purchaseFee / 10000)),
        'Auctions balance is not correct'
      );
    });

  });

  describe('participateAuction', function () {

    it('without required amount', async function() {
      const minPrice = '1000000000000000000'; // 1.0 $
      const fixedPrice = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const auctionId = await this.digiAuction.createAuction.call(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );
      await this.digiAuction.createAuction(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );

      //
        
      const participationAmount = '100000000000000000'; // .10 $
      await expectRevert(
        this.digiAuction.participateAuction(
          auctionId,
          participationAmount,
          { from: accounts[3] }
        ),
        'DigiAuction: User needs more token balance in order to do this action'
      );
    });

    it('when ended', async function() {
      const minPrice = '1000000000000000000'; // 1.0 $
      const fixedPrice = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const auctionId = await this.digiAuction.createAuction.call(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );
      await this.digiAuction.createAuction(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );

      //
      await time.increase(time.duration.days(2));

      const participationAmount = '1000000000000000000'; // 1.00 $
      await expectRevert(
        this.digiAuction.participateAuction(
          auctionId,
          participationAmount,
          { from: accounts[2] }
        ),
        'DigiAuction: Auction closed'
      );
    });

    it('without minimum price', async function() {
      const minPrice = '1000000000000000000'; // 1.0 $
      const fixedPrice = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const auctionId = await this.digiAuction.createAuction.call(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );
      await this.digiAuction.createAuction(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );

      //
        
      const participationAmount = '100000000000000000'; // .10 $
      await expectRevert(
        this.digiAuction.participateAuction(
          auctionId,
          participationAmount,
          { from: accounts[2] }
        ),
        'DigiAuction: Insufficient offer amount for this auction'
      );
    });

    it('first participation', async function() {
      const minPrice = '1000000000000000000'; // 1.0 $
      const fixedPrice = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const auctionId = await this.digiAuction.createAuction.call(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );
      await this.digiAuction.createAuction(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );

      //

      const userBalanceBefore = await this.stableToken.balanceOf(accounts[2]);
      const auctionsBalanceBefore = await this.stableToken.balanceOf(this.digiAuction.address);

      const participationAmount = '1000000000000000000'; // 1.00 $
      await this.digiAuction.participateAuction(
        auctionId,
        participationAmount,
        { from: accounts[2] }
      );

      const userBalanceAfter = await this.stableToken.balanceOf(accounts[2]);
      const auctionsBalanceAfter = await this.stableToken.balanceOf(this.digiAuction.address);

      assert.equal(
        subStrings(userBalanceBefore, userBalanceAfter),
        participationAmount,
        'User balance not correct'
      );
      assert.equal(
        sumStrings(participationAmount, auctionsBalanceBefore),
        auctionsBalanceAfter,
        'Auctions balance not correct'
      );

      let participation = await this.digiAuction.highestOffers.call(auctionId).valueOf();
      assert.equal(
        participation.buyer,
        accounts[2],
        'New highestOffers has not right value for buyer'
      );
      assert.equal(
        participation.offer,
        participationAmount,
        'New highestOffers has not right value for offer'
      );
    });

    it('second participation', async function() {
      const minPrice = '1000000000000000000'; // 1.0 $
      const fixedPrice = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const auctionId = await this.digiAuction.createAuction.call(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );
      await this.digiAuction.createAuction(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );

      //

      const firstUserBalanceBefore = await this.stableToken.balanceOf(accounts[2]);
      const auctionsBalanceBefore = await this.stableToken.balanceOf(this.digiAuction.address);
      await this.digiAuction.participateAuction(
        auctionId,
        '1000000000000000000',
        { from: accounts[2] }
      );

      const userTwoBalanceBefore = await this.stableToken.balanceOf(accounts[4]);
      const participationAmount = '1000000000000000001'; // 1.01 $
      await this.digiAuction.participateAuction(
        auctionId,
        participationAmount,
        { from: accounts[4] }
      );

      assert.equal(
        (await this.stableToken.balanceOf(accounts[2])).toString(),
        firstUserBalanceBefore.toString(),
        'First user participation has not been returned'
      );
      assert.equal(
        (await this.stableToken.balanceOf(accounts[4])).toString(),
        subStrings(userTwoBalanceBefore, participationAmount),
        'Second user participation has not been charged'
      );
      assert.equal(
        (await this.stableToken.balanceOf(this.digiAuction.address)).toString(),
        sumStrings(auctionsBalanceBefore, participationAmount),
        'Auctions balance is not correct'
      );

      let participation = await this.digiAuction.highestOffers.call(auctionId).valueOf();
      assert.equal(
        participation.buyer,
        accounts[4],
        'New highestOffers has not right value for buyer'
      );
      assert.equal(
        participation.offer,
        participationAmount,
        'New highestOffers has not right value for offer'
      );
    });

    it('second participation but not highest offer', async function() {
      const minPrice = '1000000000000000000'; // 1.0 $
      const fixedPrice = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const auctionId = await this.digiAuction.createAuction.call(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );
      await this.digiAuction.createAuction(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );

      //
      await this.digiAuction.participateAuction(
        auctionId,
        '1000000000000000001',
        { from: accounts[2] }
      );

      const participationAmount = '1000000000000000000'; // 1.00 $
      await expectRevert(
        this.digiAuction.participateAuction(
          auctionId,
          participationAmount,
          { from: accounts[4] }
        ),
        'DigiAuction: Amount must be higher'
      );

    });

  });

  describe('claim', function () {

    it('when ended and won', async function() {
      const minPrice = '1000000000000000000'; // 1.0 $
      const fixedPrice = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const auctionId = await this.digiAuction.createAuction.call(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );
      await this.digiAuction.createAuction(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );

      //

      const ownerBalanceBefore = await this.stableToken.balanceOf(accounts[1]);

      const participationAmount = '1000000000000000000'; // 1.00 $
      await this.digiAuction.participateAuction(
        auctionId,
        participationAmount,
        { from: accounts[2] }
      );

      assert.equal(
        await this.digiNFT.ownerOf(this.cardTwo),
        this.digiAuction.address,
        'Auction contract is not the owner of the NFT'
      );

      await time.increase(time.duration.days(2));

      await this.digiAuction.claim(
        auctionId,
        { from: accounts[2] }
      );

      assert.equal(
        await this.digiNFT.ownerOf(this.cardTwo),
        accounts[2],
        'Winner user not received the NFT'
      );

      const ownerBalanceAfter = await this.stableToken.balanceOf(accounts[1]);
      const purchaseFee = Number(await this.digiAuction.purchaseFee.call());

      assert.equal(
        sumStrings(ownerBalanceBefore, (participationAmount - (participationAmount * (purchaseFee / 10000)))),
        ownerBalanceAfter,
        'Token owner has not received the amount' 
      );

      assert.equal(
        (await this.stableToken.balanceOf(this.digiAuction.address)).toString(),
        (participationAmount * (purchaseFee / 10000)).toString(),
        'DigiAuction has not received the fee amount' 
      );
    });

    it('when ended and claimed by other user', async function() {
      const minPrice = '1000000000000000000'; // 1.0 $
      const fixedPrice = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const auctionId = await this.digiAuction.createAuction.call(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );
      await this.digiAuction.createAuction(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );

      //

      const participationAmount = '1000000000000000000'; // 1.00 $
      await this.digiAuction.participateAuction(
        auctionId,
        participationAmount,
        { from: accounts[2] }
      );

      await time.increase(time.duration.days(2));

      await this.digiAuction.claim(
        auctionId,
        { from: accounts[4] }
      );

      assert.equal(
        await this.digiNFT.ownerOf(this.cardTwo),
        accounts[2],
        'Winner user not received the NFT'
      );
    });

    it('when not ended', async function() {
      const minPrice = '1000000000000000000'; // 1.0 $
      const fixedPrice = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const auctionId = await this.digiAuction.createAuction.call(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );
      await this.digiAuction.createAuction(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );

      //
      
      const participationAmount = '1000000000000000000'; // 1.00 $
      await this.digiAuction.participateAuction(
        auctionId,
        participationAmount,
        { from: accounts[2] }
      );

      await expectRevert(
        this.digiAuction.claim(
          auctionId,
          { from: accounts[2] }
        ),
        'DigiAuction: Auction not closed'
      );
    });

  });

  describe('feesDestinators and feePercentages', function () {

    it('trying to setFeesDestinatorsWithPercentages() by not owner', async function() {
      await expectRevert(
        this.digiAuction.setFeesDestinatorsWithPercentages(
          [accounts[6]],
          [100],
          { from: accounts[1] }
        ),
        'Ownable: caller is not the owner'
      );
    });

    it('trying to setFeesDestinatorsWithPercentages() without 100%', async function() {
      await expectRevert(
        this.digiAuction.setFeesDestinatorsWithPercentages(
          [accounts[6]],
          [99],
          { from: accounts[0] }
        ),
        'DigiAuction: Percentages sum must be 100'
      );
    });

    it('setted after setFeesDestinatorsWithPercentages() calls with 1 address', async function() {
      await this.digiAuction.setFeesDestinatorsWithPercentages(
        [accounts[6]],
        [100],
        { from: accounts[0] }
      );

      assert.equal(
        await this.digiAuction.feesDestinators.call(0).valueOf(),
        accounts[6],
        'feesDestinators has not been setted correctly' 
      );
      assert.equal(
        await this.digiAuction.feesPercentages.call(0).valueOf(),
        100,
        'feesPercentages has not been setted correctly' 
      );
    });

    it('setted after setFeesDestinatorsWithPercentages() calls with 3 address', async function() {
      await this.digiAuction.setFeesDestinatorsWithPercentages(
        [accounts[6], accounts[7], accounts[8]],
        [50, 25, 25],
        { from: accounts[0] }
      );

      assert.equal(
        await this.digiAuction.feesDestinators.call(0).valueOf(),
        accounts[6],
        'feesDestinators has not been setted correctly' 
      );
      assert.equal(
        await this.digiAuction.feesDestinators.call(1).valueOf(),
        accounts[7],
        'feesDestinators has not been setted correctly' 
      );
      assert.equal(
        await this.digiAuction.feesDestinators.call(2).valueOf(),
        accounts[8],
        'feesDestinators has not been setted correctly' 
      );
      assert.equal(
        await this.digiAuction.feesPercentages.call(0).valueOf(),
        50,
        'feesPercentages has not been setted correctly' 
      );
      assert.equal(
        await this.digiAuction.feesPercentages.call(1).valueOf(),
        25,
        'feesPercentages has not been setted correctly' 
      );
      assert.equal(
        await this.digiAuction.feesPercentages.call(2).valueOf(),
        25,
        'feesPercentages has not been setted correctly' 
      );
    });

    it('withdrawAcumulatedFees() when no fees', async function() {
      await this.digiAuction.setFeesDestinatorsWithPercentages(
        [accounts[6]],
        [100],
        { from: accounts[0] }
      );

      await this.digiAuction.withdrawAcumulatedFees({ from: accounts[0] });
      
      assert.equal(
        (await this.stableToken.balanceOf(accounts[6])).toString(),
        '0',
        'withdrawAcumulatedFees() has withdrawal fees when no fees' 
      );
    });

    it('getAcumulatedFees() works', async function() {
      const minPrice = '1000000000000000000'; // 1.0 $
      const fixedPrice = '10000000000000000000'; // 10.0 $
      const duration = time.duration.days(1);

      const auctionId = await this.digiAuction.createAuction.call(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );
      await this.digiAuction.createAuction(
        this.cardTwo,
        minPrice,
        fixedPrice,
        duration,
        { from: accounts[1] }
      );

      //

      await this.digiAuction.setFeesDestinatorsWithPercentages(
        [accounts[6], accounts[7], accounts[8]],
        [50, 25, 25],
        { from: accounts[0] }
      );

      const participationAmount = '1000000000000000000'; // 1.00 $
      await this.digiAuction.participateAuction(
        auctionId,
        participationAmount,
        { from: accounts[2] }
      );

      await time.increase(time.duration.days(2));

      await this.digiAuction.claim(
        auctionId,
        { from: accounts[2] }
      );

      await this.digiAuction.withdrawAcumulatedFees({ from: accounts[0] });
      
      //

      const purchaseFee = Number(await this.digiAuction.purchaseFee.call());

      assert.equal(
        (await this.stableToken.balanceOf(accounts[6])).toString(),
        ((participationAmount * (purchaseFee / 10000)) / 100 * 50),
        'accounts[6] has withdrawal wrong fees amounts' 
      );
      assert.equal(
        (await this.stableToken.balanceOf(accounts[7])).toString(),
        ((participationAmount * (purchaseFee / 10000)) / 100 * 25),
        'accounts[7] has withdrawal wrong fees amounts' 
      );
      assert.equal(
        (await this.stableToken.balanceOf(accounts[8])).toString(),
        ((participationAmount * (purchaseFee / 10000)) / 100 * 25),
        'accounts[8] has withdrawal wrong fees amounts' 
      );

    });
  });

  describe('setFee', function () {

    it('purchaseFee setted after setFee()', async function() {
      await this.digiAuction.setFee(
        100,
        { from: accounts[0] }
      );

      const purchaseFee = Number(await this.digiAuction.purchaseFee.call());

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