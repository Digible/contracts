// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

// @dev Interfact for DIGIWAX subscriber (as opposed to WaxMaker)

contract IDigiWaxSubscriber{   
    event BoxWaxSealBroken (bytes32 indexed requestId, string indexed boxName);
    event BoxWaxSealSet (bytes32 indexed requestId, string indexed boxName);
    event WalletSubscribed(string indexed boxname, address wallet, bool usedKey);
    event BoxCreated(string indexed boxname, address boxCreator);
    
    mapping (string => address) public boxOwner_map;
    
    mapping (string => bool) public generalSubscriptionOpen_by_boxName_map;
    mapping (string => bool) public digikeySubscriptionOpen_by_boxName_map; 
    mapping (string => uint256) public accessPrice_by_boxName_map;
    mapping (string => address) public accessPriceContractAddress_by_boxName_map;       
    mapping (string => address[]) public participantWallets_by_boxName_map;    
    mapping (string => bool) public oracleSpoke_by_boxName_map;  
    mapping (bytes32 => bool) public  boxSealed_By_requestId_map;
    
    
    //@dev This is where wallets enter the box participation
    function subscribeWalletToBoxByName (string memory boxName, address subscriber ) public returns (bool){    }

// @dev this is where wallets enter using digiKey - please use boxName and not RequestId
    function subscribeWalletToBoxByRequestIdUsingKey (string memory boxName, address subscriber, address digiKeyContractAddress, uint digikeyTokenId ) public returns (bool){}
          
    }