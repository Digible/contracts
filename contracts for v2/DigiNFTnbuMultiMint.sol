//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
 
import {DigiNFT} from "./DigiNFTnbu.sol";

 contract DigiNFTnbuMultiMint {

    uint private constant _maxQty = 20;

    function bulkMint(
        address wallet,
        string[] memory cardName,
        string[] memory cardImage,
        bool[] memory cardPhysical,
        string[] memory tokenUriMetadata,
        address digiNFTContractAddress,
        string memory baseUri,
        uint[] memory qtyToMint
    ) public returns (uint[] memory) {
        require(qtyToMint.length <= _maxQty, "DigiNFT: You exceeded the max amount of mint");
        for (uint i = 0; i < qtyToMint.length; i++) {
            for (uint j = 0; j < qtyToMint[i]; j++) {
                DigiNFT(digiNFTContractAddress).mint(wallet, cardName[i], string(abi.encodePacked(baseUri, cardImage[i])), cardPhysical[i], string(abi.encodePacked(baseUri, tokenUriMetadata[i])));
            }
        }
    }
}