// SPDX-License-Identifier: MIT
// @dev DigiTrack Version 1 Tracks Where the item is.
pragma solidity 0.8.11;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";





contract DigiTrack is AccessControl {

event StatusUpdated(address indexed nftAddress, uint256  indexed tokenId, string newStatus, address digiSafeWallet);  

mapping (address => mapping (uint256 => string)) public phygitalStatus;
mapping (address => mapping (uint256 => address)) public digisafeOperator;

bytes32 public constant DIGISAFE = keccak256("DIGISAFE"); //0x5cc3257ddf2cf0b55d4fe73dde4c462a068a696d19b4b0f5e81a90f679fff734

constructor () public {
  _setupRole(DEFAULT_ADMIN_ROLE, msg.sender); 

}
//only ADMIN can set digisafe address, otherwise it is digisafe that is making the call
function updateStatus(address _nftAddress, uint256 _tokenId, string memory _newStatus, address _digiSafeAddress) public {
require(hasRole(DIGISAFE, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Admin only");
address digisafeAddress = address(msg.sender);
if(hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {digisafeAddress = _digiSafeAddress;}
phygitalStatus[_nftAddress][_tokenId] = _newStatus;
digisafeOperator[_nftAddress][_tokenId] = digisafeAddress;
emit StatusUpdated(_nftAddress, _tokenId, _newStatus, digisafeAddress);

}

function updateStatusBulk(address _nftAddress, uint256 _startTokenId, uint256 _endTokenId, string memory _newStatus, address _digiSafeAddress) external {
for (uint256 i = _startTokenId; i <= _endTokenId; i++){
    updateStatus(_nftAddress, i, _newStatus, _digiSafeAddress);
}

}

function getStatus(address _nftAddress, uint256 _tokenId) external view returns( string memory) {
    return phygitalStatus[_nftAddress][_tokenId];

}


}

