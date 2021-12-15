pragma solidity 0.8.10;
import "https://github.com/Digible/contracts/blob/contractsV2/contracts%20for%20v2/DigiNFTnbu.sol";


 contract DigiNFTnbuBulk{

function bulkMint(
        address wallet,
        string memory cardName,
        string memory cardImage,
        bool cardPhysical,
        string  memory tokenURI_metadata,
        address digiNFTContractAddress,
        uint qtyToMint

     ) public returns (uint[] memory) {
      
         uint[] memory mintedTokenIds = new uint[](qtyToMint);
         
         for (uint i = 0; i < qtyToMint; i++){

             mintedTokenIds[i] = DigiNFT(digiNFTContractAddress).mint(wallet, cardName,cardImage, cardPhysical, tokenURI_metadata);

         }

         return mintedTokenIds;

}




 }



