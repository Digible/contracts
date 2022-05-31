// Bulk URI Update for digiNFTs. V2.0
// ADMIN Only usage

pragma solidity 0.8.11;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";


contract IdigiNFTUri {
    function setTokenUri(uint256 tokenId, string memory tokenURI)
        public
        returns (bool)
    {}

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        returns (string memory)
    {}
}

//@dev v2 with access control
contract BulkTokenURIUpdate is AccessControl {
    constructor() public {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function bulkSetUri(
        uint256 startTokenId,
        uint256 endTokenId,
        string memory tokenURI,
        address digiNFTContractAddress
    ) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "ADMIN ONLY");
        
        for (uint256 i = startTokenId; i <= endTokenId; i++) {
            IdigiNFTUri(digiNFTContractAddress).setTokenUri(i, tokenURI);
        }
    }

    function tokenURI(address digiNFTContractAddress, uint256 tokenId)
        external
        view
        returns (string memory)
    {
       return  IdigiNFTUri(digiNFTContractAddress).tokenURI(tokenId);
    }
}
