pragma solidity ^0.4.24;

import "./Label.sol";
import "./Controllable.sol";
import "./XCoin.sol";
import "./Bank.sol";
import "./Banks.sol";

contract BankService is Label, Controllable {

    string constant CLASS_CODE = "BANK_SERVICE";

    address public bankAddress;

    constructor(address _bankAddress, string _typeCode, string _label, string _description) public
        Label(CLASS_CODE, _typeCode, _label, _description)
    {
        if (address(0) != _bankAddress) {
            bankAddress = _bankAddress;

            // START CAUTION: SHOULD BE REMOVE FROM PRODUCTION
            Bank bank = Bank(bankAddress);
            Banks banks = Banks(bank.banksAddress());
            address xCoinAddress = banks.xCoinAddress();
            require(address(0) != xCoinAddress, "Exchange coin is not available");
            XCoin xCoin = XCoin(xCoinAddress);
            xCoin.faucet(address(this), 900000000000000000000000, "Faucet: BankService");
        }
    }

}
