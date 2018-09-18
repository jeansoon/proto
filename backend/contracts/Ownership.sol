pragma solidity ^0.4.24;

contract Ownership {
    address public owner;
    address public newOwner;

    event OwnershipTransferred (address indexed _from, address indexed _to);

    constructor () public
    {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require (msg.sender == owner, "Only owner is allowed");
        _;
    }

    function transferOwnership (address _newOwner) public
        onlyOwner
    {
        newOwner = _newOwner;
    }

    function acceptOwnership () public
    {
        require (msg.sender == newOwner, "Only new owner is allowed");

        emit OwnershipTransferred (owner, newOwner);

        owner = newOwner;
        newOwner = address(0);
    }

}