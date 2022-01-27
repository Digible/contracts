pragma solidity ^0.8.11;
 
pragma experimental ABIEncoderV2;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol";

// @dev DigiRoyalty V1.
contract DigiRoyalty is ReentrancyGuard {
    using SafeMath for uint256;
    
    event RoyaltySet(address indexed nftContractAddress, uint256 tokenId, address indexed beneficiaryWallet, uint256 amount_bps);   
 
    mapping (address => mapping(uint256 => Royalty)) public royaltiesByTokenByContractAddress;

    struct Royalty {
        uint256 amount_bps;
        address beneficiaryWallet;
    }

    // @dev sets royalty for any contract 
    function setRoyaltyforTokenAny (
        address _contractAddress,
        uint256 _tokenId, 
        address _beneficiaryAddress, 
        uint256 _fee
        ) 
        nonReentrant external {
        
        require(msg.sender == (IERC721)(_contractAddress).ownerOf(_tokenId), "Not the owner");          
        require(royaltiesByTokenByContractAddress[_contractAddress][_tokenId].beneficiaryWallet == address(0), "Royalty already set");
        royaltiesByTokenByContractAddress[_contractAddress][_tokenId] = Royalty({
            beneficiaryWallet: _beneficiaryAddress,
            amount_bps: _fee
        });

        emit RoyaltySet(_contractAddress, _tokenId, _beneficiaryAddress, _fee);
    }

    function calculateRoyalty(address _nftContractAddress, uint256 _tokenId, uint256 saleAmount) external returns (uint256)
    {
          return saleAmount.mul(royaltiesByTokenByContractAddress[_nftContractAddress][_tokenId].amount_bps).div(10000); 
      
    } 



}