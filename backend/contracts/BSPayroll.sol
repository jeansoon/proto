pragma solidity ^0.4.24;

import "./SafeMathLib.sol";
import "./BankService.sol";
import "./BankAccount.sol";
import "./Bank.sol";
import "./Banks.sol";

contract BSPayroll is BankService {
    using SafeMath for uint256;

    string constant TYPE_CODE = "PAYROLL";

    event ServiceTransfer(uint256 transactionId, uint256 timestamp, uint256 indexed soPAN, uint256 indexed toPAN, uint256 soValue, uint256 toValue, uint256 fee, uint256 rate);
    event ServiceTransaction(uint256 transactionId, uint256 timestamp, uint256 indexed soPAN, uint256 soValues, uint256 toCount, uint256 soFees);

    struct Transaction {
        bool inUsed;
        uint256 timestamp;
        uint256 soPAN;
        uint256 soValues;
        uint256 toCount;
        uint256 soFees;
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

    function transfer(address _sender, string _metadata, uint256 _soPAN, uint256[] _toPANs, uint256[] _values, uint256[] _fees, uint256[] _rates) public
        isUsable
        returns(uint256 transactionId)
    {

        (Bank sob, BankAccount soa, address soAddress) = banks.getBankAccount(_soPAN);
        require(msg.sender == address(soa) && _sender == soAddress, "Access denied");

        transactionId = banks.transactionsCount(_sender);

        require(!transactions[_sender][transactionId].inUsed, "Duplicated transaction id");

        Transaction storage transaction = transactions[_sender][transactionId];

        transaction.inUsed = true;
        transaction.timestamp = now;
        transaction.soPAN = _soPAN;
        transaction.metadata = _metadata;

        balancesTransfer(transaction, transactionId, sob, _soPAN, _toPANs, _values, _fees, _rates);
    }

    function balancesTransfer(Transaction storage transaction, uint256 _transactionId, Bank _sob, uint256 _soPAN, uint256[] _toPANs,
        uint256[] _values, uint256[] _fees, uint256[] _rates) private
    {
        uint256 soValue;

        for (uint256 i = 0; _toPANs.length > i; i = i.add(1)) {
            require(100 == _fees[i], "Fee is mismatched");

            // Perform balance transfers
            soValue = _sob.serviceTransfer(_soPAN, _toPANs[i], _values[i], _fees[i], 0, _rates[i]);

            transaction.soValues = transaction.soValues.add(soValue);
            transaction.toCount = transaction.toCount.add(1);
            transaction.soFees = transaction.soFees.add(_fees[i]);

            emit ServiceTransfer(_transactionId, now, _soPAN, _toPANs[i], soValue, _values[i], _fees[i], _rates[i]);
        }

        emit ServiceTransaction(_transactionId, transaction.timestamp, _soPAN, transaction.soValues, transaction.toCount, transaction.soFees);
    }

    function transferInfo(address /*_sender*/, uint256 _soPAN, uint256[] _toPANs, uint256[] _values) public view
        isUsable
        returns(uint256[] fees /* soFees */, uint256[] rates, uint256[] soValues)
    {
        fees = new uint256[](_toPANs.length);
        rates = new uint256[](_toPANs.length);
        soValues = new uint256[](_toPANs.length);

        (, BankAccount soa,) = banks.getBankAccount(_soPAN);
        uint16 soaCurrencyCode = soa.currencyCode();

        BankAccount toa;

        for (uint256 i = 0; _toPANs.length > i; i = i.add(1)) {
            (, toa,) = banks.getBankAccount(_toPANs[i]);

            fees[i] = 100;
            rates[i] = soa.getExchangeRate(soaCurrencyCode, toa.currencyCode());

            if (address(soa) == address(toa))
                soValues[i] = _values[i];
            else
                soValues[i] = soa.getExchangeValueByRate(_values[i], rates[i]);
        }
    }

    function sealRequirement() private view
    {
    }

}
