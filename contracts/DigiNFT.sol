pragma solidity 0.6.5;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract DigiNFT is ERC721, AccessControl {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    bytes32 public constant MINTER = keccak256("MINTER");

    mapping (uint256 => string) private _cardNames;
    mapping (uint256 => string) public _cardImages;
    mapping (uint256 => bool) private _cardPhysicals;

    constructor(
        string memory baseURI
    ) public ERC721("Digi NFT", "DNFT") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER, msg.sender);
        _setBaseURI(baseURI);
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
        require(hasRole(MINTER, msg.sender), 'DigiNFT: Only for role MINTER');

        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(wallet, newItemId);
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

    function _setCardName(uint256 tokenId, string memory _cardName) internal virtual {
        require(_exists(tokenId), "ERC721Metadata: Name set of nonexistent token");
        _cardNames[tokenId] = _cardName;
    }

    function _setCardPhysical(uint256 tokenId, bool _cardPhysical) internal virtual {
        require(_exists(tokenId), "ERC721Metadata: Physical set of nonexistent token");
        _cardPhysicals[tokenId] = _cardPhysical;
    }

    function _setCardImage(uint256 tokenId, string memory _cardImage) internal virtual {
        require(_exists(tokenId), "ERC721Metadata: Image set of nonexistent token");
        _cardImages[tokenId] = _cardImage;
    }

}