const { expectRevert, expectEvent, BN } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const DigiNFT = artifacts.require("DigiNFT");

contract('DigiNFT', function (accounts) {

  beforeEach(async function () {

    this.digiNft = await DigiNFT.new(
      'https://digi.com/nft/',
      { from: accounts[0] }
    );

    await this.digiNft.grantRole(
      "0xf0887ba65ee2024ea881d91b74c2450ef19e1557f03bed3ea9f16b037cbe2dc9",
      accounts[0],
      { from: accounts[0] }
    );

  });

  describe('Supply', function () {

    it('has correct value', async function() {
      this.tokenIdA = await this.digiNft.mint.call(
        accounts[1],
        'Card Name',
        'x',
        false,
        { from: accounts[0] }
      );
      await this.digiNft.mint(
        accounts[1],
        'Card Name',
        'x',
        false,
        { from: accounts[0] }
      );

      assert.equal(
        await this.digiNft.totalSupply(),
        1,
        'DigiNFT has not a supply of 1 tokens'
      );
    });

  });

  describe('Minting one token', function () {

    it('has correct Id', async function() {
      this.tokenIdA = await this.digiNft.mint.call(
        accounts[1],
        'Card Name',
        'x',
        false,
        { from: accounts[0] }
      );
      await this.digiNft.mint(
        accounts[1],
        'Card Name',
        'x',
        false,
        { from: accounts[0] }
      );

      assert.equal(
        this.tokenIdA,
        1,
        'Token ID is not \'1\''
      );
    });

    it('has correct Name', async function() {
      this.tokenIdA = await this.digiNft.mint.call(
        accounts[1],
        'Card Name',
        'x',
        false,
        { from: accounts[0] }
      );
      await this.digiNft.mint(
        accounts[1],
        'Card Name',
        'x',
        false,
        { from: accounts[0] }
      );

      assert.equal(
        await this.digiNft.cardName(this.tokenIdA),
        'Card Name',
        'Token name is not \'Card Name\''
      );
    });

    it('has correct Image', async function() {
      this.tokenIdA = await this.digiNft.mint.call(
        accounts[1],
        'Card Name',
        'x',
        false,
        { from: accounts[0] }
      );
      await this.digiNft.mint(
        accounts[1],
        'Card Name',
        'x',
        false,
        { from: accounts[0] }
      );

      assert.equal(
        await this.digiNft.cardImage(this.tokenIdA),
        'x',
        'Token image is not \'x\''
      );
    });

    it('has correct Physical', async function() {
      this.tokenIdA = await this.digiNft.mint.call(
        accounts[1],
        'Card Name',
        'x',
        true,
        { from: accounts[0] }
      );
      await this.digiNft.mint(
        accounts[1],
        'Card Name',
        'x',
        true,
        { from: accounts[0] }
      );

      assert.equal(
        await this.digiNft.cardPhysical(this.tokenIdA),
        true,
        'Token phisycal is not \'true\''
      );
    });

  });

  describe('Account 1', function () {

    it('should have TokenA', async function() {
      this.tokenA = await this.digiNft.mint.call(
        accounts[1],
        'Card Name',
        'x',
        false,
        { from: accounts[0] }
      );
      await this.digiNft.mint(
        accounts[1],
        'Card Name',
        'x',
        false,
        { from: accounts[0] }
      );

      assert.equal(
        await this.digiNft.ownerOf(this.tokenA),
        accounts[1],
        'Account 1 is not owner of TokenA'
      );
    });

    it('transfers TokenA to Account 2', async function() {
      this.tokenA = await this.digiNft.mint.call(
        accounts[1],
        'Card Name',
        'x',
        false,
        { from: accounts[0] }
      );
      await this.digiNft.mint(
        accounts[1],
        'Card Name',
        'x',
        false,
        { from: accounts[0] }
      );

      await this.digiNft.transferFrom(
        accounts[1],
        accounts[2],
        this.tokenA,
        { from: accounts[1] }
      );
      assert.equal(
        await this.digiNft.ownerOf(this.tokenA),
        accounts[2],
        'Account 2 is not owner of TokenA'
      );
    });

  });

  describe('Account 2', function () {

    it('should can not to tranfer TokenA', async function() {
      this.tokenA = await this.digiNft.mint.call(
        accounts[1],
        'Card Name',
        'x',
        false,
        { from: accounts[0] }
      );
      await this.digiNft.mint(
        accounts[1],
        'Card Name',
        'x',
        false,
        { from: accounts[0] }
      );

      await expectRevert(
        this.digiNft.transferFrom(
          accounts[1],
          accounts[2],
          this.tokenA,
          { from: accounts[2] }
        ),
        'ERC721: transfer caller is not owner nor approved'
      );
    });

  });

  describe('Account 2', function () {

    it('should can not to mint a token', async function() {
      await expectRevert(
        this.digiNft.mint(
          accounts[2],
          'Card Name',
          'x',
          false,
          { from: accounts[2] }
        ),
        'DigiNFT: Only for role MINTER'
      );
    });

  });

});
