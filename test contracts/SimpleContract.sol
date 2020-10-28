pragma solidity ^0.7.0;

contract SimpleContract {
    uint256 public field;
    
    constructor() {
        field = 5;
    }
    
    function setField(uint256 number) public {
        field = number;
    }
}
