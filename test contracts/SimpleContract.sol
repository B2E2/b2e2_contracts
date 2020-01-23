pragma solidity ^0.5.0;

contract SimpleContract {
    uint256 public field;
    
    constructor() public {
        field = 5;
    }
    
    function setField(uint256 number) public {
        field = number;
    }
}