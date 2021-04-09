pragma solidity 0.6.5;
pragma experimental ABIEncoderV2;

import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract DigiDuel is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeMath for uint8;

    uint256 BIGNUMBER = 10 ** 18;

    /******************
    CONFIG
    ******************/
    uint256 public purchaseFee = 100;   // 1%

    /******************
    EVENTS
    ******************/
    event CreatedDuel(uint256 duelId, address indexed wallet, uint256 tokenId, uint256 amount, Color color, uint256 created);
    event CanceledDuel(uint256 duelId, address indexed wallet, uint256 tokenId, uint256 amount, Color color, uint256 created);
    event AcceptedDuel(uint256 duelId, address indexed wallet, uint256 tokenId, uint256 amount, Color color, uint256 created);
    event WinnedDuel(uint256 duelId, address indexed wallet, uint256 tokenIdA, uint256 tokenIdB, uint256 totalAmount, Color color, uint256 created);
    event Log(Color data);
    event Log(address data);

    /******************
    INTERNAL ACCOUNTING
    *******************/
    address public digiERC20;
    address public digiERC271;
    address[] public feesDestinators;
    uint256[] public feesPercentages;

    uint256 public duelsCount = 0;

    mapping (uint256 => Duel) public duels;
    mapping (uint256 => uint256) public lastDuelByToken;

    struct Duel {
        uint256 tokenId;
        address owner;
        uint256 amount;
        Color color;
        bool accepted;
        uint256 endDate;
    }

    enum Color {
        Black,
        Red
    }

    /******************
    PUBLIC FUNCTIONS
    *******************/
    constructor(
        address _digiERC20,
        address _digiERC271
    )
        public
    {
        require(address(_digiERC20) != address(0)); 
        require(address(_digiERC271) != address(0));

        digiERC20 = _digiERC20;
        digiERC271 = _digiERC271;
    }

    /**
    * @dev User creates duel for NFT.
    */
    function create(
        uint256 _tokenId,
        uint256 _amount,
        Color _color,
        uint256 _duration
    )
        public
        returns (uint256)
    {
        require(_color == Color.Black || _color == Color.Red, "DigiDuel: Color must be 0 (Black) or 1 (Red)");

        IERC721(digiERC271).transferFrom(msg.sender, address(this), _tokenId);
        IERC20(digiERC20).transferFrom(msg.sender, address(this), _amount);

        uint256 timeNow = _getTime();
        uint256 newDuelId = duelsCount;
        duelsCount += 1;

        duels[newDuelId] = Duel({
            tokenId: _tokenId,
            owner: msg.sender,
            amount: _amount,
            color: _color,
            accepted: false,
            endDate: timeNow + _duration
        });
        lastDuelByToken[_tokenId] = newDuelId;

        emit CreatedDuel(newDuelId, msg.sender, _tokenId, _amount, _color, timeNow);

        return newDuelId;
    }

    /**
    * @dev User cancels duel for NFT.
    */
    function cancel(
        uint256 _duelId
    )
        public
        inProgress(_duelId)
        returns (uint256)
    {
        require(duels[_duelId].owner == msg.sender, 'DigiDuel: User is not the token owner');

        uint256 timeNow = _getTime();
        duels[_duelId].endDate = timeNow;

        emit CanceledDuel(_duelId, msg.sender, duels[_duelId].tokenId, duels[_duelId].amount, duels[_duelId].color, timeNow);
    }

    /**
    * @dev User accepts duel fot NFT.
    */
    function accept(
        uint256 _duelId,
        uint256 _tokenId
    )
        public
        inProgress(_duelId)
    {
        require(IERC721(digiERC271).ownerOf(_tokenId) == msg.sender, 'DigiDuel: User is not the NFT owner');
        
        uint256 timeNow = _getTime();
        Color acceptedColor = _oppositeColor(duels[_duelId].color);

        uint256 totalAmount = duels[_duelId].amount.mul(2);
        uint256 feeAmount = totalAmount.mul(purchaseFee).div(10000);
        uint256 amountAfterFee = duels[_duelId].amount.sub(feeAmount);

        emit AcceptedDuel(_duelId, msg.sender, duels[_duelId].tokenId, duels[_duelId].amount, acceptedColor, timeNow);

        Color winnerColor = _randomColor();
        address winnerAddress = address(0x0);
        emit Log(winnerColor);
        emit Log(acceptedColor);
        if (winnerColor == acceptedColor) {
            
            winnerAddress = msg.sender;

        } else {

            winnerAddress = duels[_duelId].owner;
            IERC20(digiERC20).transferFrom(msg.sender, winnerAddress, duels[_duelId].amount);
            IERC721(digiERC271).transferFrom(msg.sender, winnerAddress, _tokenId);

        }

        duels[_duelId].accepted = true;

        IERC20(digiERC20).transfer(winnerAddress, amountAfterFee);
        IERC721(digiERC271).transferFrom(address(this), winnerAddress, duels[_duelId].tokenId);

        emit WinnedDuel(_duelId, winnerAddress, duels[_duelId].tokenId, _tokenId, amountAfterFee, winnerColor, timeNow);
    }

    /**
    * @dev Send all the acumulated fees for one token to the fee destinators.
    */
    function withdrawAcumulatedFees() public {
        uint256 total = IERC20(digiERC20).balanceOf(address(this));
        
        for (uint8 i = 0; i < feesDestinators.length; i++) {
            IERC20(digiERC20).transfer(
                feesDestinators[i],
                total.mul(feesPercentages[i]).div(100)
            );
        }
    }

    /**
    * @dev Sets the purchaseFee for every withdraw.
    */
    function setFee(uint256 _purchaseFee) public onlyOwner() {
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
        require(_destinators.length == _percentages.length, "DigiDuel: Destinators and percentageslenght are not equals");

        uint256 total = 0;
        for (uint8 i = 0; i < _percentages.length; i++) {
            total += _percentages[i];
        }
        require(total == 100, "DigiDuel: Percentages sum must be 100");

        feesDestinators = _destinators;
        feesPercentages = _percentages;
    }

    /******************
    PRIVATE FUNCTIONS
    *******************/
    function _getTime() internal view returns (uint256) {
        return block.timestamp;
    }

    function _randomNumber(uint256 _limit) internal view returns (uint256) {
        uint256 _gasleft = gasleft();
        bytes32 _blockhash = blockhash(block.number - 1);
        bytes32 _structHash = keccak256(
            abi.encode(
                _blockhash,
                _getTime(),
                _gasleft,
                _limit
            )
        );
        uint256 _randomNumber = uint256(_structHash);
        assembly {_randomNumber := add(mod(_randomNumber, _limit), 1)}
        return uint8(_randomNumber);
    }

    function _randomColor() internal view returns (Color) {
        if (_randomNumber(2) == 1) {
            return Color.Black;
        }

        return Color.Red;
    }

    function _oppositeColor(Color color) internal view returns (Color) {
        if (color == Color.Red) {
            return Color.Black;
        }

        return Color.Red;
    }

    /******************
    MODIFIERS
    *******************/
    modifier requiredAmount(address _wallet, uint256 _amount) {
        require(
            IERC20(digiERC20).balanceOf(_wallet) >= _amount,
            'DigiDuel: User needs more token balance in order to do this action'
        );
        _;
    }

    modifier inProgress(uint256 _duelId) {
        require(
            (duels[_duelId].endDate > _getTime()) && duels[_duelId].accepted == false,
            'DigiDuel: Duel ended'
        );
        _;
    }
}
