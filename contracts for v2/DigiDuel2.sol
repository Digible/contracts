// SPDX-License-Identifier: MIT
// @dev DIGIDUEL Version 2a 
//  
// CHALLENGER VS DEFENDER
// CHAINLINK ORACLE 
// COLOR WIN ALGORITHM (~50/50);
// CHALLENGER PUTS UP A PRIZE CARD ALONG WITH AN ENEREGY CARD vd
// DEFENDER PUTS UP THEIR OWN PRICE CARD WITH ENERGY CARD.
// CHALLENGER IS ASSIGNED COLOR RED
// DEFENDER IS ASSIGNED COLOR BLUE
// THE DUEL:
// *** IF CHAINLINK-ALGO SAYS "RED" 
// * * CHALLENGER WINS THE DEFENDER'S PRIZE CARD BUT.
// ** DEFENDER WINS THE CHALLENGERS ENERGY CARD.
// ** IF THE RESULT IS  "BLUE" THEN
// ** DEFENDER WIN'S THE CHALLANGER'S PRIZE CARD
// ** 
// Duels start at index 1. Index 0 for duelTotalyNftAddressAndTokenId means no duel
pragma solidity 0.8.11;

import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/VRFConsumerBase.sol";
import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/ChainlinkClient.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/utils/ERC721Holder.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol";

contract DigiDuel2 is VRFConsumerBase,
 AccessControl,
  ChainlinkClient, 
  ERC721Holder, 
  ReentrancyGuard {
    using SafeMath for uint256; 

    // ChainlinkConfiguration
   uint256 private BIGNUMBER = 10**18;
    bytes32 private s_keyHash;
    uint256 private s_fee;
    address public _linkAddress;  


 /******************
    EVENTS
    ******************/
    event IChallangeYou(uint256 duelId, address indexed challanger_wallet, address your_prize_nftAddress, uint256 your_prize_tokenId, uint256 endDate, string challengersMessage);

    event CxlDuel(uint256 duelId, address indexed wallet, uint256 tokenId, uint256 amount, Color color, uint256 created);
    event ChallengeAccepted(uint256 duelId, address indexed wallet, uint256 tokenId, uint256 amount, Color color, uint256 created);
    event WinnerDeclared(uint256 duelId, address indexed wallet, uint256 tokenIdA, uint256 tokenIdB, uint256 totalAmount, Color color, uint256 created);

    // Access Fee Accounting 

    IERC20 public DIGI;
    uint256 public wax_fee_digi; // TODO
    uint256 public access_fee_percentage; // TODO
    address private _digiFeeCollectorAddress; // TODO


    // guts

    bytes32 public constant CHALLENGER = keccak256("CHALLENGER"); //
    
   mapping (address => Duel) duels_byWallet;
   mapping(address => mapping(uint256 => Duel)) lastDuelbyNftAddressAndTokenId;



    mapping (uint256 => Duel) public duels;
    uint256 public duelsCount = 0;




    // Stats
   
     mapping (address => uint256) public duelsWon_byWallet; 
     mapping (address => uint256) public duelsTotal_byWallet;
     mapping(address => mapping(uint256 => uint256)) duelsWonByNftAddressAndTokenId;
     mapping(address => mapping(uint256 => uint256)) duelTotalyNftAddressAndTokenId;



    struct Duel {
        address wallet_ch;
        address prize_nftAddress_ch;
        uint256 prize_tokenId_ch;
        address energy_nftAddress_ch;
        uint256 energy_tokenId_ch;
    
        Color color;
        address wallet_def;
        address prize_nftAddress_def;
        uint256 prize_tokenId_def;
        address energy_nftAddress_def;
        uint256 energy_tokenId_def;
       
        string challangersMessage;
        address winner;
        uint256 endDate;
    }

    enum Color {
        Blue,
        Red,
        Unknown
    }


function createChallange(address _prize_nftAddress_ch, 
uint256 _prize_tokenId_ch, address _energy_nftAddress_ch, 
uint256 _energy_tokenId_ch,
address _prize_nftAddress_def,
uint256 _prize_tokenId_def,

uint256 _duration,
string calldata _challengersMessage
) public {
 
 require(hasRole(CHALLENGER, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "No Challenger Status");     
        duelsCount += 1; // to start at 1
        
        uint256 newDuelId = duelsCount; 
        uint256 _endDate = block.timestamp + _duration;
      

 duels[newDuelId] = Duel({
            wallet_ch: msg.sender,
            prize_nftAddress_ch: _prize_nftAddress_ch,
            prize_tokenId_ch: _prize_tokenId_ch,
            energy_nftAddress_ch: _energy_nftAddress_ch,
            energy_tokenId_ch: _energy_tokenId_ch,

            
            color: Color.Unknown,

            wallet_def: address(0x0),
            prize_nftAddress_def : _prize_nftAddress_def,
            prize_tokenId_def: _prize_tokenId_def,
            energy_nftAddress_def: address(0x0),
            energy_tokenId_def: 0,
            challengersMessage: _challengersMessage,
            winner: address(0x0),
            endDate: _endDate
        });


     duels_byWallet[msg.sender]  =  duels[newDuelId];
     lastDuelbyNftAddressAndTokenId[_prize_nftAddress_ch][_prize_tokenId_ch] = duels[newDuelId];
 

    emit IChallangeYou(newDuelId, msg.sender, _prize_nftAddress_def,  _prize_tokenId_def,  _endDate, _challengersMessage);


}







 constructor() VRFConsumerBase(0x8C7382F9D8f56b33781fE506E897a4F1e2d17255, 0x326C977E6efc84E512bB9C30f76E30c160eD06FB)  {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender); 
        _setupRole(CHALLENGER, msg.sender);
        _linkAddress = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
        s_keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
        s_fee = 100000000000000;
        DIGI = IERC20(0x03d390Af242C8a8a5340489f2D2649e859d7ec2f);
        _digiFeeCollectorAddress = msg.sender;
        wax_fee_digi = 50 * BIGNUMBER;  
        access_fee_percentage = 10;           
    }


 //@ dev ORACLE HAS SPOKEN: CHAINLINK VRF CALLS THIS fulfillRandomness FUNCTION:
        
     /**
     * @notice Callback function used by VRF Coordinator to return the random number
     * to this contract.
     * @dev Some action on the contract state should be taken here, like storing the result.
     * @dev WARNING: take care to avoid having multiple VRF requests in flight if their order of arrival would result
     * in contract states with different outcomes. Otherwise miners or the VRF operator would could take advantage
     * by controlling the order.
     * @dev The VRF Coordinator will only send this function verified responses, and the parent VRFConsumerBase
     * contract ensures that this method only receives randomness from the designated VRFCoordinator.
     *
     * @param requestId bytes32
     * @param randomness The random result returned by the oracle
     */
     
   

 function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
       
     

    }






}
