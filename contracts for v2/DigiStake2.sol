pragma solidity 0.8.11;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol";

contract DigiStake2 is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    uint256 private BIGNUMBER = 10**18;

    event Stake(address indexed wallet, uint256 amount, uint256 date);
    event Withdraw(address indexed wallet, uint256 amount, uint256 date);
    event Claim(address indexed wallet, uint256 amount, uint256 date);    

    mapping(address => uint256) public stakeMap;
    mapping(address => uint256) public rewardMap;

    address[] public stakerWallets_arr;

    address public stakingToken;
    bool public allow_Stake;
    bool public allow_Withdrawal;
    uint256 public tokenTotalStaked;
    uint256 public stakeCap;
    uint256 public entryFee_bps;

//2.5%
// DIGI CAP 1MM




    constructor(address _stakingToken) public {
        stakingToken = _stakingToken;
        allow_Stake = true;
        stakeCap = 1000 * BIGNUMBER;
        entryFee_bps = 0;
        allow_Withdrawal = true;
      
    }

    function submitReward(uint256 _amount) external payable returns (bool) {
        require(
            IERC20(stakingToken).transferFrom(
                msg.sender,
                address(this),
                _amount
            ),
            "DigiStake: Must allow the ERC20 first"
        );

        uint256 rewardBalance = _amount;

        for (uint256 i = 0; i < stakerWallets_arr.length; i++) {
            uint256 stakedAmount = stakeMap[stakerWallets_arr[i]];
            uint256 reward = 0;
            if (i < stakerWallets_arr.length - 1) {
                reward = stakedAmount
                    .mul(BIGNUMBER)
                    .mul(rewardBalance)
                    .div(tokenTotalStaked)
                    .div(BIGNUMBER);
            } else {
                reward = rewardBalance;
            }

            rewardMap[stakerWallets_arr[i]] = rewardMap[stakerWallets_arr[i]]
                .add(reward);
            rewardBalance = rewardBalance.sub(reward);
        }
    }

    function _stake(uint256 _amount) internal returns (bool) {
        require(allow_Stake, "Staking is closed now.");
       
        require(_amount != 0, "Amount 0");
        uint256 _fee = _amount.mul(entryFee_bps).div(10000);
        uint256 _netAmount = _amount - _fee;
        require(tokenTotalStaked + _netAmount <= stakeCap, "Over Max Limit.");

        require(
            IERC20(stakingToken).transferFrom(
                msg.sender,
                address(this),
                _netAmount
            ),
            "Must allow ERC20 first"
        );
        if (_fee > 0) {
            require(
                IERC20(stakingToken).transferFrom(msg.sender, owner(), _fee),
                "Must allow ERC20 first"
            );
        }

        if (stakeMap[msg.sender] == 0) {
            stakerWallets_arr.push(msg.sender);
        }
        stakeMap[msg.sender] = stakeMap[msg.sender].add(_netAmount);

        tokenTotalStaked = tokenTotalStaked.add(_netAmount);
        emit Stake(msg.sender, _netAmount, getTime());
        return true;
    }

    function _withdraw() internal returns (bool) {
        require(allow_Withdrawal, "W/D aren't open yet");
        require(stakeMap[msg.sender] > 0, "Staker Balance is 0");
        uint256 _amount = stakeMap[msg.sender];
        stakeMap[msg.sender] = 0;

        tokenTotalStaked = tokenTotalStaked.sub(_amount);

        require(
            IERC20(stakingToken).transfer(msg.sender, _amount),
            "W/D: Xfer fail"
        );
        _claim();
        emit Withdraw(msg.sender, _amount, getTime());
        return true;
    }

    
    /**
     * @dev claim dividends for a particular token that user has stake in.
     */

    function _claim() internal returns (bool) {
        uint256 _amount = rewardMap[msg.sender];
        rewardMap[msg.sender] = -0;
        require(
            IERC20(stakingToken).transfer(msg.sender, _amount),
            "Claim: Xfer fail"
        );
        emit Claim(msg.sender, _amount, getTime());
    }


    function getTime() internal view returns (uint256) {
        return block.timestamp;
    }

    function stake(uint256 _amount)
        external
        payable
        nonReentrant
        returns (bool)
    {
        return _stake(_amount);
    }

    /**
     * @dev withdraw and claim dividends for a particular token that user has stake in
     */
    function withdraw() external payable nonReentrant returns (bool) {
        return _withdraw();
    }

    function staked(address _staker) external view returns (uint256) {
        return stakeMap[_staker];
    }

    function allowStaking(bool allow) external onlyOwner {
        allow_Stake = allow;
    }

    function allowWithDrawal(bool allow) external onlyOwner {
        allow_Withdrawal = allow;
    }
}
