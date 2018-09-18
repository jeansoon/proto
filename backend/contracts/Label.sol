pragma solidity ^0.4.24;

/**
 * @title Label contract
 * @dev Implementation of the controllable operations
 */
contract Label {
    string public classCode;
    string public typeCode;
    string public label;
    string public description;

    constructor(string _classCode, string _typeCode, string _label, string _description) public
    {
        classCode = _classCode;
        typeCode = _typeCode;
        label = _label;
        description = _description;
    }
}
