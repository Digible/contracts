const { expectRevert, expectEvent, BN, time } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');
const truffleAssert = require('truffle-assertions');

const DigiToken = artifacts.require("DigiToken");
const DigiNFT = artifacts.require("DigiNFT");
const StableToken = artifacts.require("StableToken");
const DigiDuel = artifacts.require("DigiDuel");

contract('DigiDuel', function (accounts) {

    beforeEach(async function () {
        this.digiToken = await DigiToken.new(
        '1000000000000000000000000',
        { from: accounts[0] }
        );

        this.digiNFT = await DigiNFT.new(
        'https://digi.com/nft/',
        { from: accounts[0] }
        );

        this.digiDuel = await DigiDuel.new(
        this.digiToken.address,
        this.digiNFT.address,
        { from: accounts[0] }
        );

        // Presets
        await this.digiToken.approve(
        this.digiDuel.address,
        '1000000000000000000000000000', // 100,000,000
        { from: accounts[1] }
        );
        await this.digiToken.approve(
        this.digiDuel.address,
        '1000000000000000000000000000', // 100,000,000
        { from: accounts[2] }
        );

        await this.digiToken.transfer(
        accounts[1],
        '30000000000000000000000', // 3000
        { from: accounts[0] }
        );
        await this.digiToken.transfer(
        accounts[2],
        '30000000000000000000000', // 3000
        { from: accounts[0] }
        );

        await this.digiNFT.setApprovalForAll(
        this.digiDuel.address,
        true,
        { from: accounts[1] }
        );
        await this.digiNFT.setApprovalForAll(
            this.digiDuel.address,
            true,
            { from: accounts[2] }
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
        accounts[2],
        'Card Two',
        'x',
        true,
        { from: accounts[0] }
        );
        this.cardTwo = 2;
    });

    describe('create', function () {

      it('OK', async function() {
        const amount = '10000000000000000000'; // 10.0 $DIGI
        const color = '1'; // Red
        const duration = time.duration.days(1);

        const duelId = await this.digiDuel.create.call(
            this.cardOne,
            amount,
            color,
            duration,
            { from: accounts[1] }
        );
        await this.digiDuel.create(
            this.cardOne,
            amount,
            color,
            duration,
            { from: accounts[1] }
        );

        let duel = await this.digiDuel.duels.call(duelId).valueOf();
        assert.equal(
            duel.tokenId,
            this.cardOne,
            'Created duel has not right value for tokenId'
        );
        assert.equal(
            duel.owner,
            accounts[1],
            'Created duel has not right value for owner'
        );
        assert.equal(
            duel.amount,
            amount,
            'Created duel has not right value for amount'
        );
        assert.equal(
            duel.color,
            color,
            'Created duel has not right value for color'
        );
        assert.equal(
            duel.acceptedBy,
            '0x0000000000000000000000000000000000000000',
            'Created duel has not right value for accepted'
        );
      });

      it('with not enought amount', async function() {
        const amount = '100000000000000000000000'; // 100000.0 $DIGI
        const color = '1'; // Red
        const duration = time.duration.days(1);

        await expectRevert(
        this.digiDuel.create(
            this.cardOne,
            amount,
            color,
            duration,
            { from: accounts[1] }
        ),
        'ERC20: transfer amount exceeds balance'
        );
      });

      it('when not owner', async function() {
        const amount = '10000000000000000000'; // 10.0 $DIGI
        const color = '1'; // Red
        const duration = time.duration.days(1);

        await expectRevert(
            this.digiDuel.create(
                this.cardTwo,
                amount,
                color,
                duration,
                { from: accounts[1] }
            ),
            'ERC721: transfer of token that is not own.'
        );
      });

    });

    describe('cancel', function () {

      it('OK', async function() {
        const amount = '10000000000000000000'; // 10.0 $DIGI
        const color = '1'; // Red
        const duration = time.duration.days(1);

        const duelId = await this.digiDuel.create.call(
          this.cardOne,
          amount,
          color,
          duration,
          { from: accounts[1] }
        );
        await this.digiDuel.create(
          this.cardOne,
          amount,
          color,
          duration,
          { from: accounts[1] }
        );

        let originalDuel = await this.digiDuel.duels.call(duelId).valueOf();

        await this.digiDuel.cancel(
          duelId,
          { from: accounts[1] }
        );

        const accountOneBalanceBefore = (await this.digiToken.balanceOf(accounts[1])).toString();

        let canceledDuel = await this.digiDuel.duels.call(duelId).valueOf();

        assert.notEqual(
          originalDuel.endDate,
          canceledDuel.endDate,
          'Canceled duel has same endDate'
        );

        assert.equal(
          (await this.digiNFT.ownerOf(this.cardOne)).toString(),
          accounts[1].toString(),
          'Account [1] has not recover the token NFT'
        );

        const accountOneBalanceAfter = (await this.digiToken.balanceOf(accounts[1])).toString();

        assert.equal(
          accountOneBalanceAfter,
          accountOneBalanceBefore,
          'Account [1] has not recover tokens'
        );
      });

      it('when not te owner', async function() {
        const amount = '10000000000000000000'; // 10.0 $DIGI
        const color = '1'; // Red
        const duration = time.duration.days(1);

        const duelId = await this.digiDuel.create.call(
          this.cardOne,
          amount,
          color,
          duration,
          { from: accounts[1] }
        );
        await this.digiDuel.create(
          this.cardOne,
          amount,
          color,
          duration,
          { from: accounts[1] }
        );

        //

        await expectRevert(
        this.digiDuel.cancel(
            duelId,
            { from: accounts[2] }
        ),
        'DigiDuel: User is not the token owner'
        );
      });

        it('when ended', async function() {
            const amount = '10000000000000000000'; // 10.0 $DIGI
            const color = '1'; // Red
            const duration = time.duration.days(1);

            const duelId = await this.digiDuel.create.call(
                this.cardOne,
                amount,
                color,
                duration,
                { from: accounts[1] }
            );
            await this.digiDuel.create(
                this.cardOne,
                amount,
                color,
                duration,
                { from: accounts[1] }
            );

            //
            
            await time.increase(time.duration.days(2));

            await expectRevert(
            this.digiDuel.cancel(
                duelId,
                { from: accounts[1] }
            ),
            'DigiDuel: Duel ended'
            );
        });
    });

    describe('accept', function () {
        it('when ended', async function() {
            const amount = '10000000000000000000'; // 10.0 $DIGI
            const color = '1'; // Red
            const duration = time.duration.days(1);
    
            const duelId = await this.digiDuel.create.call(
                this.cardOne,
                amount,
                color,
                duration,
                { from: accounts[1] }
            );
            await this.digiDuel.create(
                this.cardOne,
                amount,
                color,
                duration,
                { from: accounts[1] }
            );
      
            //
            
            await time.increase(time.duration.days(2));
      
            await expectRevert(
              this.digiDuel.cancel(
                duelId,
                { from: accounts[2] }
              ),
              'DigiDuel: Duel ended'
            );
        });

        it('OK', async function() {
            const amount = '10000000000000000000'; // 10.0 $DIGI
            const color = '1'; // Red
            const duration = time.duration.days(1);
    
            const duelId = await this.digiDuel.create.call(
                this.cardOne,
                amount,
                color,
                duration,
                { from: accounts[1] }
            );
            await this.digiDuel.create(
                this.cardOne,
                amount,
                color,
                duration,
                { from: accounts[1] }
            );
      
            //
      
            const accountOneBalanceBefore = (await this.digiToken.balanceOf(accounts[1])).toString();
            const accountTwoBalanceBefore = (await this.digiToken.balanceOf(accounts[2])).toString();

            const result = await this.digiDuel.accept(
                duelId,
                this.cardTwo,
                { from: accounts[2] }
            );

            const accountOneBalanceAfter = (await this.digiToken.balanceOf(accounts[1])).toString();
            const accountTwoBalanceAfter = (await this.digiToken.balanceOf(accounts[2])).toString();

            let eventX;
            truffleAssert.eventEmitted(result, 'WinnedDuel', (event) => {
                eventX = event;
                return true;
            });

            if (eventX.color.toString() === '1') {   // Winner accounts[1]

                assert.equal(
                    (await this.digiNFT.ownerOf(this.cardOne)).toString(),
                    accounts[1].toString(),
                    'Winner [1] has not received first token'
                );
                assert.equal(
                    (await this.digiNFT.ownerOf(this.cardTwo)).toString(),
                    accounts[1].toString(),
                    'Winner [1] has not received second token'
                );
                assert.equal(
                    accountOneBalanceAfter,
                    sumStrings(accountOneBalanceBefore, sumStrings(amount, eventX.totalAmount.toString())),
                    'Winner [1] has not received tokens'
                );

            } else {    // Winner accounts[2]

                assert.equal(
                    (await this.digiNFT.ownerOf(this.cardOne)).toString(),
                    accounts[2].toString(),
                    'Winner [2] has not received first token'
                );
                assert.equal(
                    (await this.digiNFT.ownerOf(this.cardTwo)).toString(),
                    accounts[2].toString(),
                    'Winner [2] has not received second token'
                );
                assert.equal(
                    accountTwoBalanceAfter,
                    sumStrings(accountTwoBalanceBefore, eventX.totalAmount.toString()),
                    'Winner [2] has not received tokens'
                );

            }
        });
    });

    describe('feesDestinators and feePercentages', function () {

        it('trying to setFeesDestinatorsWithPercentages() by not owner', async function() {
          await expectRevert(
            this.digiDuel.setFeesDestinatorsWithPercentages(
              [accounts[6]],
              [100],
              { from: accounts[1] }
            ),
            'Ownable: caller is not the owner'
          );
        });
    
        it('trying to setFeesDestinatorsWithPercentages() without 100%', async function() {
          await expectRevert(
            this.digiDuel.setFeesDestinatorsWithPercentages(
              [accounts[6]],
              [99],
              { from: accounts[0] }
            ),
            'DigiDuel: Percentages sum must be 100'
          );
        });
    
        it('setted after setFeesDestinatorsWithPercentages() calls with 1 address', async function() {
          await this.digiDuel.setFeesDestinatorsWithPercentages(
            [accounts[6]],
            [100],
            { from: accounts[0] }
          );
    
          assert.equal(
            await this.digiDuel.feesDestinators.call(0).valueOf(),
            accounts[6],
            'feesDestinators has not been setted correctly' 
          );
          assert.equal(
            await this.digiDuel.feesPercentages.call(0).valueOf(),
            100,
            'feesPercentages has not been setted correctly' 
          );
        });
    
        it('setted after setFeesDestinatorsWithPercentages() calls with 3 address', async function() {
          await this.digiDuel.setFeesDestinatorsWithPercentages(
            [accounts[6], accounts[7], accounts[8]],
            [50, 25, 25],
            { from: accounts[0] }
          );
    
          assert.equal(
            await this.digiDuel.feesDestinators.call(0).valueOf(),
            accounts[6],
            'feesDestinators has not been setted correctly' 
          );
          assert.equal(
            await this.digiDuel.feesDestinators.call(1).valueOf(),
            accounts[7],
            'feesDestinators has not been setted correctly' 
          );
          assert.equal(
            await this.digiDuel.feesDestinators.call(2).valueOf(),
            accounts[8],
            'feesDestinators has not been setted correctly' 
          );
          assert.equal(
            await this.digiDuel.feesPercentages.call(0).valueOf(),
            50,
            'feesPercentages has not been setted correctly' 
          );
          assert.equal(
            await this.digiDuel.feesPercentages.call(1).valueOf(),
            25,
            'feesPercentages has not been setted correctly' 
          );
          assert.equal(
            await this.digiDuel.feesPercentages.call(2).valueOf(),
            25,
            'feesPercentages has not been setted correctly' 
          );
        });
    
        it('withdrawAcumulatedFees() when no fees', async function() {
          await this.digiDuel.setFeesDestinatorsWithPercentages(
            [accounts[6]],
            [100],
            { from: accounts[0] }
          );
    
          await this.digiDuel.withdrawAcumulatedFees({ from: accounts[0] });
          
          assert.equal(
            (await this.digiToken.balanceOf(accounts[6])).toString(),
            '0',
            'withdrawAcumulatedFees() has withdrawal fees when no fees' 
          );
        });
    
        it('getAcumulatedFees() works', async function() {
            const amount = '10000000000000000000'; // 10.0 $DIGI
            const color = '1'; // Red
            const duration = time.duration.days(1);
    
            const duelId = await this.digiDuel.create.call(
                this.cardOne,
                amount,
                color,
                duration,
                { from: accounts[1] }
            );
            await this.digiDuel.create(
                this.cardOne,
                amount,
                color,
                duration,
                { from: accounts[1] }
            );
    
            //
    
            await this.digiDuel.setFeesDestinatorsWithPercentages(
                [accounts[6], accounts[7], accounts[8]],
                [50, 25, 25],
                { from: accounts[0] }
            );
    
            await this.digiDuel.accept(
                duelId,
                this.cardTwo,
                { from: accounts[2] }
            );
    
            await this.digiDuel.withdrawAcumulatedFees({ from: accounts[0] });
          
            //
    
            const purchaseFee = Number(await this.digiDuel.purchaseFee.call());

            assert.equal(
                (await this.digiToken.balanceOf(accounts[6])).toString(),
                (((amount * 2) * (purchaseFee / 10000)) / 100 * 50),
                'accounts[6] has withdrawal wrong fees amounts' 
            );
            assert.equal(
                (await this.digiToken.balanceOf(accounts[7])).toString(),
                (((amount * 2) * (purchaseFee / 10000)) / 100 * 25),
                'accounts[7] has withdrawal wrong fees amounts' 
            );
            assert.equal(
                (await this.digiToken.balanceOf(accounts[8])).toString(),
                (((amount * 2) * (purchaseFee / 10000)) / 100 * 25),
                'accounts[8] has withdrawal wrong fees amounts' 
            );
    
        });
      });
      
      describe('setFee', function () {
    
        it('purchaseFee setted after setFee()', async function() {
          await this.digiDuel.setFee(
            100,
            { from: accounts[0] }
          );
    
          const purchaseFee = Number(await this.digiDuel.purchaseFee.call());
    
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