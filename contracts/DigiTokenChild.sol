pragma solidity 0.6.5;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./DigiToken.sol";

contract DigiTokenChild is DigiToken {
    using SafeMath for uint256;
    address public childChainManagerProxy;
    address deployer;

    constructor () public DigiToken(0) {
        childChainManagerProxy = 0xb5505a6d998549090530911180f38aC5130101c6; // Matic: 0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa
        deployer = msg.sender;
    }

    function deposit(address user, bytes calldata depositData) external {
        require(msg.sender == childChainManagerProxy, "You're not allowed to deposit");

        uint256 amount = abi.decode(depositData, (uint256));
        _mint(user, amount);
    }

    function withdraw(uint256 amount) external {
        _burn(_msgSender(), amount);
    }
}
