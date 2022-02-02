// SPDX-License-Identifier: MIT
// @dev DigiTrack Version 1 Tracks Where the item is.
pragma solidity 0.8.11;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";





contract DigiTrack is AccessControl {
  

mapping (address => mapping (uint256 => string)) public phygitalStatus;
mapping (address => mapping (uint256 => address)) public digisafeOperator;

bytes32 public constant DIGISAFE = keccak256("DIGISAFE"); //0x5cc3257ddf2cf0b55d4fe73dde4c462a068a696d19b4b0f5e81a90f679fff734

constructor () public {
  _setupRole(DEFAULT_ADMIN_ROLE, msg.sender); 

}

function updateStatus(address _nftAddress, uint256 _tokenId, string memory _newStatus) external {
require(hasRole(DIGISAFE, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Admin only");
phygitalStatus[_nftAddress][_tokenId] = _newStatus;
digisafeOperator[_nftAddress][_tokenId] = address(msg.sender);

}

function getStatus(address _nftAddress, uint256 _tokenId) external view returns( string memory) {
    return phygitalStatus[_nftAddress][_tokenId];

}


}

