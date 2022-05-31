// SPDX-License-Identifier: MIT
// @dev Ukraine minter contract.
pragma solidity 0.8.10;

import "https://github.com/Digible/contracts/blob/contractsV2/contracts%20for%20v2/DigiNFTnbu.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/utils/ERC721Holder.sol";

contract IAuctMktPlaceRoyalty {

      function setRoyaltyForToken(
        address nftContractAddress,
        uint256 _tokenId,
        address beneficiary,
        uint256 _fee
    ) external {}
}


contract UkraineMinter is AccessControl, ERC721Holder  {


    event Minted(string indexed nftName, string tokenURI_metadata, address digiNFTContractAddress);

    address public  bulkMintAddress = 0x311Ed227C3cC1061C00e1BD6adA7d75a94969D82;
    address public  ukraineDonationAddress = 0xCE0DA38D334313aED791a3b85618e2dE74AB4276;
    address public  auctionmarketplaceAddress = 0xa4ACe9a3D90fbAe14a4b42698F480f4282a49A2d;

    mapping (string=>mapping(address => bool)) public walletMintedByNftName;

    mapping (string=>uint256) public minimumDonationByNftName;
    mapping (string=>address) public donationCurrencyByNftName;
    mapping (string=>address) public mintFromAddressByNftName;
    mapping (string=>string) public nftImageByNftName;
    mapping (string=>bool) public nftPhygitalByNftName;
    mapping (string=>string) public tokenURI_metadataByNftName;
    mapping (string=>bool) public mintingClosedByNftName;
    string[] public nftNames;
    mapping (string=>bool) public nftNameTaken;
    
    constructor () {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender); 
       
        addNFT("U Digicube - Ukraine Peace Special Edition",
        0xA16a4Bd312C11205ebEf9299bd8D8D81DD570E39, // DigiCube Testnet Address
        "https://digible.mypinata.cloud/ipfs/QmT6dJ2aLSuHzooyveL1HCe8SfNzXiNYyjQa9JViyambse",
        false,
        "https://digible.mypinata.cloud/ipfs/QmPYAu76MX6oVMc866pMvrxgVvS9z74dowZx1K2thTKTtj",
        0,
        0x0000000000000000000000000000000000000000,
        false);  
        

         addNFT("U Digicube - Stand with Ukraine Special Edition",
         0xA16a4Bd312C11205ebEf9299bd8D8D81DD570E39, // DigiCube Testnet Address
        "https://digible.mypinata.cloud/ipfs/QmbumEkTTwP5LZbq9FpptP5ZcHHi6S9HdMREf1yWveaPWL",
        false,
        "https://digible.mypinata.cloud/ipfs/QmcWBrda3hvJ6JJHYw98uAw9pLdndXFvYjGNYEpDoK8EcL",
        100,
        0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, //
        false);  
        

    }

    function MintNft (
        address receivingWallet,
        string memory nftName, 
        uint256 donationAmount) public payable returns (uint256)
     {
        
      require(!mintingClosedByNftName[nftName], "Minting for this NFT is closed");
       require (!walletMintedByNftName[nftName][msg.sender], "Wallet already minted this NFT.");
        if(minimumDonationByNftName[nftName] > 0) {
            require (donationAmount >= minimumDonationByNftName[nftName], "Minimum donation amount is not met");
            require (IERC20(donationCurrencyByNftName[nftName]).transferFrom(msg.sender, ukraineDonationAddress, donationAmount), "Approve ERC20");
            }

        //uint256 newTokenId = DigiNFT(mintFromAddressByNftName[nftName]).mint(receivingWallet,
        uint256 newTokenId = DigiNFT(mintFromAddressByNftName[nftName]).mint(address(this),
        nftName,
        nftImageByNftName[nftName], 
        nftPhygitalByNftName[nftName], 
        tokenURI_metadataByNftName[nftName]); 
        walletMintedByNftName[nftName][msg.sender] = true;
        emit Minted(nftName, tokenURI_metadataByNftName[nftName], mintFromAddressByNftName[nftName]);
        IAuctMktPlaceRoyalty(auctionmarketplaceAddress).setRoyaltyForToken(
                mintFromAddressByNftName[nftName],
                newTokenId,
                ukraineDonationAddress,
                500
        );
        IERC721(mintFromAddressByNftName[nftName]).safeTransferFrom(address(this),receivingWallet, newTokenId);


        return newTokenId;


       
    }


    function addNFT (string memory nftName, 
        address nftContractAddress,
        string memory nftImage,
        bool phygital,
        string memory tokenURI_metadata,
        uint256 minimumDonation,
        address donationCurrency,
        bool closed) public 
    {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Only for role DEFAULT_ADMIN_ROLE");
        require(!nftNameTaken[nftName], "This NFT Name is taken. Please choose another");
        nftNameTaken[nftName] = true;
        mintFromAddressByNftName[nftName] = nftContractAddress;
        nftImageByNftName[nftName] = nftImage;
        nftPhygitalByNftName[nftName] = phygital;
        tokenURI_metadataByNftName[nftName] = tokenURI_metadata;
        minimumDonationByNftName[nftName] = minimumDonation;
        donationCurrencyByNftName[nftName] = donationCurrency;
        if(closed) {
            closeNft(nftName, closed);
        }
        nftNames.push(nftName);
    }

   
    function closeNft(string memory nftName, bool closeNft) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Only for role DEFAULT_ADMIN_ROLE");
        mintingClosedByNftName[nftName] = closeNft;

    }

    function allowWalletToMintByNftName(string memory nftName) public {
         require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Only for role DEFAULT_ADMIN_ROLE");
         walletMintedByNftName[nftName][msg.sender] = false;

    }

 
  

       
    
}
