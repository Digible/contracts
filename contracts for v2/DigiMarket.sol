pragma solidity ^0.8.9;
 
pragma experimental ABIEncoderV2;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";

/**
    * @dev DigiMarket Contract V2.
    https://docs.google.com/document/d/1mTGGCsUWOWlN2WYTfvALJwirnKwW7vRQwh8ar8eIQCA/edit#
    */

contract DigiMarket is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeMath for uint8;
    using SafeERC20 for ERC20;

    uint256 BIGNUMBER = 10 ** 18;

    /******************
    CONFIG
    ******************/
    uint256 public purchaseFee = 1000;   // 10%
    uint256 public digiAmountRequired = 3000 * (BIGNUMBER);

    /******************
    EVENTS
    ******************/
    event CreatedSale(uint256 saleId, address indexed wallet, uint256 tokenId, address tokenAddress, uint256 created);
    event CanceledSale(uint256 saleId, address indexed wallet, uint256 tokenId, address tokenAddress, uint256 created);
    event SaleBuyed(uint256 saleId, address indexed wallet, uint256 amount, uint256 indexed tokenId, address indexed tokenAddress, uint256 created); 
    event CreatedOffer(uint256 saleId, address indexed wallet, uint256 tokenId, address tokenAddress, uint256 created);
    event OfferAccepted(uint offerId, address indexed wallet, uint256 amount, address paymentCurrencyAddress, uint256 tokenId, address tokenAddress, uint256 created);

 
    /******************
    INTERNAL ACCOUNTING
    *******************/
    address public digiERC721; //@the legacy default Digi Smart Contract 
    address public stakeERC20; //@the required token
    address   public stableERC20; //@the payment token.
    address[] public feesDestinators;
    uint256[] public feesPercentages;
    mapping (address => bool) public currenciesUsed_map;
    uint256 public salesCount = 0;
    uint256 public offerCount = 0;
    mapping (uint256 => Sale) public sales;
    mapping (uint256 => Offer) public offers;
    mapping (address => mapping (uint256 => uint256)) public lastSaleByToken;    
    mapping (address => mapping (uint256 => uint256)) public lastOfferByToken;  
    mapping (address => mapping(uint256 => Royalty)) public royaltiesByTokenByContractAddress;

    struct Royalty {
        uint256 fee;
        address wallet;
    }

    struct Sale {
        uint256 tokenId;
        address tokenAddress;
        address owner;
        uint256 price;
        address paymentcurrencyAddress;
        bool royalty;
        bool buyed;
        uint256 endDate;
    }

      struct Offer {
        uint256 tokenId;
        address tokenAddress;
        address owner;
        uint256 price;
        address paymentcurrencyAddress;
        uint256 requestedNftTokenId;
        address requestedNftAddress;
        address offererAddress;
        bool accepted;
        uint256 endDate;
    }

    /******************
    PUBLIC FUNCTIONS
    *******************/
    // constructor(
    //     address _stakeERC20,
    //     address _stableERC20,
    //     address _digiERC721_default
    // )
    //     public
    // {
    //     require(address(_stakeERC20) != address(0)); 
    //     require(address(_stableERC20) != address(0));
    //     require(address(_digiERC721_default) != address(0));

    //     stakeERC20 = _stakeERC20;
    //     stableERC20 = _stableERC20;
    //     digiERC721 = _digiERC721_default;
    // }


    constructor(
        
    )
        public 
    {
        stakeERC20 = 0xd9145CCE52D386f254917e481eB44e9943F39138; //@dev utility token $DIGI address
        stableERC20 = 0xd9145CCE52D386f254917e481eB44e9943F39138; //@dev default currency token (i.e. USDT)
        digiERC721 = 0xf8e81D47203A594245E36C48e151709F0C19fBe8; //@dev default DIGI NFT address (should be current)
    }

// @dev sets royalty for primary DIGInft contract - legacy
    function setRoyaltyForToken(uint256 _tokenId, address beneficiary, uint256 _fee) external {
        require(msg.sender == IERC721(digiERC721).ownerOf(_tokenId), "DigiMarket: Not the owner");
        require(AccessControl(digiERC721).hasRole(keccak256("MINTER"), msg.sender), "DigiMarket: Not minter");
        require(lastSaleByToken[digiERC721][_tokenId] == 0, "DigiMarket:  The market for token was already established");
        require(royaltiesByTokenByContractAddress[digiERC721][_tokenId].wallet == address(0), "DigiMarket: Royalty was already set");
        royaltiesByTokenByContractAddress[digiERC721][_tokenId] = Royalty({
            wallet: beneficiary,
            fee: _fee
        });
    }


// @dev sets royalty for any contract 
    function setRoyaltyforTokenAny(uint256 _tokenId, address beneficiary, 
    uint256 _fee, address _contractAddress) 
    external {
        
        require(msg.sender == (IERC721)(_contractAddress).ownerOf(_tokenId), "DigiMarket: Not the owner");
        require(AccessControl(_contractAddress).hasRole(keccak256("MINTER"), msg.sender), "DigiMarket: Not minter");
        require(lastSaleByToken[_contractAddress][_tokenId] == 0, "DigiMarket: Auction already created");
        require(royaltiesByTokenByContractAddress[_contractAddress][_tokenId].wallet == address(0), "DigiMarket: Royalty already set");
        royaltiesByTokenByContractAddress[_contractAddress][_tokenId] = Royalty({
            wallet: beneficiary,
            fee: _fee
        });
    }

    /**
    * @dev User creates sale for NFT using default currency (legacy var: stableERC20)
    */
   
    /**
    * @dev User cancels sale for NFT.
    */
    function cancelSale(
        uint256 _saleId
    )
        public
        inProgress(_saleId)
        returns (uint256)
    {
        require(IERC721(sales[_saleId].tokenAddress).ownerOf(sales[_saleId].tokenId) == msg.sender, 'DigiMarket: User is not the token owner');

        uint256 timeNow = _getTime();
        sales[_saleId].endDate = timeNow;

        emit CanceledSale(_saleId, msg.sender, sales[_saleId].tokenId, sales[_saleId].tokenAddress, timeNow);
    }

    /**
    * @dev User buyes the NFT.
    */
    function buy(uint256 _saleId)
        public
        inProgress(_saleId)
    {
        address tokenAddress = sales[_saleId].tokenAddress;
        require(ERC721 (tokenAddress).ownerOf(sales[_saleId].tokenId) == sales[_saleId].owner, "DigiMarket: Sale creator user is no longer NFT owner");
        ERC20 puchaseCurrency = ERC20(sales[_saleId].paymentcurrencyAddress);
        require(puchaseCurrency.balanceOf(msg.sender) >= sales[_saleId].price, "DigiMarket: User does not have enough balance");
        
        uint amount = sales[_saleId].price;
        uint256 feeAmount = amount.mul(purchaseFee).div(10000);
        uint256 royaltyFeeAmount = 0;
        if (sales[_saleId].royalty) {
            royaltyFeeAmount = amount.mul(royaltiesByTokenByContractAddress[tokenAddress][sales[_saleId].tokenId].fee).div(10000);
        }
        uint256 amountAfterFee = amount.sub(feeAmount).sub(royaltyFeeAmount);

        puchaseCurrency.safeTransferFrom(msg.sender, address(this), feeAmount);
        puchaseCurrency.safeTransferFrom(msg.sender, sales[_saleId].owner, amountAfterFee);
    
        if (royaltyFeeAmount > 0) {
            puchaseCurrency.safeTransferFrom(msg.sender, royaltiesByTokenByContractAddress[digiERC721][sales[_saleId].tokenId].wallet, royaltyFeeAmount);
        }
        IERC721(sales[_saleId].tokenAddress).transferFrom(sales[_saleId].owner, msg.sender, sales[_saleId].tokenId);
        
        uint256 timeNow = _getTime();
        sales[_saleId].buyed = true;

        emit SaleBuyed(_saleId, msg.sender, sales[_saleId].price, sales[_saleId].tokenId, sales[_saleId].tokenAddress, timeNow);
    }

    function createSale(
        uint256 _tokenId,
        address _tokenAddress,
        uint256 _price,
        uint256 _duration
    )
        public
        requiredAmount(msg.sender, digiAmountRequired)
        returns (uint256)
    {
        return createSaleAnyCurrency(_tokenId,_tokenAddress,_price,_duration, stableERC20);
               
    }

    
    function createSaleAnyCurrency(
        uint256 _tokenId,
        address _tokenAddress,
        uint256 _price,
        uint256 _duration,
        address _currencyAddress
    )
        public
        requiredAmount(msg.sender, digiAmountRequired)
        returns (uint256)
    {
        require(IERC721(_tokenAddress).ownerOf(_tokenId) == msg.sender, 'DigiMarket: User is not the token owner');
        require(IERC721(_tokenAddress).isApprovedForAll(msg.sender, address(this)), 'DigiMarket: DigiMarket contract address must be approved for transfer');

        uint256 timeNow = _getTime();
        uint256 newSaleId = salesCount;
       
        salesCount += 1;

        sales[newSaleId] = Sale({
            tokenId: _tokenId,
            tokenAddress: _tokenAddress,
            owner: msg.sender,
            price: _price,
            royalty: royaltiesByTokenByContractAddress[digiERC721][_tokenId].wallet != address(0),
            buyed: false,
            endDate: timeNow + _duration,
            paymentcurrencyAddress: _currencyAddress
        });
        lastSaleByToken[_tokenAddress][_tokenId] = newSaleId;
        if(!currenciesUsed_map[_currencyAddress]){
            currenciesUsed_map[_currencyAddress] == true;
        }

        emit CreatedSale(newSaleId, msg.sender, _tokenId, _tokenAddress, timeNow);

        return newSaleId;
    }

    function makeTradeOffer(
        address _requestedNftAddress,
        uint256 _requestedNftTokenId,
        uint256 _tokenId,
        address _tokenAddress,
        address _currencyAddress,
        uint256 _currencyOfferQty,        
        uint256 _duration
       
    )
        public
        requiredAmount(msg.sender, digiAmountRequired)
        returns (uint256)
    {
        require(_tokenAddress == address(0) || IERC721(_tokenAddress).ownerOf(_tokenId) == msg.sender, 'DigiMarket: User is not the token owner');
        require(_tokenAddress == address(0) ||IERC721(_tokenAddress).isApprovedForAll(msg.sender, address(this)), 'DigiMarket: DigiMarket contract address must be approved for transfer');
        require(_currencyOfferQty == 0 || IERC20(_currencyAddress).balanceOf(msg.sender) >= _currencyOfferQty, "Digimarket: User does not have enough of offer currency");
        require (_tokenAddress != address(0) || _currencyOfferQty > 0, "You haven't offered anything");

        uint256 timeNow = _getTime();
        uint256 newOfferId = offerCount;
       
        offerCount += 1;

        offers[newOfferId] = Offer({
            requestedNftTokenId : _requestedNftTokenId,
            requestedNftAddress : _requestedNftAddress,
            owner: msg.sender,
            tokenId: _tokenId,
            tokenAddress: _tokenAddress,
            paymentcurrencyAddress: _currencyAddress,
            price: _currencyOfferQty,
            offererAddress: msg.sender,
            endDate: timeNow + _duration,
            accepted: false   
                 
           
        });
        lastOfferByToken[_requestedNftAddress][_requestedNftTokenId] = newOfferId;
        if(!currenciesUsed_map[_currencyAddress]){
            currenciesUsed_map[_currencyAddress] == true;
        }

        emit CreatedOffer(newOfferId, msg.sender, _requestedNftTokenId, _requestedNftAddress, timeNow);

        return newOfferId;
    }




    function acceptOffer(uint256 _offerId)
        public
        
    {
        Offer memory offer = offers[_offerId];
        //@ dev check if Offerer (offererAddress) still has the NFT and Token they offered; checks if the Oferree(msg.sender) still owns the nft
        require(IERC721(offer.requestedNftAddress).ownerOf(offer.requestedNftTokenId) == msg.sender, "DigiMarket: You no longer are the NFT owner");
        require(IERC721(offer.requestedNftAddress).isApprovedForAll(msg.sender, address(this)), 'DigiMarket: DigiMarket contract address must be approved for transfer');
        require (offer.requestedNftAddress == address(0) || IERC721(offer.requestedNftAddress).ownerOf(offer.tokenId) == offer.offererAddress, "Digimarket: The offerer no longer owns the NFT they offered");
        require (offer.price == 0 || IERC20(offer.paymentcurrencyAddress).balanceOf(offer.offererAddress) >= offer.price, "Digimarket: The offerer no longer has enough tokens they offered");
        
        
        uint amount = offer.price;
        uint256 feeAmount = amount.mul(purchaseFee).div(10000);
        uint256 royaltyFeeAmount = 0;
        Royalty memory royalty = royaltiesByTokenByContractAddress[offer.requestedNftAddress][offer.requestedNftTokenId];
        if (royalty.fee > 0) {
            royaltyFeeAmount = amount.mul(royalty.fee).div(10000);
        }
        uint256 amountAfterFee = amount.sub(feeAmount).sub(royaltyFeeAmount);
        ERC20 puchaseCurrency = ERC20(offer.paymentcurrencyAddress);
        
        //@dev Offeror sends Tokens and offered NFT
        puchaseCurrency.safeTransferFrom(offer.offererAddress, address(this), feeAmount);
        puchaseCurrency.safeTransferFrom(offer.offererAddress, offer.owner, amountAfterFee);    
        if (royaltyFeeAmount > 0) {
            puchaseCurrency.safeTransferFrom(offer.offererAddress, royalty.wallet, royaltyFeeAmount);
        }
        IERC721(offer.tokenAddress).transferFrom(offer.offererAddress, msg.sender, offer.tokenId);
        //@dev Offeree sends the NFT
        IERC721(offer.requestedNftAddress).transferFrom(msg.sender, offer.offererAddress, offer.requestedNftTokenId);
        uint256 timeNow = _getTime();
        offer.accepted = true;

        emit OfferAccepted(_offerId, msg.sender, offer.price, offer.paymentcurrencyAddress, offer.requestedNftTokenId, offer.requestedNftAddress, timeNow);
    }

    /**
    * @dev Send all the acumulated fees for default (legacy) to the fee destinators.
    */
    function withdrawAcumulatedFees() public {
        uint256 total = IERC20(stableERC20).balanceOf(address(this));
        
        for (uint8 i = 0; i < feesDestinators.length; i++) {
            ERC20(stableERC20).safeTransfer(
                feesDestinators[i],
                total.mul(feesPercentages[i]).div(100)
            );
        }
    }

  function withdrawAcumulatedFeesByToken(address token) public {
        require (currenciesUsed_map[token], "Token was not used in sales");
        uint256 total = IERC20(token).balanceOf(address(this));
        
        for (uint8 i = 0; i < feesDestinators.length; i++) {
            ERC20(token).safeTransfer(
                feesDestinators[i],
                total.mul(feesPercentages[i]).div(100)
            );
        }
    }



    /**
    * @dev Send all the acumulated fees for default (legacy) to the fee destinators.
    */
   
    /**
    * @dev Sets the purchaseFee for every withdraw.
    */
    function setFee(uint256 _purchaseFee) public onlyOwner() {
        require(_purchaseFee <= 3000, "DigiMarket: Max fee 30%");
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
        require(_destinators.length == _percentages.length, "DigiMarket: Destinators and percentages lenght are not equals");

        uint256 total = 0;
        for (uint8 i = 0; i < _percentages.length; i++) {
            total += _percentages[i];
        }
        require(total == 100, "DigiMarket: Percentages sum must be 100");

        feesDestinators = _destinators;
        feesPercentages = _percentages;
    }

    /******************
    PRIVATE FUNCTIONS
    *******************/
    function _getTime() internal view returns (uint256) {
        return block.timestamp;
    }

    /******************
    MODIFIERS
    *******************/
    modifier requiredAmount(address _wallet, uint256 _amount) {
        require(
            IERC20(stakeERC20).balanceOf(_wallet) >= _amount,
            'DigiMarket: User needs more token balance in order to do this action'
        );
        _;
    }

    modifier inProgress(uint256 _saleId) {
        require(
            (sales[_saleId].endDate > _getTime()) && sales[_saleId].buyed == false,
            'DigiMarket: Sale ended'
        );
        _;
    }

    
}
