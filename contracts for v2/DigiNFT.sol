pragma solidity ^0.8.8;
 
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";


/**
    * @dev DigiNFT Contract V2.
    https://docs.google.com/document/d/1Iam-3y-tOMSFMpslaABVOS5gFb96EFmh04QIWY5O-8Y/edit#
    */



 contract DigiNFT is ERC721, AccessControl {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

   bytes32 public constant MINTER = keccak256("MINTER");
   bytes32 public constant PHYSMINTER = keccak256("PHYSMINTER");
   
   bool private _requireMinter; 
   bool private _requirePhysminter;
   
    mapping (uint256 => string) private _cardNames;
    mapping (uint256 => string) public _cardImages;
    mapping (uint256 => bool) private _cardPhysicals;

 function _baseURI() internal view virtual override returns (string memory) {
        return "https://api.digible.io/nft/";
    }
    


    constructor() public ERC721 ("Digi NFT", "DNFT") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender); 
        _setupRole(MINTER, msg.sender);  
        _setupRole(PHYSMINTER, msg.sender);
        _requireMinter = false;
        _requirePhysminter = false;
    

    }

    /**
    * @dev Mints a new DIGI NFT for a wallet.
    */
    function mint(
        address wallet,
        string memory cardName,
        string memory cardImage,
        bool cardPhysical
    )
        public
        returns (uint256)
    {
        if(_requireMinter) {require(hasRole(MINTER, msg.sender), 'DigiNFT: Only for role MINTER');}

        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _safeMint(wallet, newItemId);
        _setCardName(newItemId, cardName);
        _setCardImage(newItemId, cardImage);
        _setCardPhysical(newItemId, cardPhysical);
        

        return newItemId;
    }

    function cardName(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: Name query for nonexistent token");
        return _cardNames[tokenId];
    }

    function cardPhysical(uint256 tokenId) public view returns (bool) {
        require(_exists(tokenId), "ERC721Metadata: Physical query for nonexistent token");
        return _cardPhysicals[tokenId];
    }

    function cardImage(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: Image query for nonexistent token");
        return _cardImages[tokenId];
    }
    
    /** @dev
      * requireMinter - TRUE: only approved wallets with ROLE = MINTER will be able to mint nfts.  FALSE: anyone can.
     **/
    
    function requireMinter(bool b) public   {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 'DigiNFT: Only for role DEFAULT_ADMIN_ROLE');
        return _setRequireMinter(b);
      
    }
    
     /** @dev
      * requirePhysminterMinter - TRUE: only approved wallets with ROLE = PHYSMINTER will be able to mark NFTs as physical FALSE: anyone cardName
     **/
    function requirePhysminter (bool b) public   {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 'DigiNFT: Only for role DEFAULT_ADMIN_ROLE');
        return _setRequirePhysminter(b);
    }
    
    function setMnterRole(address wallet, bool canMint) public {
       require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 'DigiNFT: Only for role DEFAULT_ADMIN_ROLE');
       if(canMint) { return  _setupRole(MINTER, wallet);  } 
       return revokeRole(MINTER, wallet);
    }
    
function setPhysminterRole(address wallet, bool canPhysmint) public {
       require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 'DigiNFT: Only for role DEFAULT_ADMIN_ROLE');
       if(canPhysmint) { return  _setupRole(PHYSMINTER, wallet);  }
       return revokeRole(PHYSMINTER, wallet);
    }

    function _setCardName(uint256 tokenId, string memory _cardName) internal virtual {
        require(_exists(tokenId), "ERC721Metadata: Name set of nonexistent token");
        _cardNames[tokenId] = _cardName;
    }

    function _setCardPhysical(uint256 tokenId, bool _cardPhysical) internal virtual {
        require(_exists(tokenId), "ERC721Metadata: Physical set of nonexistent token");
     if(_requirePhysminter && _cardPhysical) { require(hasRole(PHYSMINTER, msg.sender), 'DigiNFT: Only for role PHYSMINTER'); }
        _cardPhysicals[tokenId] = _cardPhysical;
    }

    function _setCardImage(uint256 tokenId, string memory _cardImage) internal virtual {
        require(_exists(tokenId), "ERC721Metadata: Image set of nonexistent token");
        _cardImages[tokenId] = _cardImage;
    }
    
    function _setRequireMinter (bool b) internal virtual  {
        _requireMinter = b;   
    }
    
    function _setRequirePhysminter (bool b) internal virtual  {
        _requirePhysminter = b;
    }
    
   
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        
        require(_exists(tokenId), "ERC721Metadata: Token query for nonexistent token");
         
        return string(abi.encodePacked(_baseURI(), uint2str(tokenId)));
    }
    
     function totalSupply() external  view  returns (uint256) {
     return  _tokenIds.current();
      
    }
    
    /** @dev
     * Utilities
     */
     
  function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
    
    
     function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    
 

}

