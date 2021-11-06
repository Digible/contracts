pragma solidity ^0.8.8;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";

/**
    * @dev DigiGrade Contract V1
  
  
    */
contract DigiGrade is AccessControl {
     using Counters for Counters.Counter;
    Counters.Counter private _gradeIds;
    
   address[] _graders;
    
    constructor() 
    {
         _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
         _graders.push(msg.sender)
        
    }
    