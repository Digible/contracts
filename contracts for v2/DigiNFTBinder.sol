pragma solidity ^0.8.8;
 
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";

 contract DigiNFTBinder is  AccessControl {
     
    
    mapping (address => bool) public DigiNFTAddresses;
    uint addressRegistryCount;
    
     constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender); 
        
        
 }
 
 function  allowDigiNFTContract   (address _addy)   public {
     
      require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 'DigiNFTBinder: Only for role DEFAULT_ADMIN_ROLE');
      require(!DigiNFTAddresses[_addy], 'DigiNFTBinder: Contract address already allowed');
      DigiNFTAddresses[_addy] = true;
      addressRegistryCount++;
 }
 
function  removeDigiNFTContract   (address _addy) public {
     
    
      require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 'DigiNFTBinder: Only for role DEFAULT_ADMIN_ROLE');
      require(DigiNFTAddresses[_addy], 'DigiNFTBinder: Contract address already not allowed');
      DigiNFTAddresses[_addy] = false;
      addressRegistryCount--;
 }
 
 
   

 function getAll() public view returns (address[] memory){
    address[] memory ret = new address[](addressRegistryCount);
    for (uint i = 0; i < addressRegistryCount; i++) {
        ret[i] = DigiNFTAddresses[i];
    }
    return ret;
}
 
 
 
 
 }
 
 
 
 