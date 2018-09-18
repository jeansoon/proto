pragma solidity ^0.4.24;

import "./Controllable.sol";
import "./Label.sol";
import "./SafeMathLib.sol";
import "./ListLib.sol";
import "./XCoin.sol";
import "./Banks.sol";
import "./BankAccount.sol";
import "./BankService.sol";

contract Bank is Label, Controllable {
    using SafeMath for uint256;
    using ListLib for ListLib.AddressList;

    string constant CLASS_CODE = "BANK";

    event Destroyed();
    event AddedAccount(address indexed bankAddress, address accountAddress);
    event RemovedAccount(address indexed bankAddress, address accountAddress);

    event AddedService(address indexed bankAddress, address serviceAddress);
    event RemovedService(address indexed bankAddress, address serviceAddress);

    uint16 public countryCode; // ISO 3166-1
    address public banksAddress;
    Banks banks;

    // Exchange coin
    XCoin xCoin;

    // ERC20 Account instance address
    ListLib.AddressList accountsList;

    // Registered BIN ranges
    mapping(uint256 => bool) public registeredBINs;

    // Services
    ListLib.AddressList servicesList;

    constructor (address _banksAddress, string _typeCode, string _label, string _description, uint16 _countryCode) public
        Label(CLASS_CODE, _typeCode, _label, _description)
    {
        require(address(0) != _banksAddress, "Banks instance address is empty");

        banksAddress = _banksAddress;
        countryCode = _countryCode;

        banks = Banks(banksAddress);
        address xCoinAddress = banks.xCoinAddress();
        require(address(0) != xCoinAddress, "XCoin is not available");
        xCoin = XCoin(xCoinAddress);

        // CAUTION: SHOULD BE REMOVE FROM PRODUCTION
        xCoin.faucet(address(this), 900000000000000000000000, "Faucet: Bank");
        // END CAUTION
    }

    /**
     * Caller must provide allowance to transfer fund to target PAN
     *
     * @param _toPAN The target of PAN
     * @param _toValue The target of value
     */
    function transfer(address _serviceAddress, uint256 _soPAN, uint256 _toPAN, uint256 _toValue) public
        isUsable
        returns(bool success)
    {
        require(banks.registeredBank(msg.sender), "Access denied");

        (Bank tob, BankAccount toa, address toAddress) = banks.getBankAccount(_toPAN);

        // Claim allowance from sender
        uint256 xcValue = xCoin.getExchangeValue(_toValue, toa.currencyCode(), xCoin.currencyCode());
        xCoin.transferFrom(msg.sender, address(this), xcValue);

        // Is that on us transfer
        if (accountsList.addressInUsed(address(toa))) {
            toa.transfer(toAddress, _toValue);
            toa.record(_serviceAddress, toAddress, _soPAN, _toPAN, _toValue, "");
        }
        else {
            // Transform toValue into xCoin value to target
            xCoin.increaseApproval(address(tob), xcValue);
            tob.transfer(_serviceAddress, _soPAN, _toPAN, _toValue);
        }

        return true;
    }

    /**
     * Called by service provider to transfer fund
     *
     * @param _soPAN The source of PAN
     * @param _toPAN The target of PAN
     * @param _toValue The target of value
     * @param _soFee The source of fee that pay by sender
     * @param _toFee The target of fee that pay by receiver
     * @param _rate The exchage rate
     */
    function serviceTransfer(uint256 _soPAN, uint256 _toPAN, uint256 _toValue, uint256 _soFee, uint256 _toFee, uint256 _rate) public
        isUsable
        returns (uint256)
    {
        // sender must be registered service provider
        require(servicesList.addressInUsed(msg.sender), "Access denied");

        (Bank sob, BankAccount soa, address soAddress) = banks.getBankAccount(_soPAN);
        (, BankAccount toa, address toAddress) = banks.getBankAccount(_toPAN);

        require(address(sob) == address(this), "Source of fund is not on us");
        require(_rate == soa.getExchangeRate(soa.currencyCode(), toa.currencyCode()), "Exchange rate mismatched");

        // Convert fees into xCoin value to pay service provider
        feesTransfer(soa, toa, _soFee, _toFee);

        if (address(soa) != address(toa))
            return balancesTransfer(_soPAN, _toPAN, _toValue, _soFee, _toFee, _rate);

        toa.transferFrom(soAddress, toAddress, _toValue);
        toa.record(msg.sender, toAddress, _soPAN, _toPAN, _toValue, "");

        // Claim transaction fee
        if (0 < _soFee)
            soa.transferFrom(soAddress, address(this), _soFee);

        return _toValue;
    }

    /**
     * Perform fee transfer
     */
    function feesTransfer(BankAccount _soa, BankAccount _toa, uint256 _soFee, uint256 _toFee) private
    {
        if (0 < _soFee || 0 < _toFee) {
            uint256 xcValue = xCoin.getExchangeValue(_soFee, _soa.currencyCode(), xCoin.currencyCode());

            if (0 < _toFee)
                xcValue = xcValue.add(xCoin.getExchangeValue(_toFee, _toa.currencyCode(), xCoin.currencyCode()));

            xCoin.transfer(msg.sender, xcValue);
        }
    }

    /**
     * Perform fund transfer
     */
    function balancesTransfer(uint256 _soPAN, uint256 _toPAN, uint256 _toValue, uint256 _soFee, uint256 _toFee, uint256 _rate) private
        returns (uint256 soValue)
    {
        (, BankAccount soa, address soAddress) = banks.getBankAccount(_soPAN);
        (Bank tob, BankAccount toa,) = banks.getBankAccount(_toPAN);

        // Convert toValue to source currency
        soValue = soa.getExchangeValueByRate(_toValue, _rate);

        // Claim transfer value and transaction fee
        soa.transferFrom(soAddress, address(this), soValue.add(_soFee));

        // Transform (toValue - toFee) into xCoin value to target bank
        xCoin.increaseApproval(address(tob), xCoin.getExchangeValue(_toValue.sub(_toFee), toa.currencyCode(), xCoin.currencyCode()));
        tob.transfer(msg.sender, _soPAN, _toPAN, _toValue.sub(_toFee));
    }
    
    function addAccount(address _accountAddress) public
        onlyOwner
        returns(bool success)
    {
        require(address(0) != _accountAddress, "Account address is empty");
        BankAccount account = BankAccount(_accountAddress);
        uint256 BIN = account.BIN();

        require(account.sealed(), "Account instance is not sealed");
        require(!registeredBINs[BIN], "Duplicated account BIN range");
        require(accountsList.pushAddress(_accountAddress), "Duplicated account instance");

        registeredBINs[BIN] = true;

        banks.emitAddedBankAccount(_accountAddress);
        return true;
    }

    function removeAccount(address _accountAddress) public
        onlyOwner
        returns(bool success)
    {
        if (accountsList.removeAddress(_accountAddress)) {
            BankAccount account = BankAccount(_accountAddress);
            uint256 BIN = account.BIN();

            delete registeredBINs[BIN];

            banks.emitRemovedBankAccount(_accountAddress);
        }

        return true;
    }

    function getAccounts() public view
        returns (address[])
    {
        return accountsList.addressList();
    }

    function getAccountsCount() public view
        returns (uint256)
    {
        return accountsList.count;
    }

    function getNextAccount(address _accountAddress) public view
        returns (address)
    {
        return accountsList.nextAddress(_accountAddress);
    }

    function registeredAccount(address _accountAddress) public view
        returns (bool)
    {
        return accountsList.addressInUsed(_accountAddress);
    }

    function addService(address _serviceAddress) public
        onlyOwner
        returns(bool success)
    {
        BankService service = BankService(_serviceAddress);

        require(service.sealed(), "Service instance is not sealed");
        require(servicesList.pushAddress(_serviceAddress), "Duplicated service instance");

        banks.emitAddedBankService(_serviceAddress);
        return true;
    }

    function removeService(address _serviceAddress) public
        onlyOwner
        returns(bool success)
    {
        if (servicesList.removeAddress(_serviceAddress))
            banks.emitRemovedBankService(_serviceAddress);
        return true;
    }

    function getServices() public view
        returns (address[])
    {
        return servicesList.addressList();
    }

    function getServicesCount() public view
        returns (uint256)
    {
        return servicesList.count;
    }

    function getNextService(address _serviceAddress) public view
        returns (address)
    {
        return servicesList.nextAddress(_serviceAddress);
    }

    function registeredService(address _serviceAddress) public view
        returns (bool)
    {
        return servicesList.addressInUsed(_serviceAddress);
    }

    function sealRequirement() private view
    {
    }

}
