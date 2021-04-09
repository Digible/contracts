pragma solidity 0.6.5;

interface IDigiNFT {
    function mint(
        address wallet,
        string calldata cardName,
        bool cardPhysical
    ) external returns (uint256);

    function cardName(uint256 tokenId) external view returns (string memory);
    function cardPhysical(uint256 tokenId) external view returns (bool);
    function transferFrom(address from, address to, uint256 tokenId) external;
}