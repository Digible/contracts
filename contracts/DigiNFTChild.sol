pragma solidity 0.6.5;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./library/ContextMixin.sol";
import "./DigiNFT.sol";

contract DigiNFTChild is DigiNFT, ContextMixin {
    uint256 public constant BATCH_LIMIT = 20;
    
    address deployer;
    address childChainManagerProxy;

    event WithdrawnBatch(address indexed user, uint256[] tokenIds);
    event TransferWithMetadata(address indexed from, address indexed to, uint256 indexed tokenId, bytes metaData);

    constructor() public DigiNFT('https://api.digible.io/nft/') {
        childChainManagerProxy = 0xb5505a6d998549090530911180f38aC5130101c6; // Matic: 0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa
        deployer = msg.sender;
    }

    function _msgSender()
        internal
        override
        view
        returns (address payable sender)
    {
        return ContextMixin.msgSender();
    }

    function deposit(address user, bytes calldata depositData) external {
        require(_msgSender() == childChainManagerProxy, "You're not allowed to deposit");

        if (depositData.length == 32) {
            uint256 tokenId = abi.decode(depositData, (uint256));
            _mint(user, tokenId);
        } else {
            uint256[] memory tokenIds = abi.decode(depositData, (uint256[]));
            uint256 length = tokenIds.length;
            for (uint256 i; i < length; i++) {
                _mint(user, tokenIds[i]);
            }
        }
    }

    function withdraw(uint256 tokenId) external {
        require(_msgSender() == ownerOf(tokenId), "ChildERC721: INVALID_TOKEN_OWNER");
        _burn(tokenId);
    }

    function withdrawBatch(uint256[] calldata tokenIds) external {
        uint256 length = tokenIds.length;
        require(length <= BATCH_LIMIT, "ChildERC721: EXCEEDS_BATCH_LIMIT");
        for (uint256 i; i < length; i++) {
            uint256 tokenId = tokenIds[i];
            require(_msgSender() == ownerOf(tokenId), string(abi.encodePacked("ChildERC721: INVALID_TOKEN_OWNER ", tokenId)));
            _burn(tokenId);
        }
        emit WithdrawnBatch(_msgSender(), tokenIds);
    }

    function withdrawWithMetadata(uint256 tokenId) external {
        require(_msgSender() == ownerOf(tokenId), "ChildERC721: INVALID_TOKEN_OWNER");

        emit TransferWithMetadata(_msgSender(), address(0), tokenId, this.encodeTokenMetadata(tokenId));

        _burn(tokenId);

    }

    function encodeTokenMetadata(uint256 tokenId) external view virtual returns (bytes memory) {
        return abi.encode(tokenURI(tokenId));
    }
}
