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
    event NewSaleIdCreated(uint256 saleId, address indexed wallet, uint256 tokenId, address tokenAddress, uint256 created);
    event SaleCXL(uint256 saleId, address indexed wallet, uint256 tokenId, address tokenAddress, uint256 created);
    event Bought(uint256 saleId, address indexed wallet, uint256 amount, uint256 indexed tokenId, address indexed tokenAddress, uint256 created);     
    

 
    /******************
    INTERNAL ACCOUNTING
    *******************/
    address public digiERC20;
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

    constructor( address _digi
        
    )
        public 
    {
        // stakeERC20 = 0xd9145CCE52D386f254917e481eB44e9943F39138; //@dev utility token $DIGI address
        // stableERC20 = 0xd9145CCE52D386f254917e481eB44e9943F39138; //@dev default currency token (i.e. USDT)
        // digiERC721 = 0xf8e81D47203A594245E36C48e151709F0C19fBe8; //@dev default DIGI NFT address (should be current)



        digiERC20 = _digi;
  


    }



// @dev sets royalty for any contract 
    function setRoyaltyforTokenAny(uint256 _tokenId, address beneficiary, 
    uint256 _fee, address _contractAddress) 
    external {
        
        require(msg.sender == (IERC721)(_contractAddress).ownerOf(_tokenId), "DigiMarket: Not the owner");
    
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

        emit SaleCXL(_saleId, msg.sender, sales[_saleId].tokenId, sales[_saleId].tokenAddress, timeNow);
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
            puchaseCurrency.safeTransferFrom(msg.sender, royaltiesByTokenByContractAddress[tokenAddress][sales[_saleId].tokenId].wallet, royaltyFeeAmount);
        }
        IERC721(sales[_saleId].tokenAddress).transferFrom(sales[_saleId].owner, msg.sender, sales[_saleId].tokenId);
        
        uint256 timeNow = _getTime();
        sales[_saleId].buyed = true;

        emit Bought(_saleId, msg.sender, sales[_saleId].price, sales[_saleId].tokenId, sales[_saleId].tokenAddress, timeNow);
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
            royalty: royaltiesByTokenByContractAddress[_tokenAddress][_tokenId].wallet != address(0),
            buyed: false,
            endDate: timeNow + _duration,
            paymentcurrencyAddress: _currencyAddress
        });
        lastSaleByToken[_tokenAddress][_tokenId] = newSaleId;
        if(!currenciesUsed_map[_currencyAddress]){
            currenciesUsed_map[_currencyAddress] == true;
        }

        emit NewSaleIdCreated(newSaleId, msg.sender, _tokenId, _tokenAddress, timeNow);

        return newSaleId;
    }



    /**
    * @dev Send all the acumulated fees for default (legacy) to the fee destinators.
    */


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
            IERC20(digiERC20).balanceOf(_wallet) >= _amount,
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
