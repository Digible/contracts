// SPDX-License-Identifier: MIT
// @dev DigiEvoMu Version 1 - Evolution and Mutation of NFTs,
pragma solidity 0.8.12;
import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/VRFConsumerBase.sol";
import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/ChainlinkClient.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/utils/ERC721Holder.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol";

contract DigiEvoMu is VRFConsumerBase, AccessControl, ChainlinkClient, ERC721Holder, ReentrancyGuard {
    using SafeMath for uint256; 


    event RandomnessReceived (string indexed podname, bytes32 indexed requestId, uint256 indexed result);
    event PodWaxSealBroken (bytes32 indexed requestId, string indexed podName);
    event OracleConsulted (bytes32 indexed requestId, string indexed podName);
    event WalletSubscribed(string indexed podname, address wallet, bool usedKey);
    event PodCreated(string indexed podname, address podCreator);
 
    bytes32 public constant PODMAKER = keccak256("PODMAKER"); //0e713d936ee004edc0a77c6094bd6a75d836bda1eece05c06df5d9ce4a89655f
    
    uint256 private BIGNUMBER = 10**18;
    bytes32 private s_keyHash;
    uint256 private s_fee;
    address public _linkAddress;   

    IERC20 public DIGI;
    uint256 public pod_fee_digi;
    uint256 public access_fee_percentage;
    address private _digiFeeCollectorAddress;
    
    mapping (string => address) public podOwner_map;
    mapping (string => bytes32) public requestId_by_podName_map;
    mapping (string => bool) private _requestIdDead_by_podName_map;
    mapping (string => bool) public generalSubscriptionOpen_by_podName_map;
    mapping (string => bool) public digikeySubscriptionOpen_by_podName_map; 

    mapping (string => uint256) public accessPrice_by_podName_map;
    mapping (string => address) public accessPriceContractAddress_by_podName_map;    
   
    
    mapping (string => uint256[]) public tokensArr_by_podName_map;
    mapping (string => address[]) public eligible_nftAddresses_by_podName_map;
    mapping (string => uint256[]) public digiKeyTokensArr_by_podName_map;
    mapping (string => mapping (address => mapping(uint256 => bool))) public digiKeyAllowed_byPodName_3map;  
 
    mapping (string => address[]) public participantWallets_by_podName_map; 
    mapping (string => mapping(address=>bool)) public _walletSubscribed_by_podName_map;
    mapping (string => bool) public oracleSpoke_by_podName_map;
    
    mapping (bytes32 => string) public _podName_by_requestId_map;
    mapping (bytes32 => uint256[]) private _shuffledTokens_by_requestId_map;
    mapping (bytes32 => address[]) private _shuffledAddresses_by_requestId_map;  
  
  
    mapping (string => bool) public podnameTaken_map;

    mapping (bytes32=>uint256) private  _fullfilledRandomRequests_map;  

    
    mapping (address=>uint256) public mutationsQtyAllowed_by_wallet_map 
    mapping (address =>Pod[])  public pods_by_wallet_map;
    mapping (string =>Pod) public pod_by_name_wallet_map;
    mapping (string => address[]) public resultNFT_Addresses_by_podName_map;

     struct Pod {
        string: podName;
        address: ownerWallet;
        bool: isMutation;
        uint256: startTime;
        uint256: duration;
        address: accessFeeCurrency;
        uint256: accessPrice;

    }

    
    constructor() VRFConsumerBase(0x8C7382F9D8f56b33781fE506E897a4F1e2d17255, 0x326C977E6efc84E512bB9C30f76E30c160eD06FB)  {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender); 
        _setupRole(PODMAKER, msg.sender);
        _linkAddress = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
        s_keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
        s_fee = 100000000000000;
        DIGI = IERC20(0x03d390Af242C8a8a5340489f2D2649e859d7ec2f);
        _digiFeeCollectorAddress = msg.sender;
        pod_fee_digi = 50 * BIGNUMBER;  
        access_fee_percentage = 10;           
    }


    

// ["0xd9145CCE52D386f254917e481eB44e9943F39138","0xd9145CCE52D386f254917e481eB44e9943F39138"]
// [1,2]
// 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4


//-----------------------------------------
//------------POD CREATION FUNCTIONS -------------------//

    function createPod (string memory podName,  
                        bool isMutation,                                               
                        address allowed_NftContractAddress,
                        uint256 allowed_start_tokenId, uint256 allowed_end_tokenId,                        
                        address result_nftContractAddress,  
                        uint256 result_start_keyTokenId, uint256 result_end_keyTokenId,
                        uint256 evolutionDuration;                                     
                        address accessPriceContractAddress, 
                        uint256 accessPrice
                        )                         
            external payable returns (bool) {

        require(hasRole(PODMAKER, msg.sender), "Only for PODMAKER");
        require(!podnameTaken_map[podName], "Pod name taken");    
        require(LINK.balanceOf(address(this)) >= s_fee, "Not enough LINK to offer oralce. Send more LINK to this contract address.");
        require(DIGI.transferFrom(msg.sender, _digiFeeCollectorAddress, pod_fee_digi), "DIGI Fee XFer failed");      
        podnameTaken_map[podName] = true;
        podOwner_map[podName] = msg.sender;
        Pod storage pod = Pod({
            podName: podName,
            ownerWallet:msg.sender,
            isMutation: isMutation,
            startTime: block.timestamp,
            duration: evolutionDuration,
            accessFeeCurrency: accessPriceContractAddress,
            accessPrice: accessPrice;

        });
        pods_by_wallet_map[msg.sender].push(pod));        
        pod_by_name_wallet_map[podName] = pod;
        
       
        enableNFTsforEvolution(podName, allowed_NftContractAddress, allowed_start_tokenId, result_end_keyTokenId);
        packPod(podName, result_nftContractAddress, result_start_keyTokenId, result_end_keyTokenId);
        askOracle(podName);
        emit PodCreated(podName, msg.sender);     
        return true;
    }


  function enableNFTsforEvolution(string memory podName, 
    address nftContractAddress, 
    uint256 start_keyTokenId,
    uint256 end_keyTokenId) 
    public  {
     
      require(podOwner_map[podName] == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "For Pod Owner Only"); 
             
        for (uint256 i = start_keyTokenId; i <= end_keyTokenId; i++) {
            eligible_nftAddresses_by_podName_map[podName].push(nftContractAddress);
            digiKeyTokensArr_by_podName_map[podName].push(i);         
            digiKeyAllowed_byPodName_3map[podName][nftContractAddress][i] = true;
        }  
    }
    

    function packPod (string memory podName, address nftContractAddress, uint256 start_tokenId, uint256 end_tokenId) 
            public payable returns (bool) {
       
        require(podOwner_map[podName] == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "For Pod Owner Only");
        require(podnameTaken_map[podName], "Pod Does Not Exist");

        for (uint256 i = start_tokenId; i <= end_tokenId; i++) {
            require(IERC721(nftContractAddress).ownerOf(i) == msg.sender, "Not Owner");
            IERC721(nftContractAddress).safeTransferFrom(msg.sender, address(this), i);
            resultNFT_Addresses_by_podName_map[podName].push(nftContractAddress);
            tokensArr_by_podName_map[podName].push(i);
        }             
        return true;    
    }

    // @dev - THIS IS WHERE WE REQUEST RANDOMNESS FROM THE CHAINLINK ORACLE
    function askOracle (string memory podName) internal returns (bytes32){
    

        Pod pod = pod_by_name_wallet_map[podName];       
        bytes32 requestId = requestRandomness(s_keyHash, s_fee);              
        requestId_by_podName_map[podName] = requestId;
        _podName_by_requestId_map[requestId] = podName;      
        emit OracleConsulted(requestId, podName);
        return requestId;                         
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
        string memory podName = _podName_by_requestId_map[requestId];
        emit RandomnessReceived(podName, requestId, randomness);       
        oracleSpoke_by_podName_map[podName] = true;     
        _fullfilledRandomRequests_map[requestId] = randomness;   
     
    }



    function breakWax_Pod (string memory podName)  external returns(address[] memory, uint256[] memory){
       
       require(podOwner_map[podName] == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "For Pod Owner Only");
       require (!_requestIdDead_by_podName_map[podName], "Pod was undone");   
       require(podnameTaken_map[podName], "No such pod");  
       require(oracleSpoke_by_podName_map[podName], "Oracle Hasn't Shuffled Pod Yet");   
       bytes32 requestId = requestId_by_podName_map[podName];
       
        uint256 qtyTokens = tokensArr_by_podName_map[podName].length;
        require (!_requestIdDead_by_podName_map[podName], "Pod was undone");        
        require(participantWallets_by_podName_map[podName].length == qtyTokens, "Participant count wrong");
        require(podOwner_map[podName] == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "For pod owner only");
       
        //@dev shuffle tokens 
        uint256 randomness = _fullfilledRandomRequests_map[requestId];       
        uint256[] memory randoms = new uint256[](qtyTokens);
        for (uint256 i = 0; i < qtyTokens; i++) {
                 randoms[i] = uint256(keccak256(abi.encode(randomness, i)));
        }
  
        uint256[] memory tokenArr = new uint256[](qtyTokens);
        address[] memory addressArr = new address[](qtyTokens);
        tokenArr = tokensArr_by_podName_map[podName];
        addressArr = resultNFT_Addresses_by_podName_map[podName];
         
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
            nft.safeTransferFrom(address(this), participantWallets_by_podName_map[podName][i], tokenId);
        } 

        return (addressArr, tokenArr);
   }    



        //@dev owner/admin can add allowed
        
  
    function updateSubscriptionsByPod(string memory podName, bool isOpen_Gen, bool isOpen_Key) external {
        require(podOwner_map[podName] == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "For Pod Owner Only");     
        generalSubscriptionOpen_by_podName_map[podName] = isOpen_Gen;
          digikeySubscriptionOpen_by_podName_map[podName] = isOpen_Key;
    }

         
    //@undos all packs in pod and returns NFTs to original owner
    function undoPodByName(string memory podName) external returns (bool){
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "For Admin Only");     
        require(podnameTaken_map[podName], "No such pod name");
       
        for (uint256 i = 0; i <  tokensArr_by_podName_map[podName].length; i++) {
            IERC721(resultNFT_Addresses_by_podName_map[podName][i]).safeTransferFrom(address(this), podOwner_map[podName],  tokensArr_by_podName_map[podName][i]);            
        }
        _requestIdDead_by_podName_map[podName] = true; 
      return true;
    }  
    
    //@dev This is where wallets enter the pod participation
    function subscribeWalletToPodByName (string memory podName, address subscriber ) external nonReentrant returns (bool){
        require(generalSubscriptionOpen_by_podName_map[podName], "General Subscription is not open yet!");
        require(!_walletSubscribed_by_podName_map[podName][subscriber] || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Wallet Already Subscribed");
        require(participantWallets_by_podName_map[podName].length < tokensArr_by_podName_map[podName].length, "No More Spots Left");
        IERC20 feeToken = IERC20(accessPriceContractAddress_by_podName_map[podName]);
        uint256 fee_amount = accessPrice_by_podName_map[podName].mul(access_fee_percentage).div(100);
        uint256 net_amount = accessPrice_by_podName_map[podName].mul(100 - access_fee_percentage).div(100);
        require(accessPrice_by_podName_map[podName] == 0 || (
             feeToken.transferFrom(msg.sender, _digiFeeCollectorAddress, fee_amount) &&
             feeToken.transferFrom(msg.sender, podOwner_map[podName], net_amount)), "Access Fees XFR Failed");
    

        participantWallets_by_podName_map[podName].push(subscriber);
        _walletSubscribed_by_podName_map[podName][subscriber] =true;
        emit WalletSubscribed(podName, subscriber, false);
        return true;
    }

// @dev this is where wallets enter using digiKey
    function subscribeWalletToPodByRequestIdUsingKey (string memory podName, address subscriber, address nftContractAddress, uint digikeyTokenId ) external nonReentrant returns (bool){
          
        require(digikeySubscriptionOpen_by_podName_map[podName], "Key Subscription is not open yet!");
        require( digiKeyAllowed_byPodName_3map[podName][nftContractAddress][digikeyTokenId], "Key was already used or non-existant");
        require(participantWallets_by_podName_map[podName].length < tokensArr_by_podName_map[podName].length, "No More Spots Left");
        require (IERC721(nftContractAddress).ownerOf(digikeyTokenId) == subscriber, "Subscriber not owner of the Key");
        participantWallets_by_podName_map[podName].push(subscriber);
        digiKeyAllowed_byPodName_3map[podName][nftContractAddress][digikeyTokenId] = false;
        emit WalletSubscribed(podName, subscriber, true);
        return true;
    }

   
  
    function oraclize(string memory podName, uint256 randomness) external  {    
     require(podOwner_map[podName] == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "For Pod Owner Only"); 
    require(podnameTaken_map[podName], "No such pod");    
      bytes32 requestId = requestId_by_podName_map[podName];
      _fullfilledRandomRequests_map[requestId] = randomness;
        oracleSpoke_by_podName_map[podName] = true;
        emit RandomnessReceived(podName, requestId, randomness);
  }   


function getTotalSpotsByPodName(string memory podName) external view returns (uint){


 return tokensArr_by_podName_map[podName].length;

}

function getTotalKeysByPodName (string memory podName) external view returns (uint){

 return digiKeyTokensArr_by_podName_map[podName].length;

}

function getTotalWalletsByPodName (string memory podName) external view returns (uint){


 return participantWallets_by_podName_map[podName].length;

}


  //@dev Admin only FUNCTIONS
   
  
    function setFeeAndKeyHash(uint256 fee, bytes32 keyHash) external  {
          require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Admin only");
        s_fee = fee;
        s_keyHash = keyHash;
    }

   function withdrawGas(address tokenContract)  external  {    
         require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Admin only");
    
    IERC20 token = IERC20(tokenContract);
    require(token.transfer(msg.sender, token.balanceOf(address(this))), "Unable to transfer");
  }

    function setDigiFees(uint256 human_fee, uint256 human_percentage)  external  {
          require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Admin only");
    pod_fee_digi = human_fee * BIGNUMBER;
    access_fee_percentage = human_percentage;
  }



function bulkMint(
    
        address wallet,
        string memory cardName,
        string memory cardImage,
        bool cardPhysical,
        string  memory tokenURI_metadata,
        address digiNFTContractAddress,
        uint qtyToMint

     ) public returns (uint[] memory) {
      
      require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 'DigiNFTBulkMinter: Only for role DEFAULT_ADMIN_ROLE');
         uint[] memory mintedTokenIds = new uint[](qtyToMint);
         
         for (uint i = 0; i < qtyToMint; i++){

             mintedTokenIds[i] = DigiNFT(digiNFTContractAddress).mint(wallet, cardName,cardImage, cardPhysical, tokenURI_metadata);

         }

         return mintedTokenIds;

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