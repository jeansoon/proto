pragma solidity ^0.4.24;

import "./SafeMathLib.sol";

library ListLib {
    using SafeMath for uint256;

    bool constant HEAD = false;
    bool constant TAIL = true;

    /**
     * Address List
     */
    struct AddressList {
        uint256 count;
        mapping(address => bool) inUsed;
        mapping(address => mapping(bool => address)) list;
    }

    function addressList(AddressList storage self) internal view
        returns (address[] items)
    {
        items = new address[](self.count);
        address a = firstAddress(self);

        for (uint256 i = 0; 0 != a; i = i.add(1)) {
            items[i] = a;
            a = nextAddress(self, a);
        }
    }

    function addressInUsed(AddressList storage self, address _item) internal view
        returns (bool)
    {
        return self.inUsed[_item];
    }

    function firstAddress(AddressList storage self) internal view
        returns (address)
    {
        return self.list[address(0)][TAIL];
    }

    function lastAddress(AddressList storage self) internal view
        returns (address)
    {
        return self.list[address(0)][HEAD];
    }

    function nextAddress(AddressList storage self, address _item) internal view
        returns (address)
    {
        return self.list[_item][TAIL];
    }

    function pushAddress(AddressList storage self, address _item) internal
        returns (bool success)
    {
        require(address(0) != _item, "Zero address is not usable");

        if (!self.inUsed[_item]) {
            // Initialize node
            self.list[_item][TAIL] = address(0);
            self.list[_item][HEAD] = self.list[address(0)][HEAD];

            // Insert the new node
            self.list[self.list[address(0)][HEAD]][TAIL] = _item;
            self.list[address(0)][HEAD] = _item;

            self.inUsed[_item] = true;

            self.count = self.count.add(1);

            return true;
        }

        return false;
    }

    function removeAddress(AddressList storage self, address _item) internal
        returns (bool success)
    {
        if (self.inUsed[_item]) {
            self.list[self.list[_item][TAIL]][HEAD] = self.list[_item][HEAD];
            self.list[self.list[_item][HEAD]][TAIL] = self.list[_item][TAIL];

            delete self.list[_item][TAIL];
            delete self.list[_item][HEAD];
            delete self.inUsed[_item];

            self.count = self.count.sub(1);

            return true;
        }

        return false;
    }

    /**
     * UINT256 List
     */
    struct Uint256List {
        uint256 count;
        mapping(uint256 => bool) inUsed;
        mapping(uint256 => mapping(bool => uint256)) list;
    }

    function uint256List(Uint256List storage self) internal view
        returns (uint256[] items)
    {
        items = new uint256[](self.count);
        uint256 a = firstUint256(self);

        for (uint256 i = 0; 0 != a; i = i.add(1)) {
            items[i] = a;
            a = nextUint256(self, a);
        }
    }

    function uint256InUsed(Uint256List storage self, uint256 _item) internal view
        returns (bool)
    {
        return self.inUsed[_item];
    }

    function firstUint256(Uint256List storage self) internal view
        returns (uint256)
    {
        return self.list[0][TAIL];
    }

    function lastUint256(Uint256List storage self) internal view
        returns (uint256)
    {
        return self.list[0][HEAD];
    }

    function nextUint256(Uint256List storage self, uint256 _item) internal view
        returns (uint256)
    {
        return self.list[_item][TAIL];
    }

    function pushUint256(Uint256List storage self, uint256 _item) internal
        returns (bool success)
    {
        require(0 != _item, "Zero value is not usable");
        
        if (!self.inUsed[_item]) {
            // Initialize node
            self.list[_item][TAIL] = 0;
            self.list[_item][HEAD] = self.list[0][HEAD];

            // Insert the new node
            self.list[self.list[0][HEAD]][TAIL] = _item;
            self.list[0][HEAD] = _item;

            self.inUsed[_item] = true;

            self.count = self.count.add(1);

            return true;
        }

        return false;
    }

    function removeUint256(Uint256List storage self, uint256 _item) internal
        returns (bool success)
    {
        if (self.inUsed[_item]) {
            self.list[self.list[_item][TAIL]][HEAD] = self.list[_item][HEAD];
            self.list[self.list[_item][HEAD]][TAIL] = self.list[_item][TAIL];

            delete self.list[_item][TAIL];
            delete self.list[_item][HEAD];
            delete self.inUsed[_item];

            self.count = self.count.sub(1);

            return true;
        }

        return false;
    }

}
