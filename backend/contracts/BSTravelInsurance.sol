pragma solidity ^0.4.24;

import "./SafeMathLib.sol";
import "./BankService.sol";
import "./BankAccount.sol";
import "./Bank.sol";
import "./Banks.sol";

contract BSTravelInsurance is BankService {
    using SafeMath for uint256;

    string constant TYPE_CODE = "TRAVEL_INSURANCE";

    event ServiceTransaction(uint256 transactionId, uint256 timestamp, uint256 indexed soPAN, uint256 indexed toPAN, uint256 soValue, uint256 toValue, uint256 toFee, uint256 rate);

    struct Transaction {
        bool inUsed;
        uint256 timestamp;
        uint256 soPAN;
        uint256 toPAN;
        uint256 soValue;
        uint256 toValue;
        uint256 toFee;
        uint256 rate;
        string metadata;
    }

    // Transactions (mapped: holder address + transaction id => Transaction)
    mapping(address => mapping(uint256 => Transaction)) public transactions;

    Bank bank;
    Banks banks;

    constructor(address _bankAddress, string _label, string _description) public
        BankService(_bankAddress, TYPE_CODE, _label, _description)
    {
        require(address(0) != _bankAddress, "Bank address is empty");
        bank = Bank(_bankAddress);
        banks = Banks(bank.banksAddress());
    }

    function transfer(address _sender, string _metadata, uint256 _soPAN, uint256 _toPAN, uint256 _toValue, uint256 _toFee, uint256 _rate) public
        isUsable
        returns(uint256 transactionId)
    {
        (Bank sob, BankAccount soa, address soAddress) = banks.getBankAccount(_soPAN);
        require(msg.sender == address(soa) && _sender == soAddress, "Access denied");

        transactionId = banks.transactionsCount(_sender);

        require(100 == _toFee, "Fee mismatched");
        require(!transactions[_sender][transactionId].inUsed, "Duplicated transaction id");

        // Perform balance transfers
        uint256 soValue = sob.serviceTransfer(_soPAN, _toPAN, _toValue, 0, _toFee, _rate);

        transactions[_sender][transactionId] = Transaction({
            inUsed: true,
            timestamp: now,
            soPAN: _soPAN,
            toPAN: _toPAN,
            soValue: soValue,
            toValue: _toValue,
            toFee: _toFee,
            rate: _rate,
            metadata: _metadata
        });

        emit ServiceTransaction(transactionId, now, _soPAN, _toPAN, soValue, _toValue, _toFee, _rate);
    }

    function transferInfo(address /*_sender*/, uint256 _soPAN, uint256 _toPAN, uint256 _toValue) public view
        isUsable
        returns(uint256 toFee, uint256 rate, uint256 soValue)
    {
        (, BankAccount soa,) = banks.getBankAccount(_soPAN);
        (, BankAccount toa,) = banks.getBankAccount(_toPAN);

        // Calculate transaction fee and rate
        toFee = 100;
        rate = soa.getExchangeRate(soa.currencyCode(), toa.currencyCode());

        if (address(soa) == address(toa))
            soValue = _toValue;
        else
            soValue = soa.getExchangeValueByRate(_toValue, rate);
    }

    function sealRequirement() private view
    {
    }

}
