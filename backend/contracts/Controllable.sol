pragma solidity ^0.4.24;

import "./Ownership.sol";

/**
 * @title Controllable contract
 * @dev Implementation of the controllable operations
 */
contract Controllable is Ownership {
    // ========================
    // ** ABSTRACT FUNCTIONS **
    // ========================

    /**
    * Seal requirements
    */
    function sealRequirement() private view;

    bool public stopped;
    bool public sealed;

    event Stopped();
    event Resumed();
    event Sealed();
    event Destroyed();

    modifier isStopped {
        require(!stopped);
        _;
    }

    modifier isSealed {
        require(sealed);
        _;
    }
    
    modifier isNotSealed {
        require(!sealed);
        _;
    }
    
    modifier isUsable {
        if (!sealed)
            require(owner == msg.sender);
        else
            require(!stopped);
        _;
    }

    constructor() public
    {
        sealed = true;
    }

    function stopMe () public
        onlyOwner
        returns(bool success)
    {
        stopped = true;
        emit Stopped ();
        return true;
    }
    
    function resumeMe () public
        onlyOwner
        returns(bool success)
    {
        stopped = false;
        emit Resumed ();
        return true;
    }

    function seal() public
        onlyOwner
        isNotSealed
        returns(bool success)
    {
        require(address(0) == newOwner, "Transfer ownership is incomplete");
        
        sealRequirement();
        sealed = true;
        
        emit Sealed();
        return true;
    }

    function destroy() public
        onlyOwner
    {
        // Mark this contract is not usable
        stopMe();
        emit Destroyed();

        // Destroy this contract and refund to owner
        selfdestruct (owner);
    }

}
