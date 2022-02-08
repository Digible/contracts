pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
import "https://github.com/Digible/contracts/blob/contractsV2/contracts%20for%20v2/DigiTrack.sol";

contract DigiMarketAndAuction is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    uint256 BIGNUMBER = 10**18;

    /******************
    CONFIG
    ******************/
    uint256 public purchaseFee = 1000; // 10%
    uint256 public digiAmountRequired = 3000 * (BIGNUMBER);
    address public digiTrackAddress;
    bool public marketLive = true;

    /******************
    EVENTS AUCTION
    ******************/
    event CreatedAuction(
        uint256 saleId,
        address indexed wallet,
        address indexed nftContractAddress,
        uint256 tokenId,
        uint256 created
    );
    event CanceledAuction(
        uint256 indexed saleId,
        address indexed wallet,   
        uint256 created
    );
    event NewHighestOffer(
        uint256 indexed saleId,
        address indexed wallet,     
        uint256 amount,
        uint256 created
    );
    event DirectBought(
        uint256 indexed saleId,        
        address indexed wallet,
        address indexed nftContractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 created
    );
    event Claimed(
        uint256 indexed saleId,        
        address indexed wallet,
        address indexed nftContractAddress,
        uint256 tokenId,      
        uint256 created
    );
   

    event NewSaleIdCreated(
        uint256 indexed saleId,
        address indexed wallet,
        address tokenAddress,
        uint256 tokenId,        
        uint256 created
    );
    event SaleCXL(
        uint256 indexed saleId,
        address indexed wallet,
        address tokenAddress,
        uint256 tokenId,       
        uint256 created
    );
 
    event Refunded(
        uint256 indexed saleId,
        address indexed sellersWallet,
        address buyerWallet,            
        uint256 created
    );

    /******************
    INTERNAL ACCOUNTING
    *******************/
    address public digiERC20;

    address[] public feesDestinators;
    uint256[] public feesPercentages;

    uint256 public salesCount;
  
    mapping(uint256 => bool) public claimedAuctions;
    mapping (uint256 => Offer) public highestOffers;
    mapping (uint256 => Offer[]) public offersArr;
    mapping(address => mapping(uint256 => uint256)) public lastAuctionByTokenByContract;
    mapping(address => mapping(uint256 => Royalty)) public royaltiesByTokenByContract;
    mapping(uint256 => Sale) public sales;
    mapping(address => mapping(uint256 => uint256)) public lastSaleByToken;
    mapping(address => uint256) public accumulatedFeesByCurrency;
    mapping(uint256 => address) public buyerBySaleId; 


    struct Royalty {
        uint256 fee;
        address wallet;        
    }

    struct Sale {
        address nftContractAddress;
        uint256 tokenId;
        address owner;
        bool isAuction;
        uint256 minPrice;
        uint256 fixedPrice;
        address paymentCurrency;       
        bool royalty;
        uint256 endDate;
        bool paymentClaimed;
        bool royaltyClaimed;
        uint256 finalPrice;       
        bool refunded;
    }

      struct Offer {
        address buyer;
        uint256 offer;
        uint256 date;
    }

    constructor(address _digi,  address _digiTrackAddress) public payable {
        require(address(_digi) != address(0) && _digiTrackAddress != address(0));
        digiERC20 = _digi;
        digiTrackAddress = _digiTrackAddress;
    }

    /**
     * @dev User deposits DIGI NFT for auction.
     */
    function createAuction(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _minPrice,
        uint256 _fixedPrice,
        address _paymentCurrency,
        uint256 _duration
    )
        external
        payable
        requiredAmount(msg.sender, digiAmountRequired)
        returns (uint256)
    {
        require(_paymentCurrency != address(0));
        require (marketLive, "Market closed");

        // Transfer NFT into 
        IERC721(_nftContractAddress).transferFrom(
            msg.sender,
            address(this),
            _tokenId
        );

        uint256 timeNow = _getTime();
        uint256 newAuction = salesCount;
        salesCount += 1;

        sales[newAuction] = Sale({
            nftContractAddress: _nftContractAddress,
            tokenId: _tokenId,
            owner: msg.sender,
            isAuction: true,
            minPrice: _minPrice,
            fixedPrice: _fixedPrice,
            paymentCurrency: _paymentCurrency,           
            royalty: royaltiesByTokenByContract[_nftContractAddress][_tokenId]
                .wallet != address(0),
            endDate: timeNow + _duration,
            paymentClaimed: false,
            royaltyClaimed: false,    
            finalPrice: 0,    
            refunded: false
        });
        lastAuctionByTokenByContract[_nftContractAddress][
            _tokenId
        ] = newAuction;

        if(royaltiesByTokenByContract[_nftContractAddress][_tokenId].wallet == address(0)){
            royaltiesByTokenByContract[_nftContractAddress][_tokenId].wallet = msg.sender;
        }
        emit CreatedAuction(newAuction, msg.sender ,_nftContractAddress, _tokenId, timeNow);

        return newAuction;
    }

    /**
     * @dev User makes an offer for the DIGI NFT.
     */
    function participateAuction(uint256 _auctionId, uint256 _amount)
        external
        payable
        nonReentrant
        inProgress(_auctionId)
        minPrice(_auctionId, _amount)
        newHighestOffer(_auctionId, _amount)
    {
        require (marketLive, "Market closed");
        require(sales[_auctionId].isAuction, "Not and auction");
        IERC20(sales[_auctionId].paymentCurrency).transferFrom(
            msg.sender,
            address(this),
            _amount
        );

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
        payable
        nonReentrant
        notClaimed(_auctionId)
        inProgress(_auctionId)
    {
        require (marketLive, "Market closed");
        require(IERC20(sales[_auctionId].paymentCurrency).balanceOf(msg.sender) > sales[_auctionId].fixedPrice, "Not enough balance");
        require(sales[_auctionId].fixedPrice > 0, "Direct buy unavailable");   
        uint256 feeAmount = sales[_auctionId].fixedPrice.mul(purchaseFee).div(10000);  
        sales[_auctionId].finalPrice = sales[_auctionId].fixedPrice;    
        buyerBySaleId[_auctionId]  = msg.sender;
                
        // 1. SEND AUCTION GAS TO DIGI (THIS ADDRESS)

        IERC20(sales[_auctionId].paymentCurrency).transferFrom(
            msg.sender,
            address(this),
            feeAmount
        );

        

        // 2. Send Payments to Seller/Escrow, Royalty/Escrow (2 xfers)
        processPayment(
            _auctionId,
            sales[_auctionId].nftContractAddress,
            sales[_auctionId].tokenId,  
            sales[_auctionId].owner,             
            sales[_auctionId].paymentCurrency, 
            sales[_auctionId].fixedPrice,
            msg.sender
        );

        //3. Send NFT to winner 
        IERC721(sales[_auctionId].nftContractAddress).transferFrom(
            address(this),
            msg.sender,
            sales[_auctionId].tokenId
        );
        
        uint256 timeNow = _getTime();
        sales[_auctionId].finalPrice = sales[_auctionId].fixedPrice;
        claimedAuctions[_auctionId] = true;
        _returnPreviousOffer(_auctionId);

        emit DirectBought(
            _auctionId,
            msg.sender,
            sales[_auctionId].nftContractAddress,
            sales[_auctionId].tokenId,           
            sales[_auctionId].fixedPrice,
            timeNow
        );
    }


    function processPayment(uint256 saleId, address nftContractAddress, uint256 tokenId, address seller,  address paymentCurrency, uint256 grossAmount, address senderOfPayment) internal  {
        
        uint256 feeAmount = grossAmount.mul(purchaseFee).div(10000);
        uint256 royaltyFeeAmount = 0;
    
        if (sales[saleId].royalty) {
            royaltyFeeAmount = grossAmount
                .mul(royaltiesByTokenByContract[sales[saleId].nftContractAddress][sales[saleId].tokenId].fee)
                    .div(10000);
        }
    
        uint256 netAmount = grossAmount.sub(feeAmount).sub(royaltyFeeAmount);                   
        
        address _receiverOfPayment = address(this);        
        address _receiverOfRoyalty = address(this);
        string memory digiSafeStatus = DigiTrack(digiTrackAddress).getStatus(nftContractAddress, tokenId);
                


        // Check if DigiSafeStatus (escrow or seller)
        if (
            !IDigiNFT(nftContractAddress).cardPhysical(tokenId) || 
            keccak256(abi.encodePacked((digiSafeStatus))) == keccak256(abi.encodePacked(("Digisafe - Redemption Ready"))) ||
            keccak256(abi.encodePacked((digiSafeStatus))) == keccak256(abi.encodePacked(("Digisafe - Pending Grade")))
           ) {           
                _receiverOfPayment = seller;
                _receiverOfRoyalty = royaltiesByTokenByContract[nftContractAddress][tokenId].wallet;                
                sales[saleId].paymentClaimed = true;
                sales[saleId].royaltyClaimed = true;  
                accumulatedFeesByCurrency[paymentCurrency] = accumulatedFeesByCurrency[paymentCurrency].add(feeAmount);  
            }


        // 1. Send Payment to Seller or Escrow if Phygital and not in DigiSafe

        if(senderOfPayment != _receiverOfPayment){
        IERC20(paymentCurrency).transferFrom(
            senderOfPayment,
            _receiverOfPayment,
            netAmount
        );

        }

        // 2. Send Royalty to Beneficiary or Escrow 

        if(senderOfPayment != _receiverOfPayment) {
        if (royaltyFeeAmount > 0) {
            IERC20(paymentCurrency).transferFrom(
                msg.sender,
                _receiverOfRoyalty,
                royaltyFeeAmount
            );
        }   

        }

        
    }


    /**
     * @dev Winner user claims DIGI NFT for ended auction.
     */
    function claim(uint256 _auctionId)
        external
        nonReentrant
        ended(_auctionId)
        notClaimed(_auctionId)
    {
        require(highestOffers[_auctionId].buyer != address(0x0), "No bids");

        uint256 timeNow = _getTime();
        sales[_auctionId].finalPrice = highestOffers[_auctionId].offer;
        buyerBySaleId[_auctionId]  = msg.sender;

        // 1. Send Payments to Seller/Escrow, Royalty/Escrow (2 xfers)
        processPayment(
            _auctionId,
            sales[_auctionId].nftContractAddress,
            sales[_auctionId].tokenId,  
            sales[_auctionId].owner,  
            sales[_auctionId].paymentCurrency, 
            highestOffers[_auctionId].offer, 
            address(this)
        );
        
        //3. Transfer NFT to new Owner
        IERC721(sales[_auctionId].nftContractAddress).transferFrom(
            address(this),
            highestOffers[_auctionId].buyer,
            sales[_auctionId].tokenId
        );

        claimedAuctions[_auctionId] = true;

        emit Claimed(
            _auctionId,
            highestOffers[_auctionId].buyer,
            sales[_auctionId].nftContractAddress,
            sales[_auctionId].tokenId,         
            timeNow
        );
    }



    /**
     * @dev Cancel auction and returns token.
     */
    function cancel(uint256 _auctionId) external nonReentrant {
        require(
            sales[_auctionId].owner == msg.sender || msg.sender == owner(),
            "DigiAuction: User is not the token owner"
        );
        require(highestOffers[_auctionId].buyer == address(0x0), "Has bids");
        require(sales[_auctionId].finalPrice == 0, "Already bought");

        uint256 timeNow = _getTime();

        sales[_auctionId].endDate = timeNow;

        IERC721(sales[_auctionId].nftContractAddress).transferFrom(
            address(this),
            sales[_auctionId].owner,
            sales[_auctionId].tokenId
        );

        emit CanceledAuction(
            _auctionId,
            msg.sender,                       
            timeNow
        );
    }

// MKTPLACE

    function createSaleAnyCurrency(
        uint256 _tokenId,
        address _tokenAddress,
        uint256 _price,
        uint256 _duration,
        address _currencyAddress
    )
        external
        nonReentrant
        requiredAmount(msg.sender, digiAmountRequired)
        returns (uint256)
    {
        require (marketLive, "Market closed");
        require(IERC721(_tokenAddress).ownerOf(_tokenId) == msg.sender, "Not owner");
        require(IERC721(_tokenAddress).isApprovedForAll(msg.sender, address(this)), "Not Approved");
        
        uint256 timeNow = _getTime();
        uint256 newSaleId = salesCount;
       
        salesCount += 1;

        sales[newSaleId] = Sale({
            nftContractAddress: _tokenAddress,
            tokenId: _tokenId,
            owner: msg.sender,
            isAuction: false,
            minPrice: _price,
            fixedPrice: _price,
            paymentCurrency: _currencyAddress,
            royalty: royaltiesByTokenByContract[_tokenAddress][_tokenId].wallet != address(0),           
            endDate: timeNow + _duration,
            paymentClaimed: false,
            royaltyClaimed: false,   
            finalPrice: 0,         
            refunded: false
            
        });
        lastSaleByToken[_tokenAddress][_tokenId] = newSaleId;
       

        if(royaltiesByTokenByContract[_tokenAddress][_tokenId].wallet == address(0)){
            royaltiesByTokenByContract[_tokenAddress][_tokenId].wallet = msg.sender;
        }

        emit NewSaleIdCreated(newSaleId, msg.sender, _tokenAddress, _tokenId,  timeNow);

        return newSaleId;
    }


  function cancelSale( uint256 _saleId)
        public
        inProgress(_saleId)
        
    {
        require(IERC721(sales[_saleId].nftContractAddress).ownerOf(sales[_saleId].tokenId) == msg.sender || msg.sender == owner(), "Not Owner");
        uint256 timeNow = _getTime();
        sales[_saleId].endDate = timeNow;

        emit SaleCXL(_saleId, msg.sender, sales[_saleId].nftContractAddress, sales[_saleId].tokenId,  timeNow);

    }

    
    function claimPaymentAmount(uint256 saleId) external nonReentrant {

         require(!sales[saleId].paymentClaimed, "Payment Already Claimed");
         require(sales[saleId].finalPrice > 0, "No Sale Made");
         string memory digiSafeStatus = DigiTrack(digiTrackAddress).getStatus(sales[saleId].nftContractAddress, sales[saleId].tokenId);
         require(
            keccak256(abi.encodePacked((digiSafeStatus))) == keccak256(abi.encodePacked(("Digisafe - Redemption Ready"))) ||
            keccak256(abi.encodePacked((digiSafeStatus))) == keccak256(abi.encodePacked(("Digisafe - Pending Grade"))),
            "Not In Digisafe - Can't Claim Yet");            
        
        sales[saleId].paymentClaimed = true; 
        uint256 royaltyFeeAmount = 0;
    
        if (sales[saleId].royalty) {
            royaltyFeeAmount = sales[saleId].finalPrice
                .mul(royaltiesByTokenByContract[sales[saleId].nftContractAddress][sales[saleId].tokenId].fee)
                    .div(10000);
        }
        uint256 feeAmount = sales[saleId].finalPrice.mul(purchaseFee).div(10000);   
        uint256 netAmount = sales[saleId].finalPrice.sub(feeAmount).sub(royaltyFeeAmount);                   
        
        
        IERC20(sales[saleId].paymentCurrency).transfer(sales[saleId].owner, netAmount);
        accumulatedFeesByCurrency[sales[saleId].paymentCurrency] = accumulatedFeesByCurrency[sales[saleId].paymentCurrency].add(feeAmount);
        
    }

    
    function setRoyaltyForToken(
        address nftContractAddress,
        uint256 _tokenId,
        address beneficiary,
        uint256 _fee
        ) external {
        require(msg.sender == IERC721(nftContractAddress).ownerOf(_tokenId) || msg.sender == owner(),  "Not the owner");
        require(lastAuctionByTokenByContract[nftContractAddress][_tokenId] == 0 && lastSaleByToken[nftContractAddress][_tokenId] == 0, "Market already set");
        require(royaltiesByTokenByContract[nftContractAddress][_tokenId].wallet == address(0), "Royalty already set");
        royaltiesByTokenByContract[nftContractAddress][_tokenId] = Royalty({
            wallet: beneficiary,
            fee: _fee         
        });
    }


    function claimRoyalty(uint256 saleId) external nonReentrant{
     require(!sales[saleId].royaltyClaimed, "Royalty Already Claimed");
     require (sales[saleId].royalty, "No Royalty Set");
     string memory digiSafeStatus = DigiTrack(digiTrackAddress).getStatus(sales[saleId].nftContractAddress, sales[saleId].tokenId);
     require(
            keccak256(abi.encodePacked((digiSafeStatus))) == keccak256(abi.encodePacked(("Digisafe - Redemption Ready"))) ||
            keccak256(abi.encodePacked((digiSafeStatus))) == keccak256(abi.encodePacked(("Digisafe - Pending Grade"))),
            "Not In Digisafe - Can't Claim Yet"); 
    uint256  royaltyFeeAmount = sales[saleId].finalPrice
                .mul(royaltiesByTokenByContract[sales[saleId].nftContractAddress][sales[saleId].tokenId].fee)
                    .div(10000);
     sales[saleId].royaltyClaimed = true;  
     IERC20(sales[saleId].paymentCurrency).transfer(royaltiesByTokenByContract[sales[saleId].nftContractAddress][sales[saleId].tokenId].wallet, royaltyFeeAmount);          
          

    }

    function refund(uint256 saleId) external nonReentrant onlyOwner {
    require(!sales[saleId].paymentClaimed, "Payment Already Claimed");
    require(sales[saleId].finalPrice > 0, "No Sale Made");
    require(buyerBySaleId[saleId] != address(0), "No Buyer");
    string memory digiSafeStatus = DigiTrack(digiTrackAddress).getStatus(sales[saleId].nftContractAddress, sales[saleId].tokenId);
    require(
            keccak256(abi.encodePacked((digiSafeStatus))) == keccak256(abi.encodePacked(("Rejected"))),
            "DigiTrack Status not Rejected - Cannot Refund");
    IERC20(sales[saleId].paymentCurrency).transfer(buyerBySaleId[saleId], sales[saleId].finalPrice);

    uint256 timeNow = _getTime();
    emit Refunded(saleId, sales[saleId].owner, buyerBySaleId[saleId], timeNow);




    }


/**
     * @dev Send all the acumulated fees for one token to the fee destinators.
     */
    function withdrawAcumulatedFees(address _currency) external nonReentrant onlyOwner {
        uint256 total = accumulatedFeesByCurrency[_currency];

        for (uint8 i = 0; i < feesDestinators.length; i++) {
            IERC20(_currency).transfer(
                feesDestinators[i],
                total.mul(feesPercentages[i]).div(100)
            );
        }

        accumulatedFeesByCurrency[_currency] = 0;

    }


    /**
     * @dev Sets the purchaseFee for every withdraw.
     */
    function setFee(uint256 _purchaseFee) external onlyOwner {
        require(_purchaseFee <= 3000, "Max fee 30%");
        purchaseFee = _purchaseFee;
    }

    /**
     * @dev Configure how to distribute the fees for user's withdraws.
     */
    function setFeesDestinatorsWithPercentages(
        address[] memory _destinators,
        uint256[] memory _percentages
    ) external onlyOwner {
        require(
            _destinators.length == _percentages.length,
            "DigiAuction: Destinators and percentageslenght are not equals"
        );

        uint256 total = 0;
        for (uint8 i = 0; i < _percentages.length; i++) {
            total += _percentages[i];
        }
        require(total == 100, "DigiAuction: Percentages sum must be 100");

        feesDestinators = _destinators;
        feesPercentages = _percentages;
    }

    //@dev set digi requirement using lots of 0s
    function setDigiRequirement(uint256 digis1018) external onlyOwner {
        digiAmountRequired = digis1018;
    }

     function setMarketStatus(bool _marketLive) external  onlyOwner {

        marketLive = _marketLive;

    }

    /******************
    PRIVATE FUNCTIONS
    *******************/
    function _returnPreviousOffer(uint256 _auctionId) internal {
        Offer memory currentOffer = highestOffers[_auctionId];
        if (currentOffer.offer > 0) {
            IERC20(sales[_auctionId].paymentCurrency).transfer(
                currentOffer.buyer,
                currentOffer.offer
            );
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
            IERC20(digiERC20).balanceOf(_wallet) >= _amount,
            "DigiAuction: User needs more token balance in order to do this action"
        );
        _;
    }

    modifier newHighestOffer(uint256 _auctionId, uint256 _amount) {
        require(
            _amount > highestOffers[_auctionId].offer,
            "DigiAuction: Amount must be higher"
        );
        _;
    }

    modifier minPrice(uint256 _auctionId, uint256 _amount) {
        require(
            _amount >= sales[_auctionId].minPrice,
            "DigiAuction: Insufficient offer amount for this auction"
        );
        _;
    }

    modifier inProgress(uint256 _auctionId) {
        require(
            (sales[_auctionId].endDate > _getTime()) &&
                sales[_auctionId].finalPrice == 0,
            "DigiAuction: Auction closed"
        );
        _;
    }

    modifier ended(uint256 _auctionId) {
        require(
            (_getTime() > sales[_auctionId].endDate) &&
                sales[_auctionId].finalPrice == 0,
            "DigiAuction: Auction not closed"
        );
        _;
    }

    modifier notClaimed(uint256 _auctionId) {
        require(
            (claimedAuctions[_auctionId] == false),
            "DigiAuction: Already claimed"
        );
        _;
    }
}
interface IDigiNFT {
    

    function cardPhysical(uint256 tokenId) external view returns (bool);

}
