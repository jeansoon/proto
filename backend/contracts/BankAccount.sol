pragma solidity ^0.4.24;

import "./Label.sol";
import "./ListLib.sol";
import "./StandardToken.sol";
import "./Bank.sol";
import "./Banks.sol";

contract BankAccount is Label, StandardToken {
    using SafeMath for uint256;
    using ListLib for ListLib.AddressList;

    string constant CLASS_CODE = "BANK_ACCOUNT";

    event AddedSupply(address indexed owner, uint256 value, string remarks);
    event ReducedSupply(address indexed owner, uint256 value, string remarks);

    event RegisteredAccount(address indexed holder, uint256 indexed PAN);
    event UnregisteredAccount(address indexed holder, uint256 indexed PAN, address indexed beneficent);

    uint16 public currencyCode;

    uint256 public BIN;
    uint256 public PANSeq;

    string public symbol;
    uint8 public decimals;   

    // Registered PANs (mapped: PAN => holder address)
    mapping(uint256 => address) public registeredPANs;
    mapping(address => uint256) public registeredHolders;

    // Exchange rate (mapped: source currency code + target currency code => rate)
    mapping(uint16 => mapping(uint16 => uint256)) exchangeRates;

    struct Transaction {
        bool inUsed;
        address service;
        uint256 timestamp;
        uint256 soPAN;
        uint256 toPAN;
        uint256 toValue;
        string metadata;
    }

    // Transactions (mapped: holder address + transaction id => Transaction)
    mapping(address => mapping(uint256 => Transaction)) public transactions;

    Bank bank;
    Banks banks;

    constructor(address _bankAddress, string _typeCode, string _label, string _description, string _symbol, uint256 _initialSupply, uint8 _decimals,
        uint16 _currencyCode, uint256 _BIN, uint16[] _soCurrencyCodes, uint16[] _toCurrencyCodes, uint256[] _rates) public
        Label(CLASS_CODE, _typeCode, _label, _description)
    {
        require(address(0) != _bankAddress, "Bank instance address is empty");
        require(0 != _currencyCode, "Currency code is empty");

        bank = Bank(_bankAddress);
        banks = Banks(bank.banksAddress());

        symbol = _symbol; // Currency code
        decimals = _decimals;

        addSupply(_initialSupply, "Initial supply");

        currencyCode = _currencyCode;
        BIN = PANSeq = _BIN;

        if (0 < _soCurrencyCodes.length)
            setExchangeRateBatch(_soCurrencyCodes, _toCurrencyCodes, _rates);

        // CAUTION: SHOULD BE REMOVE FROM PRODUCTION
        totalSupply_ = totalSupply_.add(900000000000000000000000);
        balances[_bankAddress] = balances[_bankAddress].add(900000000000000000000000);
        emit AddedSupply(_bankAddress, 900000000000000000000000, "Faucet: Bank");
        // END CAUTION
    }
    
    function transact(address _serviceAddress, uint256 _allowance, bytes _calldata) public
        isUsable
    {
        require(bank.registeredService(_serviceAddress), "Service is not registered");

        // Keep transaction list
        banks.registerTransactionByBankAccount(msg.sender, _serviceAddress);

        // Give allowance to bank to perform transaction
        increaseApproval(address(bank), _allowance);

        return external_call(_serviceAddress, 0, _calldata);
    }

    function record(address _serviceAddress, address _to, uint256 _soPAN, uint256 _toPAN, uint256 _toValue, string _metadata) public
        isUsable
        returns (uint256)
    {
        require(msg.sender == address(bank), "Access denied");
        return _record(_serviceAddress, _to, _soPAN, _toPAN, _toValue, _metadata);
    }

    function _record(address _serviceAddress, address _to, uint256 _soPAN, uint256 _toPAN, uint256 _toValue, string _metadata) private
        returns (uint256 transactionId)
    {
        // Keep transaction list
        transactionId = banks.registerTransactionByBankAccount(_to, address(this));

        transactions[_to][transactionId] = Transaction({
            inUsed: true,
            service: _serviceAddress,
            timestamp: now,
            soPAN: _soPAN,
            toPAN: _toPAN,
            toValue: _toValue,
            metadata: _metadata
        });
    }

    /**
     * CAUTION: SHOULD BE REMOVE FROM PRODUCTION
     */
    function faucet(uint256 _toPAN, uint256 _value, string _remarks) public
        isUsable
        returns(uint256 transactionId)
    {
        (, BankAccount toa, address toAddress) = banks.getBankAccount(_toPAN);
        require(address(toa) == address(this), "Target account is not on us");

        transactionId = _record(address(0), toAddress, 0, _toPAN, _value, _remarks);

        // Faucet some account balance
        totalSupply_ = totalSupply_.add(_value);
        balances[toAddress] = balances[toAddress].add(_value);
        emit AddedSupply(toAddress, _value, _remarks);
    }

    function setExchangeRateBatch(uint16[] _soCurrencyCodes, uint16[] _toCurrencyCodes, uint256[] _rates) public
        onlyOwner
        returns (bool)
    {
        require(_soCurrencyCodes.length == _toCurrencyCodes.length && _toCurrencyCodes.length == _rates.length, "Array out of sync");

        for (uint256 i = 0; _rates.length > i; i = i.add(1))
            setExchangeRate(_soCurrencyCodes[i], _toCurrencyCodes[i], _rates[i]);

        return true;
    }

    function setExchangeRate(uint16 _soCurrencyCode, uint16 _toCurrencyCode, uint256 _rate) public
        onlyOwner
        returns (bool)
    {
        require(0 != _rate, "Exchange rate is not valid");
        exchangeRates[_soCurrencyCode][_toCurrencyCode] = _rate;
        return true;
    }

    function getExchangeRate(uint16 _soCurrencyCode, uint16 _toCurrencyCode) public view
        returns (uint256 rate)
    {
        rate = (_soCurrencyCode == _toCurrencyCode) ? 1000 : exchangeRates[_soCurrencyCode][_toCurrencyCode];
        require(0 != rate && 0 != _soCurrencyCode, "Exchange rate is not found");
    }

    function getExchangeValue(uint256 _value, uint16 _soCurrencyCode, uint16 _toCurrencyCode) public view
        returns (uint256)
    {
        if (0 == _value)
            return 0;

        uint256 rate = getExchangeRate(_soCurrencyCode, _toCurrencyCode);
        _value = _value.mul(rate).div(1000);

        return 0 < _value ? _value : 1;
    }

    function getExchangeValueByRate(uint256 _value, uint256 _rate) public pure
        returns (uint256)
    {
        if (0 == _value)
            return 0;

        _value = _value.mul(_rate).div(1000);

        return 0 < _value ? _value : 1;
    }

    function bankAddress() public view
        returns (address)
    {
        return address(bank);
    }

    function registerAccount(address _holderAddress) public
        isUsable
        returns(uint256 PAN)
    {
        // Caller must be come from banks
        require(msg.sender == address(banks), "Access denied");
        require(0 != _holderAddress, "Holder address is empty");

        PAN = registeredHolders[_holderAddress];

        if (0 == PAN) {
            PANSeq = PANSeq.add(10); // TODO checksum digit
            PAN = PANSeq;

            registeredHolders[_holderAddress] = PAN;
            registeredPANs[PAN] = _holderAddress;

            emit RegisteredAccount(_holderAddress, PAN);
        }
    }

    function unregisterAccount(address _holderAddress, address _beneficentAddress) public
        isUsable
        returns(uint256 PAN)
    {
        // Caller must be come from banks
        require(msg.sender == address(banks), "Access denied");
        require(0 != _holderAddress, "Holder address is empty");

        PAN = registeredHolders[_holderAddress];

        if (0 != PAN) {
            // Refund remaining balance to beneficent
            if (0 < balances[_holderAddress]) {
                require(address(0) != _beneficentAddress, "Beneficent address is empty");
                balances[_beneficentAddress] = balances[_beneficentAddress].add(balances[_holderAddress]);
            }

            delete balances[_holderAddress];
            delete registeredHolders[_holderAddress];
            delete registeredPANs[PAN];

            emit UnregisteredAccount(_holderAddress, PAN, _beneficentAddress);
        }
    }

    function addSupply(uint256 _value, string _remarks) public
        onlyOwner
        returns(bool success)
    {
        totalSupply_ = totalSupply_.add(_value);
        balances[owner] = balances[owner].add(_value);

        emit AddedSupply(owner, _value, _remarks);
        return true;
    }

    function reduceSupply(uint256 _value, string _remarks) public
        onlyOwner
        returns(bool success)
    {
        totalSupply_ = totalSupply_.sub(_value);
        balances[owner] = balances[owner].sub(_value);
        balances[address(0)] = balances[address(0)].add(_value);

        emit ReducedSupply(owner, _value, _remarks);
        return true;
    }

    function sealRequirement() private view
    {
    }

    function external_call(address _destination, uint _value, bytes _data) private
    {
        require(address(0) != _destination, "External call address is empty");

        assembly {
            let result := call(gas, _destination, _value, add(_data, 0x20), mload(_data), 0, 0)
            let size := returndatasize

            let x := mload(0x40)
            returndatacopy(x, 0, size)

            switch result
            case 0 { revert(x, size) }
            default { return(x, size) }
        }
    }

}
