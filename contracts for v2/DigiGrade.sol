pragma solidity ^0.8.9;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";

/**
    * @dev DigiGrade Contract V1
  
    */

contract DigiGrade is AccessControl {
    
    bytes32 public constant GRADER = keccak256("GRADER");
    uint256 _currentGradeId;
     
 
   
    enum DigiGradeInfo{ SMALL, MEDIUM, LARGE }
    
    
    mapping (uint256=>string) name_map;
    mapping (uint256=>string) grade_map;
    mapping (uint256=> string)gradeMetaData_map;

    
   
    
    constructor() 
    {
         _currentGradeId = 121300000;
         _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
         _setupRole(GRADER, msg.sender);
        
    }

function grade(string memory itemName, string memory grade, string memory metaUri)  public returns (uint256)
{
require(hasRole(GRADER, msg.sender), 'DigiGrade: Only for role GRADER');
_currentGradeId++;
name_map[_currentGradeId] = itemName;
grade_map[_currentGradeId] = grade;
gradeMetaData_map[_currentGradeId] = metaUri;

return _currentGradeId;
}

function setItemMetaUri(uint256 itemNumber, string memory newURI_metadata) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 'DigiGrade: Only for role DEFAULT_ADMIN_ROLE');
        require(itemNumber <= _currentGradeId && itemNumber>= 121300000, "DigiGrade: itemNumber doesnt exist");
         gradeMetaData_map[itemNumber] = newURI_metadata;
    }
    
    function lastItemNumber() external  view  returns (uint256) {
     return  _currentGradeId;
    }
      

    /**
    @dev Role Management */


    function setGraderRole(address wallet, bool canGrade) public {
       require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 'DigiGrade: Only for role DEFAULT_ADMIN_ROLE');
       if(canGrade) { return  _setupRole(GRADER, wallet);  } 
       return revokeRole(GRADER, wallet);
    }

    function setAdminRole(address wallet, bool isAdmin) public {
         require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 'DigiGrade: Only for role DEFAULT_ADMIN_ROLE');
         if(isAdmin) {return _setupRole(DEFAULT_ADMIN_ROLE, wallet); }
         return revokeRole(DEFAULT_ADMIN_ROLE, wallet);
    }
    

}
    