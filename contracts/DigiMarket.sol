pragma solidity 0.6.5;
pragma experimental ABIEncoderV2;

import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract DigiMarket is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeMath for uint8;

    uint256 BIGNUMBER = 10 ** 18;

    /******************
    CONFIG
    ******************/
    uint256 public purchaseFee = 500;   // 5%
    uint256 public digiAmountRequired = 3000 * (BIGNUMBER);

    /******************
    EVENTS
    ******************/
    event CreatedSale(uint256 saleId, address indexed wallet, uint256 tokenId, address tokenAddress, uint256 created);
    event CanceledSale(uint256 saleId, address indexed wallet, uint256 tokenId, address tokenAddress, uint256 created);
    event SaleBuyed(uint256 saleId, address indexed wallet, uint256 amount, uint256 created);
    event Log(uint256 data);

    /******************
    INTERNAL ACCOUNTING
    *******************/
    address public stakeERC20;
    address public digiERC271;
    address public stableERC20;
    address[] public feesDestinators;
    uint256[] public feesPercentages;

    uint256 public salesCount = 0;

    mapping (uint256 => Sale) public sales;
    mapping (address => mapping (uint256 => uint256)) public lastSaleByToken;

    struct Sale {
        uint256 tokenId;
        address tokenAddress;
        address owner;
        uint256 price;
        bool buyed;
        uint256 endDate;
    }

    /******************
    PUBLIC FUNCTIONS
    *******************/
    constructor(
        address _stakeERC20,
        address _stableERC20
    )
        public
    {
        require(address(_stakeERC20) != address(0)); 
        require(address(_stableERC20) != address(0));

        stakeERC20 = _stakeERC20;
        stableERC20 = _stableERC20;
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
        require(IERC20(stableERC20).balanceOf(msg.sender) > sales[_saleId].price, 'DigiMarket: User does not have enough balance');
        
        uint amount = sales[_saleId].price;
        uint256 feeAmount = amount.mul(purchaseFee).div(10000);
        uint256 amountAfterFee = amount.sub(feeAmount);

        IERC20(stableERC20).transferFrom(msg.sender, address(this), feeAmount);
        IERC20(stableERC20).transferFrom(msg.sender, sales[_saleId].owner, amountAfterFee);
        IERC721(sales[_saleId].tokenAddress).transferFrom(sales[_saleId].owner, msg.sender, sales[_saleId].tokenId);
        
        uint256 timeNow = _getTime();
        sales[_saleId].buyed = true;

        emit SaleBuyed(_saleId, msg.sender, sales[_saleId].price, timeNow);
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
