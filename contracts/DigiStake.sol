pragma solidity 0.6.5;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract DigiStake is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeMath for uint8;
    using SafeMath for uint;

    event Claimed(address indexed wallet, address indexed rewardToken, uint amount);
    event Rewarded(address indexed rewardToken, uint amount, uint totalStaked, uint date);
    event Stake(address indexed wallet, uint amount, uint date);
    event Withdraw(address indexed wallet, uint amount, uint date);
    event Log(uint256 data);

    uint BIGNUMBER = 10**18;

    mapping (address => uint) public stakeMap;
    mapping (address => uint) public userClaimableRewardPerStake;

    uint256 public totalRewards;
    uint256 public tokenTotalStaked;
    uint256 public tokenCummulativeRewardPerStake;
    address public stakingToken;
    address public rewardToken;

    constructor(address _stakingToken, address _rewardToken) public {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
    }

    function staked(address _staker) external view returns (uint) {
        return stakeMap[_staker];
    }

    function _stake(uint _amount) internal returns (bool){
        require(_amount != 0, "Amount can't be 0");
        require(IERC20(stakingToken).transferFrom(msg.sender, address(this), _amount), "DigiStake: Must allow the ERC20 first");

        if (stakeMap[msg.sender] == 0) {
            stakeMap[msg.sender] = _amount;
            userClaimableRewardPerStake[msg.sender] = tokenCummulativeRewardPerStake;
        }else{
            _claim();
            stakeMap[msg.sender] = stakeMap[msg.sender].add(_amount);
        }
        tokenTotalStaked = tokenTotalStaked.add(_amount);
        emit Stake(msg.sender, _amount, getTime());
        return true;
    }

    /**
    * @dev pay out dividends to stakers, update how much per token each staker can claim
    */
    function distribute() public returns (bool) {
        require(tokenTotalStaked != 0, "DigiStake: Total staked must be more than 0");

        uint256 currentBalance = IERC20(rewardToken).balanceOf(address(this));

        if (currentBalance == 0) {
            return false;
        }

        uint256 reward = currentBalance.sub(totalRewards);
        totalRewards = totalRewards.add(reward);

        if (totalRewards == 0) {
            return false;
        }

        tokenCummulativeRewardPerStake += reward.mul(BIGNUMBER) / tokenTotalStaked;
        emit Rewarded(rewardToken, reward, tokenTotalStaked, getTime());
        return true;
    }

    function calculateReward(address _staker) public returns (uint) {
        distribute();

        uint stakedAmount = stakeMap[_staker];
        //the amount per token for this user for this claim
        uint amountOwedPerToken = tokenCummulativeRewardPerStake.sub(userClaimableRewardPerStake[_staker]);
        uint claimableAmount = stakedAmount.mul(amountOwedPerToken); //total amount that can be claimed by this user
        claimableAmount = claimableAmount.div(BIGNUMBER); //simulate floating point operations
        return claimableAmount;
    }

    function _withdraw() internal returns (bool){
        require(stakeMap[msg.sender] > 0, "DigiStake: Amount can't be 0");
        _claim();
        uint _amount = stakeMap[msg.sender];

        stakeMap[msg.sender] = 0;
        tokenTotalStaked = tokenTotalStaked.sub(_amount);
        require(IERC20(stakingToken).transfer(msg.sender, _amount), "DigiStake: Transfer failed");
        emit Withdraw(msg.sender, _amount, getTime());
        return true;
    }

    /**
    * @dev claim dividends for a particular token that user has stake in.
    */
    function _claim() internal returns (uint) {
        uint claimableAmount = calculateReward(msg.sender);
        if (claimableAmount == 0) {
            return claimableAmount;
        }
        userClaimableRewardPerStake[msg.sender] = tokenCummulativeRewardPerStake;
        require(IERC20(rewardToken).transfer(msg.sender, claimableAmount), "DigiStake: Transfer failed");

        totalRewards = totalRewards.sub(claimableAmount);

        emit Claimed(msg.sender, rewardToken, claimableAmount);
        return claimableAmount;
    }

    function getTime() internal view returns (uint256) {
        // solhint-disable-next-line not-rely-on-time
        return now;
    }

    function stake(uint _amount) external nonReentrant returns (bool) {
        return _stake(_amount);
    }

    /**
    * @dev claim dividends for a particular token that user has stake in
    */
    function claim() external returns (uint) {
        return _claim();
    }

    /**
    * @dev withdraw and claim dividends for a particular token that user has stake in
    */
    function withdraw() external nonReentrant returns (bool){
        return _withdraw();
    }
}