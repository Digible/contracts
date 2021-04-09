pragma solidity 0.6.5;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// This contract is for demo purposes only
contract StableToken is ERC20 {
    constructor () public ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 100000000000000000000000); // 100,000.00
    }
}
