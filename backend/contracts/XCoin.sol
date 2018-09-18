pragma solidity ^0.4.24;

import "./Label.sol";
import "./StandardToken.sol";

contract XCoin is Label, StandardToken {
    using SafeMath for uint256;

    string constant CLASS_CODE = "XCOIN";

    event AddedSupply(address indexed owner, uint256 value, string remarks);
    event ReducedSupply(address indexed owner, uint256 value, string remarks);

    uint16 public currencyCode;
    string public symbol;
    uint8 public decimals;

    // Exchange rate (mapped: source currency code + target currency code => rate)
    mapping(uint16 => mapping(uint16 => uint256)) exchangeRates;

    constructor(string _typeCode, string _label, string _description, string _symbol, uint256 _initialSupply, uint8 _decimals, uint16 _currencyCode,
        uint16[] _soCurrencyCodes, uint16[] _toCurrencyCodes, uint256[] _rates) public
        Label(CLASS_CODE, _typeCode, _label, _description)
    {
        require(0 != _currencyCode, "Currency code is empty");

        symbol = _symbol; // Currency code
        decimals = _decimals;

        addSupply(_initialSupply, "Initial supply");

        currencyCode = _currencyCode;

        if (0 < _soCurrencyCodes.length)
            setExchangeRateBatch(_soCurrencyCodes, _toCurrencyCodes, _rates);
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
        require(0 != rate && 0 != _soCurrencyCode, "Exchane rate is not found");
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

    /**
     * CAUTION: SHOULD BE REMOVE FROM PRODUCTION
     */
    function faucet(address _to, uint256 _value, string _remarks) public
        isUsable
        returns(bool success)
    {
        // Faucet some balance
        totalSupply_ = totalSupply_.add(_value);
        balances[_to] = balances[_to].add(_value);

        emit AddedSupply(_to, _value, _remarks);

        return true;
    }

    /**
     * CAUTION: SHOULD BE REMOVE FROM PRODUCTION
     */
    function faucetBatch(address[] _tos, uint256 _value, string _remarks) public
        isUsable
        returns(bool success)
    {
        // Faucet some balance
        for (uint256 i = 0; _tos.length > i; i = i.add(1)) {
            totalSupply_ = totalSupply_.add(_value);
            balances[_tos[i]] = balances[_tos[i]].add(_value);

            emit AddedSupply(_tos[i], _value, _remarks);
        }

        return true;
    }

    function sealRequirement() private view
    {
    }

}
