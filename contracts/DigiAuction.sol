pragma solidity 0.6.5;
pragma experimental ABIEncoderV2;

import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../node_modules/@openzeppelin/contracts/access/AccessControl.sol";
import "./IDigiNFT.sol";

contract DigiAuction is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeMath for uint8;

    uint256 BIGNUMBER = 10 ** 18;

    /******************
    CONFIG
    ******************/
    uint256 public purchaseFee = 1000;   // 10%
    uint256 public digiAmountRequired = 3000 * (BIGNUMBER);

    /******************
    EVENTS
    ******************/
    event CreatedAuction(uint256 auctionId, address indexed wallet, uint256 tokenId, uint256 created);
    event CanceledAuction(uint256 auctionId, address indexed wallet, uint256 tokenId, uint256 created);
    event NewHighestOffer(uint256 indexed auctionId, address indexed wallet, uint256 amount, uint256 created);
    event DirectBuyed(uint256 indexed tokenId, uint256 auctionId, address indexed wallet, uint256 amount, uint256 created);
    event Claimed(uint256 indexed tokenId, uint256 auctionId, address indexed wallet, uint256 amount, uint256 created);
    event Log(uint256 data);

    /******************
    INTERNAL ACCOUNTING
    *******************/
    address public stakeERC20;
    address public digiERC271;
    address public stableERC20;
    address[] public feesDestinators;
    uint256[] public feesPercentages;

    uint256 public auctionCount = 0;

    mapping (uint256 => Auction) public auctions;
    mapping (uint256 => bool) public claimedAuctions;
    mapping (uint256 => Offer) public highestOffers;
    mapping (uint256 => uint256) public lastAuctionByToken;
    mapping (uint256 => Royalty) public royaltiesByToken;
    struct Royalty {
        uint256 fee;
        address wallet;
    }

    struct Auction {
        uint256 tokenId;
        address owner;
        uint256 minPrice;
        uint256 fixedPrice;
        bool buyed;
        bool royalty;
        uint256 endDate;
    }

    struct Offer {
        address buyer;
        uint256 offer;
        uint256 date;
    }

    /******************
    PUBLIC FUNCTIONS
    *******************/
    constructor(
        address _stakeERC20,
        address _digiERC271,
        address _stableERC20
    )
        public
    {
        require(address(_stakeERC20) != address(0)); 
        require(address(_digiERC271) != address(0));
        require(address(_stableERC20) != address(0));

        stakeERC20 = _stakeERC20;
        digiERC271 = _digiERC271;
        stableERC20 = _stableERC20;
    }

    function setRoyaltyForToken(uint256 _tokenId, address beneficiary, uint256 _fee) external {
        require(msg.sender == IERC721(digiERC271).ownerOf(_tokenId), "DigiAuction: Not the owner");
        require(AccessControl(digiERC271).hasRole(keccak256("MINTER"), msg.sender), "DigiAuction: Not minter");
        require(lastAuctionByToken[_tokenId] == 0, "DigiAuction: Auction already created");
        require(royaltiesByToken[_tokenId].wallet == address(0), "DigiMarket: Royalty already setted");
        royaltiesByToken[_tokenId] = Royalty({
            wallet: beneficiary,
            fee: _fee
        });
    }

    /**
    * @dev User deposits DIGI NFT for auction.
    */
    function createAuction(
        uint256 _tokenId,
        uint256 _minPrice,
        uint256 _fixedPrice,
        uint256 _duration
    )
        public
        requiredAmount(msg.sender, digiAmountRequired)
        returns (uint256)
    {
        IDigiNFT(digiERC271).transferFrom(msg.sender, address(this), _tokenId);

        uint256 timeNow = _getTime();
        uint256 newAuction = auctionCount;
        auctionCount += 1;

        auctions[newAuction] = Auction({
            tokenId: _tokenId,
            owner: msg.sender,
            minPrice: _minPrice,
            fixedPrice: _fixedPrice,
            buyed: false,
            royalty: royaltiesByToken[_tokenId].wallet != address(0),
            endDate: timeNow + _duration
        });
        lastAuctionByToken[_tokenId] = newAuction;

        emit CreatedAuction(newAuction, msg.sender, _tokenId, timeNow);

        return newAuction;
    }

    /**
    * @dev User makes an offer for the DIGI NFT.
    */
    function participateAuction(uint256 _auctionId, uint256 _amount)
        public
        nonReentrant()
        inProgress(_auctionId)
        minPrice(_auctionId, _amount)
        newHighestOffer(_auctionId, _amount)
    {
        IERC20(stableERC20).transferFrom(msg.sender, address(this), _amount);

        _returnPreviousOffer(_auctionId);

        uint256 timeNow = _getTime();
        highestOffers[_auctionId] = Offer({
            buyer: msg.sender,
            offer: _amount,
            date: timeNow
        });

        emit NewHighestOffer(_auctionId, msg.sender, _amount, timeNow);
    }

    /**
    * @dev User directly buyes the DIGI NFT at fixed price.
    */
    function directBuy(uint256 _auctionId)
        public
        notClaimed(_auctionId)
        inProgress(_auctionId)
    {
        require(IERC20(stableERC20).balanceOf(msg.sender) > auctions[_auctionId].fixedPrice, 'DigiAuction: User does not have enough balance');
        require(auctions[_auctionId].fixedPrice > 0, 'DigiAuction: Direct buy not available');
        
        uint amount = auctions[_auctionId].fixedPrice;
        uint256 feeAmount = amount.mul(purchaseFee).div(10000);

        uint256 royaltyFeeAmount = 0;
        if (auctions[_auctionId].royalty) {
            royaltyFeeAmount = amount.mul(royaltiesByToken[auctions[_auctionId].tokenId].fee).div(10000);
        }
        uint256 amountAfterFee = amount.sub(feeAmount).sub(royaltyFeeAmount);

        IERC20(stableERC20).transferFrom(msg.sender, address(this), feeAmount);
        IERC20(stableERC20).transferFrom(msg.sender, auctions[_auctionId].owner, amountAfterFee);
        if (royaltyFeeAmount > 0) {
            IERC20(stableERC20).transferFrom(msg.sender, royaltiesByToken[auctions[_auctionId].tokenId].wallet, royaltyFeeAmount);
        }
        IDigiNFT(digiERC271).transferFrom(address(this), msg.sender, auctions[_auctionId].tokenId);
        
        uint256 timeNow = _getTime();
        auctions[_auctionId].buyed = true;

        claimedAuctions[_auctionId] = true;

        _returnPreviousOffer(_auctionId);

        emit DirectBuyed(auctions[_auctionId].tokenId, _auctionId, msg.sender, auctions[_auctionId].fixedPrice, timeNow);
    }

    /**
    * @dev Winner user claims DIGI NFT for ended auction.
    */
    function claim(uint256 _auctionId)
        public
        ended(_auctionId)
        notClaimed(_auctionId)
    {
        require(highestOffers[_auctionId].buyer != address(0x0), "DigiAuction: Ended without winner");

        uint256 timeNow = _getTime();
        uint256 amount = highestOffers[_auctionId].offer;
        uint256 feeAmount = amount.mul(purchaseFee).div(10000);

        uint256 royaltyFeeAmount = 0;
        if (auctions[_auctionId].royalty) {
            royaltyFeeAmount = amount.mul(royaltiesByToken[auctions[_auctionId].tokenId].fee).div(10000);
        }
        uint256 amountAfterFee = amount.sub(feeAmount).sub(royaltyFeeAmount);

        IERC20(stableERC20).transfer(auctions[_auctionId].owner, amountAfterFee);
        if (royaltyFeeAmount > 0) {
            IERC20(stableERC20).transfer(royaltiesByToken[auctions[_auctionId].tokenId].wallet, royaltyFeeAmount);
        }
        IDigiNFT(digiERC271).transferFrom(address(this), highestOffers[_auctionId].buyer, auctions[_auctionId].tokenId);

        claimedAuctions[_auctionId] = true;

        emit Claimed(auctions[_auctionId].tokenId, _auctionId, highestOffers[_auctionId].buyer, amount, timeNow);
    }

    /**
    * @dev Send all the acumulated fees for one token to the fee destinators.
    */
    function withdrawAcumulatedFees() public {
        uint256 total = IERC20(stableERC20).balanceOf(address(this));
        
        for (uint8 i = 0; i < feesDestinators.length; i++) {
            IERC20(stableERC20).transfer(
                feesDestinators[i],
                total.mul(feesPercentages[i]).div(100)
            );
        }
    }

    /**
    * @dev Cancel auction and returns token.
    */
    function cancel(uint256 _auctionId)
        public
    {
        require(auctions[_auctionId].owner == msg.sender, 'DigiAuction: User is not the token owner');
        require(highestOffers[_auctionId].buyer == address(0x0), "DigiAuction: Ended but has winner");
        require(auctions[_auctionId].buyed == false, "DigiAuction: Already buyed");

        uint256 timeNow = _getTime();

        auctions[_auctionId].endDate = timeNow;

        IDigiNFT(digiERC271).transferFrom(
            address(this),
            auctions[_auctionId].owner,
            auctions[_auctionId].tokenId
        );

        emit CanceledAuction(_auctionId, msg.sender, auctions[_auctionId].tokenId, timeNow);
    }

    /**
    * @dev Sets the purchaseFee for every withdraw.
    */
    function setFee(uint256 _purchaseFee) public onlyOwner() {
        require(_purchaseFee <= 3000, "DigiAuction: Max fee 30%");
        purchaseFee = _purchaseFee;
    }

    /**
    * @dev Configure how to distribute the fees for user's withdraws.
    */
    function setFeesDestinatorsWithPercentages(
        address[] memory _destinators,
        uint256[] memory _percentages
    )
        public
        onlyOwner()
    {
        require(_destinators.length == _percentages.length, "DigiAuction: Destinators and percentageslenght are not equals");

        uint256 total = 0;
        for (uint8 i = 0; i < _percentages.length; i++) {
            total += _percentages[i];
        }
        require(total == 100, "DigiAuction: Percentages sum must be 100");

        feesDestinators = _destinators;
        feesPercentages = _percentages;
    }

    /******************
    PRIVATE FUNCTIONS
    *******************/
    function _returnPreviousOffer(uint256 _auctionId) internal {
        Offer memory currentOffer = highestOffers[_auctionId];
        if (currentOffer.offer > 0) {
            IERC20(stableERC20).transfer(currentOffer.buyer, currentOffer.offer);
        }
    }

    function _getTime() internal view returns (uint256) {
        return block.timestamp;
    }

    /******************
    MODIFIERS
    *******************/
    modifier requiredAmount(address _wallet, uint256 _amount) {
        require(
            IERC20(stakeERC20).balanceOf(_wallet) >= _amount,
            'DigiAuction: User needs more token balance in order to do this action'
        );
        _;
    }

    modifier newHighestOffer(uint256 _auctionId, uint256 _amount) {
        require(
            _amount > highestOffers[_auctionId].offer,
            'DigiAuction: Amount must be higher'
        );
        _;
    }

    modifier minPrice(uint256 _auctionId, uint256 _amount) {
        require(
            _amount >= auctions[_auctionId].minPrice,
            'DigiAuction: Insufficient offer amount for this auction'
        );
        _;
    }

    modifier inProgress(uint256 _auctionId) {
        require(
            (auctions[_auctionId].endDate > _getTime()) && auctions[_auctionId].buyed == false,
            'DigiAuction: Auction closed'
        );
        _;
    }

    modifier ended(uint256 _auctionId) {
        require(
            (_getTime() > auctions[_auctionId].endDate) && auctions[_auctionId].buyed == false,
            'DigiAuction: Auction not closed'
        );
        _;
    }

    modifier notClaimed(uint256 _auctionId) {
        require(
            (claimedAuctions[_auctionId] == false),
            'DigiAuction: Already claimed'
        );
        _;
    }
}
