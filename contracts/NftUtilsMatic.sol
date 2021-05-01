pragma solidity 0.6.5;

import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IERC721Supply is IERC721{
    function totalSupply() external view returns (uint256 balance);
    function tokenByIndex(uint256 index) external view returns (uint256 balance);
}

contract NftUtilsMatic {
    
    /// @notice Returns a list of all Tokens IDs assigned to an address.
    /// @param _token The ERC721.
    /// @param _owner The owner whose tokens we are interested in.
    /// @dev This method MUST NEVER be called by smart contract code. First, it's fairly
    ///  expensive but it also returns a dynamic array, which is only supported for web3 calls, and
    ///  not contract-to-contract calls.
    function tokensOfOwner(IERC721Supply _token, address _owner) external view returns(uint256[] memory ownerTokens) {
        uint256 tokenCount = _token.balanceOf(_owner);

        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 totalTokens = _token.totalSupply();
            uint256 resultIndex = 0;
            
            uint256 tokenId;

            for (tokenId = 1; tokenId <= totalTokens; tokenId++) {
                uint256 finalTokenId = _token.tokenByIndex(tokenId - 1);
                if (_token.ownerOf(finalTokenId) == _owner) {
                    result[resultIndex] = finalTokenId;
                    resultIndex++;
                }
            }

            return result;
        }
    }
}