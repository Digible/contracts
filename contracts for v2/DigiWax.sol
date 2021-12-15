// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;


import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/VRFConsumerBase.sol";
import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/ChainlinkClient.sol";
import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/ConfirmedOwner.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/utils/ERC721Holder.sol";


/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/docs/link-token-contracts/
 */

// @dev Digiwax Version 1 - packs NFTs minted from the same smart contract by tokenId

contract DigiWaxPacks is VRFConsumerBase, AccessControl, ConfirmedOwner(msg.sender), ReentrancyGuard, ChainlinkClient, ERC721Holder {
        using Counters for Counters.Counter;
    
    Counters.Counter private _packIDs;
    bytes32 private s_keyHash;
    uint256 private s_fee;
    address private _linkAddress;
    address private _digiKeyAddress;

    mapping (bytes32 => address) _nftContractAddress_by_requestId_map;
    mapping (uint256 => string) private _boxName_by_packId_map;
    mapping (string => bytes32) private _requestId_by_boxName_map;
    mapping (uint256 => bytes32) private _requestId_by_packId_map;
    mapping (string => bool) private _boxnameTaken_map;
    mapping (bytes32=>uint256) private  _fullfilledRandomRequests_map;
    mapping (bytes32=>uint256[]) private _tokensArr_by_requestId_map;
    mapping (bytes32 => uint256) private _qtyofPacks_by_requestId_map;
    mapping (bytes32 => uint256) private _startingpack_by_requestId_map;
    mapping (bytes32 => mapping (uint256 => uint256[])) private _tokenArr_by_pack_by_requestId_map;
    mapping (bytes32 => mapping (uint256 => uint256)) private _pack_by_token_by_requestId_map;
    mapping (bytes32 => uint256[]) private _shuffledOrder_by_requestId_map;
    mapping (uint256 => uint256[]) private _shuffleOrder_by_packId_map;
    mapping (uint256 => bool) private _packWaxSealed_map;
    mapping (uint256 => bool) private _tokenPacked_by_tokenId_map;
    mapping (bytes32 => address) private _originalOwner_by_requestId_map;
    mapping (bytes32 => bool) private _requestIdDead_map;
    mapping (bytes32 => address[]) private _participantWallets_by_requestId_map;
    mapping (uint256 => address[]) private _waxbroken_participantWallet_Arr_by_packId_map;
    mapping (bytes32 => mapping(address=>bool)) _walletSubscribed_by_requestId_map;
    mapping (bytes32 => mapping(uint =>bool)) _digikeyTokenIdEnabled_by_requestId_map;
    mapping (bytes32 => bool) _generalSubscriptionOpen_by_requestId_map;
    mapping (bytes32 => bool) _digikeySubscriptionOpen_by_requestId_map;
    
    event RandomnessRequested (bytes32 indexed requestId, string indexed setName);
    event RandomnessReceived (bytes32 indexed requestId, uint256 indexed result);
    event PackWaxSealBroken (bytes32 indexed requestId, uint256 indexed packId);
    event PackWaxSealSet (bytes32 indexed requestId, uint256 indexed packId);
    event WalletSubscribed(bytes32 indexed requestId, address wallet, bool usedKey);
    



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
     
     

    
       constructor() VRFConsumerBase(0x8C7382F9D8f56b33781fE506E897a4F1e2d17255, 0x326C977E6efc84E512bB9C30f76E30c160eD06FB) public 
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender); 
        _linkAddress = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
        s_keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
        s_fee = 100000000000000;
        _packIDs.increment(); //@dev to start at pack 1.
        
    }
    
        // constructor(address nftContractAddress, address vrfCoordinator, address link, bytes32 keyHash, uint256 fee)
    //     VRFConsumerBase(vrfCoordinator, link) public 
    // {
    //     _setupRole(DEFAULT_ADMIN_ROLE, msg.sender); 
    //     _nftContractAddress = nftContractAddress;
    //     s_keyHash = keyHash;
    //     s_fee = fee;
    //     setPublicChainlinkToken();
    //     _packIDs.increment(); //@dev to start at pack 1.
        
    // }


    function createBox(address nftContractAddress, uint256[] memory tokenIds, uint256  numberOfPacks, string memory boxName, address tokenOwner, address digiKeyContractAddress, uint[] memory digiKeyTokenIds) public returns (bytes32 requestId) {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "DigiWax: Only for role DEFAULT_ADMIN_ROLE");
        require(!_boxnameTaken_map[boxName], "DigiWax: Set name already taken, please chose another");
        require(tokenIds.length % numberOfPacks == 0, "Digiwax: Number of tokens must be evenly divisible into the number of packs.");
        require(LINK.balanceOf(address(this)) >= s_fee, "Digiwax: Not enough LINK to offer oralce");
        require (IERC721(nftContractAddress).isApprovedForAll(msg.sender, address (this)), "ERC721: Not Approved - use approveForAll");
        //@dev ensure that new tokens are not already not in packs
        for (uint256 i = 0; i < tokenIds.length; i++){
            require(!_tokenPacked_by_tokenId_map[tokenIds[i]], "Token already in pack");
        }
        
        _boxnameTaken_map[boxName] = true;
        //@dev GeneratesRequestId here:
        requestId = requestRandomness(s_keyHash, s_fee);

        _originalOwner_by_requestId_map[requestId] = tokenOwner;
        _requestId_by_boxName_map[boxName] = requestId;
        _qtyofPacks_by_requestId_map[requestId] = numberOfPacks;
        _nftContractAddress_by_requestId_map[requestId] = nftContractAddress;
        _tokensArr_by_requestId_map[requestId]  = tokenIds;
        uint256 _currentPackId = _packIDs.current();
        _startingpack_by_requestId_map[requestId] = _currentPackId;
        _digiKeyAddress = digiKeyContractAddress;
        enableDigikeysByRequestId(requestId, digiKeyTokenIds);
       
        for (uint256 i = _currentPackId; i < _currentPackId + numberOfPacks ; i++){
            _boxName_by_packId_map[i] = boxName;
            _requestId_by_packId_map[i] = requestId;
            _packIDs.increment();
        }
        
       
        //@dev !! WITHDRAWS TOKENS TO SEAL IN PACK
        for (uint256 i = 0; i < tokenIds.length; i++){
        IERC721(nftContractAddress).safeTransferFrom(tokenOwner, address(this), tokenIds[i]);
            _tokenPacked_by_tokenId_map[tokenIds[i]] = true;
            }
        
        emit RandomnessRequested(requestId, boxName);
    }


//@dev admin can add keys
function enableDigikeysByRequestId(bytes32 requestId, uint[] memory digiKeyTokenIds) public  {
      require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "DigiWax: Only for role DEFAULT_ADMIN_ROLE");
      require(digiKeyTokenIds.length > 0, "Digiwax: Empty Token List");
      require(_participantWallets_by_requestId_map[requestId].length < _tokensArr_by_requestId_map[requestId].length, "Digiwax: No More Spots Left");
       
        for (uint256 i = 0; i < digiKeyTokenIds.length; i++){
         _digikeyTokenIdEnabled_by_requestId_map[requestId][digiKeyTokenIds[i]] = true;
        }  
    }
    
    //@undos all packs in box and returns NFTs to original owner
    function undoBoxByName(string memory boxName) public {
      require(_boxnameTaken_map[boxName], "Digiwax: No such box name");
      return undoBoxByRequestId(getRequestIdByBoxName(boxName));
    }
    
    
    function undoBoxByRequestId(bytes32 requestId) public {
          require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 'DigiWax: Only for role DEFAULT_ADMIN_ROLE');
          uint256[] memory tokenIds = getTokensArrOriginalOrder(requestId);
          
         for (uint256 i = 0; i < tokenIds.length; i++){
            IERC721(_nftContractAddress_by_requestId_map[requestId]).safeTransferFrom(address(this), _originalOwner_by_requestId_map[requestId], tokenIds[i]);
            _tokenPacked_by_tokenId_map[tokenIds[i]] = false;
        }
        _requestIdDead_map[requestId] = true;
    }
    
    function updateGeneralSubscriptionByRequestId(bytes32 requestId, bool isOpen) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 'DigiWax: Only for role DEFAULT_ADMIN_ROLE');
        _generalSubscriptionOpen_by_requestId_map[requestId] = isOpen;
    }

     function updateDigikeySubscriptionByRequestId(bytes32 requestId, bool isOpen) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 'DigiWax: Only for role DEFAULT_ADMIN_ROLE');
        _digikeySubscriptionOpen_by_requestId_map[requestId] = isOpen;
    }



    function subscribeToBoxByName(string memory boxName, address subscriber) public returns (bool){
         require(_boxnameTaken_map[boxName], "Digiwax: No such box name");
        return subscribeWalletToBoxByRequestId(getRequestIdByBoxName(boxName), subscriber);
    }
    
    function subscribeToBoxByRequestId(bytes32 requestId) public returns (bool){
       return subscribeWalletToBoxByRequestId(requestId, msg.sender);
    }
    
    //@dev This is where wallets enter the box participation
    function subscribeWalletToBoxByRequestId (bytes32 requestId, address subscriber ) public returns (bool){
        require(_generalSubscriptionOpen_by_requestId_map[requestId], "Digiwax: General Subscription is not open yet!");
        require(!_walletSubscribed_by_requestId_map[requestId][subscriber] || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "DigiWax: Wallet Already Subscribed");
        require(_participantWallets_by_requestId_map[requestId].length < _tokensArr_by_requestId_map[requestId].length, "Digiwax: No More Spots Left");
        _participantWallets_by_requestId_map[requestId].push(subscriber);
        _walletSubscribed_by_requestId_map[requestId][subscriber] =true;
        emit WalletSubscribed(requestId, subscriber, false);
        return true;
    }

// @dev this is where wallets enter using digiKey
    function subscribeWalletToBoxByRequestIdUsingKey (bytes32 requestId, address subscriber, uint digikeyTokenId ) public returns (bool){
        require(_digikeySubscriptionOpen_by_requestId_map[requestId], "Digiwax: Key Subscription is not open yet!");
        require(_digikeyTokenIdEnabled_by_requestId_map[requestId][digikeyTokenId], "DigiWax: Key was already used or non-existant");
        require(_participantWallets_by_requestId_map[requestId].length < _tokensArr_by_requestId_map[requestId].length, "Digiwax: No More Spots Left");
        require (IERC721(_digiKeyAddress).ownerOf(digikeyTokenId) == subscriber, "Digiwax: Subscriber not owner of the Key");
        _participantWallets_by_requestId_map[requestId].push(subscriber);
        _digikeyTokenIdEnabled_by_requestId_map[requestId][digikeyTokenId] = false;
        emit WalletSubscribed(requestId, subscriber, true);
        return true;
    }

 
    
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
        if(_requestIdDead_map[requestId]) {return;}
        _fullfilledRandomRequests_map[requestId] = randomness;
        emit RandomnessReceived(requestId, randomness);
        uint256 qtyTokens = _tokensArr_by_requestId_map[requestId].length;
        uint256 qtyPacks = _qtyofPacks_by_requestId_map[requestId];
        uint256 startingPackId = _startingpack_by_requestId_map[requestId];
        uint256 tokensPerPack = qtyTokens / qtyPacks;
        uint256[] memory randoms = expand(randomness, qtyTokens) ;
        uint256[] memory tokenArr = new uint256[](qtyTokens);
        tokenArr = _tokensArr_by_requestId_map[requestId];
    
         //@dev shuffle tokens 
        for (uint256 i = 0; i < qtyTokens; i++) { 
           uint256 n =  randoms[i] % (qtyTokens - 1);
           uint256 temp = tokenArr[n];
           tokenArr[n] = tokenArr[i];
           tokenArr[i] = temp;
        }
        
        _shuffledOrder_by_requestId_map[requestId] = tokenArr;
    
         //@dev assign shuffled tokens to packs and wax seal 
        for (uint256 i = startingPackId; i < startingPackId + qtyPacks; i++) {
             for(uint256 j = 0 + (i - startingPackId) * tokensPerPack; j < tokensPerPack * (i - startingPackId + 1); j++){
              _pack_by_token_by_requestId_map[requestId][tokenArr[j]] = i;
              _tokenArr_by_pack_by_requestId_map[requestId][i].push(tokenArr[j]);
             }
             _shuffleOrder_by_packId_map[i] =  _tokenArr_by_pack_by_requestId_map[requestId][i];
             _packWaxSealed_map[i] = true;
             emit PackWaxSealSet(requestId, i);
        }
    
    }
   
   
   //@dev this is where the ERC721 gets assigned and distributed to participant wallets. 
   function breakWax_Pack(uint256 packId) public returns(uint256[] memory){
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 'DigiWax: Only for role DEFAULT_ADMIN_ROLE');
        require(!_requestIdDead_map[getRequestIdByPackId(packId)], 'Digiwax: Pack in box was undone');
         bytes32 requestId = getRequestIdByPackId(packId);
        require(_participantWallets_by_requestId_map[requestId].length == _tokensArr_by_requestId_map[requestId].length, "Digiwax: Participant count wrong");
        require(_packWaxSealed_map[packId], "Digiwax: Seal already broken!");
        _packWaxSealed_map[packId] = false;
        emit PackWaxSealBroken(_requestId_by_packId_map[packId], packId);
        uint256[] memory shuffledTokensArr = _shuffleOrder_by_packId_map[packId];
        uint256 qtyTokens = shuffledTokensArr.length;
        uint256 startingPackId = _startingpack_by_requestId_map[requestId];
        uint256 packNo = packId - startingPackId;
        uint256 shift = packNo * qtyTokens; 
        address[] memory wallets = new address[](qtyTokens);
        
         for (uint256 i = 0; i < qtyTokens; i++){
            wallets[i] = ( _participantWallets_by_requestId_map[requestId][i+shift]);
            IERC721(_nftContractAddress_by_requestId_map[requestId]).safeTransferFrom(address(this), wallets[i], shuffledTokensArr[i]);
            _tokenPacked_by_tokenId_map[shuffledTokensArr[i]] = false;
        }
       
        
        return  _shuffleOrder_by_packId_map[packId];
   }
   
   
      function breakWax_AllPacks_Box(string memory boxName) public returns(uint256[] memory, uint256){
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 'DigiWax: Only for role DEFAULT_ADMIN_ROLE');
        require(!_requestIdDead_map[getRequestIdByBoxName(boxName)], 'Digiwax: Box was undone');
        require(_boxnameTaken_map[boxName], "Digiwax: No such box");
        bytes32 requestId = getRequestIdByBoxName(boxName);
        require(_participantWallets_by_requestId_map[requestId].length == _tokensArr_by_requestId_map[requestId].length, "Digiwax: Participant count wrong");
        for (uint256 i = _startingpack_by_requestId_map[requestId]; i < _startingpack_by_requestId_map[requestId] + _qtyofPacks_by_requestId_map[requestId]; i++ ){
            if(!_packWaxSealed_map[i]) {continue;}
            breakWax_Pack(i);
        }
        return getShuffledOrderAndPackCountByRequestId(requestId);
   }


   
   function getShuffledOrderAndPackCountByRequestId (bytes32 requestId) public view returns (uint256[] memory, uint256 ) {
        for (uint256 i = _startingpack_by_requestId_map[requestId]; i < _startingpack_by_requestId_map[requestId] + _qtyofPacks_by_requestId_map[requestId]; i++){
        require (!_packWaxSealed_map[i], "Wax Not Broken On Pack Yet");    
        
        }
        return (_shuffledOrder_by_requestId_map[requestId], _qtyofPacks_by_requestId_map[requestId]);
       
   }
   
   function getShuffledOrderByPackId(uint256 packId) public view returns (uint256[] memory){
       require (!_packWaxSealed_map[packId], "Wax Not Broken On Pack Yet");  
       return _shuffleOrder_by_packId_map[packId];
       
   }
   

   function getRandomFulfillmentByRequestId(bytes32 requestId) public view returns (uint256){
       return _fullfilledRandomRequests_map[requestId];
   }
   
   
   function getRequestIdByBoxName(string memory boxName) public view returns (bytes32){
       return _requestId_by_boxName_map[boxName];
   }
   
   
   function getRequestIdByPackId(uint256 packNumber) public view returns (bytes32){
       return _requestId_by_packId_map[packNumber];
   }
   
   
   function getBoxNameByPackId(uint256 packNumber) public view returns(string memory){
       return _boxName_by_packId_map[packNumber];
   }


    function getTokensArrOriginalOrder(bytes32 requestId) public view returns(uint256[] memory){
        uint256[] memory tokenArr  = new uint256[](_tokensArr_by_requestId_map[requestId].length);
        for (uint256 i = 0; i < _tokensArr_by_requestId_map[requestId].length; i++) {
            tokenArr[i] = _tokensArr_by_requestId_map[requestId][i];
        }
        return tokenArr;
    }
   
   
    function getPackAmountByRequestId(bytes32 requestId) public view returns (uint256){
        return _qtyofPacks_by_requestId_map[requestId];
    }
  
   
    function getStartingPackByRequestId(bytes32 requestId) public view returns (uint256){
        return _startingpack_by_requestId_map[requestId];
   }
   
   
    function getTotalPacks() external view returns(uint256){
        return _packIDs.current() - 1; 
    }
   
   
   function getParticipantWalletsByRequestId(bytes32 requestId) public view returns(address[] memory){
       return _participantWallets_by_requestId_map[requestId];
   }
   
   function getWalletAssignmentByPack(uint256 packId, uint256 itemNumber) public view returns (address){
       require(!_requestIdDead_map[getRequestIdByPackId(packId)], 'Digiwax: Box was undone');
       require (!_packWaxSealed_map[packId], "Wax Not Broken On Pack Yet");  
       return _waxbroken_participantWallet_Arr_by_packId_map[packId][itemNumber];
   }

   function getEnabledDigiKeysRequestId(bytes32 requestId, uint tokenId) external view returns(bool){
       return _digikeyTokenIdEnabled_by_requestId_map[requestId][tokenId];
   }

  
   

   function withdrawLink() public onlyOwner {
    LinkTokenInterface link = LinkTokenInterface(_linkAddress);
    require(link.transfer(msg.sender, getLinkBalance1018()), "Unable to transfer");
  }
  
  
  //@dev balance in mini units 1 * 10 ** 18;
  function getLinkBalance1018() public view  returns (uint256) {
      LinkTokenInterface link = LinkTokenInterface(_linkAddress);
      return link.balanceOf(address(this));
  }
  

    /**
     * @notice Set the key hash for the oracle
     *
     * @param keyHash bytes32
     */
    function setKeyHash(bytes32 keyHash) public onlyOwner {
        s_keyHash = keyHash;
    }

    /**
     * @notice Get the current key hash
     *
     * @return bytes32
     */
    function keyHash() public view returns (bytes32) {
        return s_keyHash;
    }

    /**
     * @notice Set the oracle fee for requesting randomness
     *
     * @param fee uint256
     */
    function setFee(uint256 fee) public onlyOwner {
        s_fee = fee;
    }

    /**
     * @notice Get the current fee
     *
     * @return uint256
     */
    function fee() public view returns (uint256) {
        return s_fee;
    }
    
    
       function getChainlinkToken() public view returns (address) {
    return _linkAddress;
  }
  
 //@dev gives more random numbers from number using chainlink best practices guide
  
   function expand(uint256 randomValue, uint256 n) public pure returns (uint256[] memory expandedValues) {
    expandedValues = new uint256[](n);
    for (uint256 i = 0; i < n; i++) {
        expandedValues[i] = uint256(keccak256(abi.encode(randomValue, i)));
    }
    return expandedValues;
}
  
  


    
}