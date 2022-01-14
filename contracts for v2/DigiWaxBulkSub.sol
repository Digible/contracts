pragma solidity 0.8.11;
import "./DigiWax2b.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";


contract IWax {

   function subscribeWalletToBoxByName (string memory boxName, address subscriber ) public returns (bool){
     
    }

}


 contract DigiWaxBulkSub is AccessControl {


constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender); 
}

function makeAdmin  (address operator) external {

require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 'ONLY FOR DEFAULT_ADMIN_ROLE');
_setupRole(DEFAULT_ADMIN_ROLE, operator);
}


function bulkSubcribe  (
        address digiWaxContractAddress,
        string memory boxName,
        address[] memory wallets
     ) external returns (bool) {    
              
         for (uint i = 0; i < wallets.length; i++){

           IWax(digiWaxContractAddress).subscribeWalletToBoxByName (boxName, wallets[i]);

         }

         return true;

}

function bulkSubcribeWallet (
        address digiWaxContractAddress,
        string memory boxName,
        address wallet,
        uint256 qty

     ) external returns (bool) {    
              
         for (uint i = 0; i < qty; i++){

           IWax (digiWaxContractAddress).subscribeWalletToBoxByName (boxName, wallet);

         }

         return true;

}


 }
