// SPDX-License-Identifier: MIT
// @dev Digiwax Version 2 - packs NFTs minted from multiple smart contract by tokenId 🎁🎁🎁
pragma solidity 0.8.11;
import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/VRFConsumerBase.sol";
import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/ChainlinkClient.sol";
import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/ConfirmedOwner.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/utils/ERC721Holder.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";

contract DigiWax is VRFConsumerBase, AccessControl, ConfirmedOwner(msg.sender), ChainlinkClient, ERC721Holder {
    using SafeMath for uint256; 


    event RandomnessReceived (string indexed boxname, bytes32 indexed requestId, uint256 indexed result);
    event BoxWaxSealBroken (bytes32 indexed requestId, string indexed boxName);
    event BoxWaxSealSet (bytes32 indexed requestId, string indexed boxName);
    event WalletSubscribed(string indexed boxname, address wallet, bool usedKey);
    event BoxCreated(string indexed boxname, address boxCreator);
 
    bytes32 public constant WAXMAKER = keccak256("WAXMAKER"); //0e713d936ee004edc0a77c6094bd6a75d836bda1eece05c06df5d9ce4a89655f
    
    uint256 private BIGNUMBER = 10**18;
    bytes32 private s_keyHash;
    uint256 private s_fee;
    address private _linkAddress;   

    IERC20 public DIGI;
    uint256 public wax_fee_digi;
    uint256 public access_fee_percentage;
    address private _digiFeeCollectorAddress;
    
    mapping (string => address) public boxOwner_map;
    mapping (string => bytes32) public requestId_by_boxName_map;
    mapping (string => bool) private _requestIdDead_by_boxName_map;
    mapping (string => bool) public generalSubscriptionOpen_by_boxName_map;
    mapping (string => bool) public digikeySubscriptionOpen_by_boxName_map; 

    mapping (string => uint256) public accessPrice_by_boxName_map;
    mapping (string => address) public accessPriceContractAddress_by_boxName_map;    
   
    mapping (string => address[]) private _nftContractAddressesArr_by_boxName_map;
    mapping (string => uint256[]) private _tokensArr_by_boxName_map;
    mapping (string => address[]) private _digiKeyAddressesArr_by_boxName_map;
    mapping (string => uint256[]) private _digiKeyTokensArr_by_boxName_map;
    mapping (string => mapping (address => mapping(uint256 => bool))) private _digiKeyAllowed_byBoxName_3map;  
 
    mapping (string => address[]) public participantWallets_by_boxName_map; 
    mapping (string => mapping(address=>bool)) private _walletSubscribed_by_boxName_map;
    mapping (string => bool) public oracleSpoke_by_boxName_map;
    
    mapping (bytes32 => string) private _boxName_by_requestId_map;
    mapping (bytes32 => uint256[]) private _shuffledTokens_by_requestId_map;
    mapping (bytes32 => address[]) private _shuffledAddresses_by_requestId_map;  
  
    mapping (bytes32 => bool) public  boxSealed_By_requestId_map;
    mapping (string => bool) private _boxnameTaken_map;

    mapping (bytes32=>uint256) private  _fullfilledRandomRequests_map;    
    
    constructor() VRFConsumerBase(0x8C7382F9D8f56b33781fE506E897a4F1e2d17255, 0x326C977E6efc84E512bB9C30f76E30c160eD06FB) public {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender); 
        _setupRole(WAXMAKER, msg.sender);
        _linkAddress = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
        s_keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
        s_fee = 100000000000000;
        DIGI = IERC20(0x03d390Af242C8a8a5340489f2D2649e859d7ec2f);
        _digiFeeCollectorAddress = msg.sender;
        wax_fee_digi = 50 * BIGNUMBER;  
        access_fee_percentage = 10;           
    }

// ["0xd9145CCE52D386f254917e481eB44e9943F39138","0xd9145CCE52D386f254917e481eB44e9943F39138"]
// [1,2]
// 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4

    function createBox (string memory boxName, 
                        address nftContractAddress, uint256 start_tokenId, uint256 end_tokenId,                        
                        address digiKeyContractAddress,  uint256 start_keyTokenId, uint256 end_keyTokenId,
                        address accessPriceContractAddress, uint256 accessPrice
                        )                         
            public payable returns (bool) {

        require(hasRole(WAXMAKER, msg.sender), "Only for WAXMAKER");
        require(!_boxnameTaken_map[boxName], "Set name taken");    
        require(LINK.balanceOf(address(this)) >= s_fee, "Not enough LINK to offer oralce");
        require(DIGI.transferFrom(msg.sender, _digiFeeCollectorAddress, wax_fee_digi), "DIGI Fee XFer failed");      
        _boxnameTaken_map[boxName] = true;
        boxOwner_map[boxName] = msg.sender;
        if(end_keyTokenId > 0) { enableDigikeys(boxName, digiKeyContractAddress, start_keyTokenId, end_keyTokenId); }  
        if(accessPrice > 0) {
            accessPriceContractAddress_by_boxName_map[boxName] = accessPriceContractAddress;
            accessPrice_by_boxName_map[boxName] = accessPrice;

        }
        packBox(boxName, nftContractAddress, start_tokenId, end_tokenId);
        emit BoxCreated(boxName, msg.sender);     
        return true;
    }

    function packBox (string memory boxName, address nftContractAddress, uint256 start_tokenId, uint256 end_tokenId) 
            public payable returns (bool) {
       
        require(boxOwner_map[boxName] == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "For Box Owner Only");
        require(_boxnameTaken_map[boxName], "Box Does Not Exist");

        for (uint256 i = start_tokenId; i <= end_tokenId; i++) {
            require(IERC721(nftContractAddress).ownerOf(i) == msg.sender, "Not Owner");
            IERC721(nftContractAddress).safeTransferFrom(msg.sender, address(this), i);
            _nftContractAddressesArr_by_boxName_map[boxName].push(nftContractAddress);
            _tokensArr_by_boxName_map[boxName].push(i);
        }             
        return true;    
    }

    // @dev - THIS IS WHERE WE REQUEST RANDOMNESS FROM THE CHAINLINK ORACLE
    function sealWax (string memory boxName) public returns (bytes32){
    
        require(participantWallets_by_boxName_map[boxName].length == _tokensArr_by_boxName_map[boxName].length, "Participant count wrong");
        require(boxOwner_map[boxName] == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "For Box Owner Only");
        
        bytes32 requestId = requestRandomness(s_keyHash, s_fee); 
             
        requestId_by_boxName_map[boxName] = requestId;
        _boxName_by_requestId_map[requestId] = boxName;
        boxSealed_By_requestId_map[requestId] = true;
        emit BoxWaxSealSet(requestId, boxName);
        return requestId;                         
    }         

    function breakWax_Box (string memory boxName)  public returns(address[] memory, uint256[] memory){
       
       require(boxOwner_map[boxName] == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "For Box Owner Only");
       require (!_requestIdDead_by_boxName_map[boxName], "Box was undone");   
       require(_boxnameTaken_map[boxName], "No such box");  
       require(oracleSpoke_by_boxName_map[boxName], "Oracle Hasn't Shuffled Box Yet");   
       bytes32 requestId = requestId_by_boxName_map[boxName];

       string memory boxName = _boxName_by_requestId_map[requestId];
        uint256 qtyTokens = _tokensArr_by_boxName_map[boxName].length;
        require (!_requestIdDead_by_boxName_map[boxName], "Box was undone");        
        require(participantWallets_by_boxName_map[boxName].length == qtyTokens, "Participant count wrong");
        require(boxOwner_map[boxName] == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "For box owner only");
       
        //@dev shuffle tokens 
        uint256 randomness = _fullfilledRandomRequests_map[requestId];       
        uint256[] memory randoms = new uint256[](qtyTokens);
        for (uint256 i = 0; i < qtyTokens; i++) {
                 randoms[i] = uint256(keccak256(abi.encode(randomness, i)));
        }
  
        uint256[] memory tokenArr = new uint256[](qtyTokens);
        address[] memory addressArr = new address[](qtyTokens);
        tokenArr = _tokensArr_by_boxName_map[boxName];
        addressArr = _nftContractAddressesArr_by_boxName_map[boxName];
         
        for (uint256 i = 0; i < qtyTokens; i++) { 
           uint256 n =  randoms[i] % (qtyTokens - 1);
           uint256 tempT = tokenArr[n];
           address tempA = addressArr[n];
           tokenArr[n] = tokenArr[i];
           addressArr[n] = addressArr[i];
           tokenArr[i] = tempT;
           addressArr[i] = tempA;
        }
        
        _shuffledTokens_by_requestId_map[requestId] = tokenArr;
        _shuffledAddresses_by_requestId_map[requestId] = addressArr;   


        //@dev distribute tokens to wallets

        for (uint256 i = 0; i < _shuffledTokens_by_requestId_map[requestId].length; i++)
        {
            IERC721 nft = IERC721(_shuffledAddresses_by_requestId_map[requestId][i]);
            uint256 tokenId = _shuffledTokens_by_requestId_map[requestId][i];
            nft.safeTransferFrom(address(this), participantWallets_by_boxName_map[boxName][i], tokenId);
        } 

        return (addressArr, tokenArr);
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
        string memory boxName = _boxName_by_requestId_map[requestId];
        emit RandomnessReceived(boxName, requestId, randomness);       
        oracleSpoke_by_boxName_map[boxName] = true;     
        _fullfilledRandomRequests_map[requestId] = randomness;
      
     

    }


        //@dev owner/admin can add keys
        
    function enableDigikeys(string memory boxName, address digiKeyContractAddress, uint256 start_keyTokenId, uint256  end_keyTokenId) public  {
     
      require(boxOwner_map[boxName] == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "For Box Owner Only"); 
      
       
        for (uint256 i = start_keyTokenId; i <= end_keyTokenId; i++) {
            _digiKeyAddressesArr_by_boxName_map[boxName].push(digiKeyContractAddress);
            _digiKeyTokensArr_by_boxName_map[boxName].push(i);         
            _digiKeyAllowed_byBoxName_3map[boxName][digiKeyContractAddress][i] = true;
        }  
    }
    
    function updateSubscriptionsByBox(string memory boxName, bool isOpen_Gen, bool isOpen_Key) public {
        require(boxOwner_map[boxName] == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "For Box Owner Only");     
        generalSubscriptionOpen_by_boxName_map[boxName] = isOpen_Gen;
          digikeySubscriptionOpen_by_boxName_map[boxName] = isOpen_Key;
    }

         
    //@undos all packs in box and returns NFTs to original owner
    function undoBoxByName(string memory boxName) public returns (bool){
        require(boxOwner_map[boxName] == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "For Box Owner Only");     
        require(_boxnameTaken_map[boxName], "No such box name");
       
        for (uint256 i = 0; i <  _tokensArr_by_boxName_map[boxName].length; i++) {
            IERC721(_nftContractAddressesArr_by_boxName_map[boxName][i]).safeTransferFrom(address(this), boxOwner_map[boxName],  _tokensArr_by_boxName_map[boxName][i]);            
        }
        _requestIdDead_by_boxName_map[boxName] = true; 
      return true;
    }  
    
    //@dev This is where wallets enter the box participation
    function subscribeWalletToBoxByName (string memory boxName, address subscriber ) public returns (bool){
        require(generalSubscriptionOpen_by_boxName_map[boxName], "General Subscription is not open yet!");
        require(!_walletSubscribed_by_boxName_map[boxName][subscriber] || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Wallet Already Subscribed");
        require(participantWallets_by_boxName_map[boxName].length < _tokensArr_by_boxName_map[boxName].length, "No More Spots Left");
        IERC20 feeToken = IERC20(accessPriceContractAddress_by_boxName_map[boxName]);
        uint256 fee_amount = accessPrice_by_boxName_map[boxName].mul(access_fee_percentage).div(100);
        uint256 net_amount = accessPrice_by_boxName_map[boxName].mul(100 - access_fee_percentage).div(100);
        require(accessPrice_by_boxName_map[boxName] == 0 || (
             feeToken.transferFrom(msg.sender, _digiFeeCollectorAddress, fee_amount) &&
             feeToken.transferFrom(msg.sender, boxOwner_map[boxName], net_amount)), "Access Fees XFR Failed");
    

        participantWallets_by_boxName_map[boxName].push(subscriber);
        _walletSubscribed_by_boxName_map[boxName][subscriber] =true;
        emit WalletSubscribed(boxName, subscriber, false);
        return true;
    }

// @dev this is where wallets enter using digiKey
    function subscribeWalletToBoxByRequestIdUsingKey (string memory boxName, address subscriber, address digiKeyContractAddress, uint digikeyTokenId ) public returns (bool){
          
        require(digikeySubscriptionOpen_by_boxName_map[boxName], "Key Subscription is not open yet!");
        require( _digiKeyAllowed_byBoxName_3map[boxName][digiKeyContractAddress][digikeyTokenId], "Key was already used or non-existant");
        require(participantWallets_by_boxName_map[boxName].length < _tokensArr_by_boxName_map[boxName].length, "No More Spots Left");
        require (IERC721(digiKeyContractAddress).ownerOf(digikeyTokenId) == subscriber, "Subscriber not owner of the Key");
        participantWallets_by_boxName_map[boxName].push(subscriber);
        _digiKeyAllowed_byBoxName_3map[boxName][digiKeyContractAddress][digikeyTokenId] = false;
        emit WalletSubscribed(boxName, subscriber, true);
        return true;
    }

   
  
   



  //@dev ONLY OWNER FUNCTIONS
   
  
    function setFeeAndKeyHash(uint256 fee, bytes32 keyHash) public onlyOwner {
        s_fee = fee;
        s_keyHash = keyHash;
    }

   function withdrawGas(address tokenContract)  public onlyOwner {    
    
    IERC20 token = IERC20(tokenContract);
    require(token.transfer(msg.sender, token.balanceOf(address(this))), "Unable to transfer");
  }

    function setDigiFees(uint256 human_fee, uint256 human_percentage)  public onlyOwner {
    wax_fee_digi = human_fee * BIGNUMBER;
    access_fee_percentage = human_percentage;
  }




    function oraclize(string memory boxName, uint256 randomness) public onlyOwner {    
    require(_boxnameTaken_map[boxName], "No such box");    
      bytes32 requestId = requestId_by_boxName_map[boxName];
      _fullfilledRandomRequests_map[requestId] = randomness;
        oracleSpoke_by_boxName_map[boxName] = true;
        emit RandomnessReceived(boxName, requestId, randomness);
  }   


 //@dev gives more random numbers from number using chainlink best practices guide
  
   function expand(uint256 randomValue, uint256 n) public  pure returns (uint256[] memory expandedValues) {
    expandedValues = new uint256[](n);
    for (uint256 i = 0; i < n; i++) {
        expandedValues[i] = uint256(keccak256(abi.encode(randomValue, i)));
        }
    return expandedValues;

}


}

     /**
     * @notice Constructor uses one NFT contrtact address and inherits VRFConsumerBase
     * @dev   https://docs.chain.link/docs/vrf-contracts/
     * @dev   NETWORK: KOVAN
     * @dev   nftContractAddress: 0x4e4e06dfB3aCD27e6a96fEc7458726EEc5b487d0
     * @dev   Chainlink VRF Coordinator address: 0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9
     * @dev   LINK token address:                0xa36085F69e2889c224210F603D836748e7dC0088
     * @dev   Link Key Hash:    0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4
     * @dev   Fee:        0.1 LINK (100000000000000000)
     * 
     * @dev Network: POLYGON MUMBAI:	
     *           nftContractAddress: 0x2050ebd262Db421De662607A05be26930Edbb8C8
                                     0x74980E3A1323DE715BD660f9f8D263ED8B631D92;    

     *           VRF Coordinator	0x8C7382F9D8f56b33781fE506E897a4F1e2d17255
     *           LINK Token	0x326C977E6efc84E512bB9C30f76E30c160eD06FB
     *           Key Hash	0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4
     *           Fee:        0.0001  LINK (100000000000000)
     * 
     *       Network: Binance Smart Chain Testnet:	
     *           nftContractAddress: 0x2050ebd262Db421De662607A05be26930Edbb8C8            
     *           VRF Coordinator	0xa555fC018435bef5A13C6c6870a9d4C11DEC329C
     *           LINK Token	0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06
     *           Key Hash	0xcaf3c3727e033261d383b315559476f48034c13b18f8cafed4d871abe5049186
     *           Fee:        0.1  LINK (100000000000000000)
     * 
     * 
     * 
     * 
     *
     * vrfCoordinator address of the VRF Coordinator
     * link address of the LINK token
     * keyHash bytes32 representing the hash of the VRF job
     *  fee uint256 fee to pay the VRF oracle
     */
     
     

    
/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/docs/link-token-contracts/
 */