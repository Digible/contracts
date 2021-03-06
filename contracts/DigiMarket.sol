pragma solidity 0.6.5;
pragma experimental ABIEncoderV2;

import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../node_modules/@openzeppelin/contracts/access/AccessControl.sol";

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

    /******************
    INTERNAL ACCOUNTING
    *******************/
    address public stakeERC20;
    address public digiERC721;
    address public stableERC20;
    address[] public feesDestinators;
    uint256[] public feesPercentages;

    uint256 public salesCount = 0;

    mapping (uint256 => Sale) public sales;
    mapping (address => mapping (uint256 => uint256)) public lastSaleByToken;
    
    mapping (uint256 => Royalty) public royaltiesByToken;
    struct Royalty {
        uint256 fee;
        address wallet;
    }

    struct Sale {
        uint256 tokenId;
        address tokenAddress;
        address owner;
        uint256 price;
        bool royalty;
        bool buyed;
        uint256 endDate;
    }

    /******************
    PUBLIC FUNCTIONS
    *******************/
    constructor(
        address _stakeERC20,
        address _stableERC20,
        address _digiERC721
    )
        public
    {
        require(address(_stakeERC20) != address(0)); 
        require(address(_stableERC20) != address(0));
        require(address(_digiERC721) != address(0));

        stakeERC20 = _stakeERC20;
        stableERC20 = _stableERC20;
        digiERC721 = _digiERC721;
    }

    function setRoyaltyForToken(uint256 _tokenId, address beneficiary, uint256 _fee) external {
        require(msg.sender == IERC721(digiERC721).ownerOf(_tokenId), "DigiMarket: Not the owner");
        require(AccessControl(digiERC721).hasRole(keccak256("MINTER"), msg.sender), "DigiMarker: Not minter");
        require(lastSaleByToken[digiERC721][_tokenId] == 0, "DigiMarket: Auction already created");
        require(royaltiesByToken[_tokenId].wallet == address(0), "DigiMarket: Royalty already setted");
        royaltiesByToken[_tokenId] = Royalty({
            wallet: beneficiary,
            fee: _fee
        });
    }

    /**
    * @dev User creates sale for NFT.
    */
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
            royalty: _tokenAddress == digiERC721 && royaltiesByToken[_tokenId].wallet != address(0),
            buyed: false,
            endDate: timeNow + _duration
        });
        lastSaleByToken[_tokenAddress][_tokenId] = newSaleId;

        emit CreatedSale(newSaleId, msg.sender, _tokenId, _tokenAddress, timeNow);

        return newSaleId;
    }

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
        require(IERC721(sales[_saleId].tokenAddress).ownerOf(sales[_saleId].tokenId) == sales[_saleId].owner, 'DigiMarket: Sale creator user is not longer NFT owner');
        require(IERC20(stableERC20).balanceOf(msg.sender) >= sales[_saleId].price, 'DigiMarket: User does not have enough balance');
        
        uint amount = sales[_saleId].price;
        uint256 feeAmount = amount.mul(purchaseFee).div(10000);
        uint256 royaltyFeeAmount = 0;
        if (sales[_saleId].royalty) {
            royaltyFeeAmount = amount.mul(royaltiesByToken[sales[_saleId].tokenId].fee).div(10000);
        }
        uint256 amountAfterFee = amount.sub(feeAmount).sub(royaltyFeeAmount);

        ERC20(stableERC20).safeTransferFrom(msg.sender, address(this), feeAmount);
        ERC20(stableERC20).safeTransferFrom(msg.sender, sales[_saleId].owner, amountAfterFee);
    
        if (royaltyFeeAmount > 0) {
            ERC20(stableERC20).safeTransferFrom(msg.sender, royaltiesByToken[sales[_saleId].tokenId].wallet, royaltyFeeAmount);
        }
        IERC721(sales[_saleId].tokenAddress).transferFrom(sales[_saleId].owner, msg.sender, sales[_saleId].tokenId);
        
        uint256 timeNow = _getTime();
        sales[_saleId].buyed = true;

        emit SaleBuyed(_saleId, msg.sender, sales[_saleId].price, sales[_saleId].tokenId, sales[_saleId].tokenAddress, timeNow);
    }

    /**
    * @dev Send all the acumulated fees for one token to the fee destinators.
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
        require(_destinators.length == _percentages.length, "DigiMarket: Destinators and percentageslenght are not equals");

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
