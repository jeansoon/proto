pragma solidity ^0.4.24;

import "./Controllable.sol";
import "./Label.sol";
import "./SafeMathLib.sol";
import "./ListLib.sol";
import "./Bank.sol";
import "./BankAccount.sol";
import "./XCoin.sol";

contract Banks is Label, Controllable {
    using SafeMath for uint256;
    using ListLib for ListLib.AddressList;
    using ListLib for ListLib.Uint256List;

    string constant CLASS_CODE = "BANKS";

    event AddedBank(address indexed bank);
    event RemovedBank(address indexed bank);
    event AddedBankAccount(address indexed bank, address account);
    event RemovedBankAccount(address indexed bank, address account);
    event AddedBankService(address indexed bank, address service);
    event RemovedBankService(address indexed bank, address service);

    event RegisteredAccount(address indexed account, address indexed holder, uint256 PAN);
    event UnregisteredAccount(address indexed account, address indexed holder, uint256 PAN, address beneficent);

    struct AccountLink {
        address account;
        address holder;
    }

    // Banks instance address
    ListLib.AddressList banksList;

    // Exchange Coin
    XCoin xCoin;

    // Account holder list (mapped: holder address => PAN list)
    mapping(address => ListLib.Uint256List) holderPANsList;

    // Registered PAN (mapped: PAN => AccountLink)
    mapping(uint256 => AccountLink) public registeredPANs;
    uint256 public registeredPANsCount;

    struct Transaction {
        address source;
    }

    // Transactions (mapped: holder address + transaction id => Transaction)
    mapping(address => mapping(uint256 => Transaction)) public transactions;
    mapping(address => uint256) public transactionsCount;

    constructor(address _xCoinAddress, string _typeCode, string _label, string _description) public
        Label(CLASS_CODE, _typeCode, _label, _description)
    {
        require(address(0) != _xCoinAddress, "XCoin is not provided");
        xCoin = XCoin(_xCoinAddress);
    }

    /**
     * Retrieve xCoin address
     */
    function xCoinAddress() public view
        returns (address)
    {
        return address(xCoin);
    }

    /**
     * Retrieve transactions
     */
    function getTransactions(uint256 _limit) public view
        returns (address[], uint256)
    {
        return getTransactionsByAddress(msg.sender, _limit);
    }

    /**
     * Retrieve transactions
     */
    function getTransactionsByAddress(address _sender, uint256 _limit) public view
        returns (address[] sources, uint256 transactionId)
    {
        uint256 i;
        uint256 count = transactionId = transactionsCount[_sender];

        if (0 == _limit || _limit > count)
            _limit = count;

        sources = new address[](_limit);
        
        while (_limit > i) {
            sources[i] = transactions[_sender][count].source;

            count = count.sub(1);
            i = i.add(1);
        }
    }

    /**
     * Retrieve transaction id
     */
    function getTransactionId() public view
        returns (uint256)
    {
        return getTransactionIdByAddress(msg.sender);
    }

    /**
     * Retrieve transaction id by others
     */
    function getTransactionIdByAddress(address _sender) public view
        returns (uint256)
    {
        return transactionsCount[_sender].add(1);
    }

    function registerTransactionByBankAccount(address _sender, address _sourceAddress) public
        returns (uint256)
    {
        // Check msg.sender is registered BankAccount
        require (registeredBankAccount(msg.sender), "Access denied");
        return _registerTransaction(_sender, _sourceAddress);
    }

    function registerTransactionByOwner(address _sender, address _sourceAddress) public
        onlyOwner
        returns (uint256)
    {
        return _registerTransaction(_sender, _sourceAddress);
    }

    function _registerTransaction(address _sender, address _sourceAddress) private
        isUsable
        returns (uint256 transactionId)
    {
        require(address(0) != _sender, "Sender address is empty");
        require(address(0) != _sourceAddress, "Source address is empty");

        transactionId = transactionsCount[_sender] = transactionsCount[_sender].add(1);

        transactions[_sender][transactionId] = Transaction({
            source: _sourceAddress
        });
    }

    function registerAccount(address _accountAddress) public
        returns (uint256 PAN)
    {
        return _registerAccount(msg.sender, _accountAddress);
    }

    function registerAccountByOwner(address[] _senders, address _accountAddress) public
        onlyOwner
        returns (uint256[] PANs)
    {
        PANs = new uint256[](_senders.length);

        for (uint256 i = 0; _senders.length > i; i = i.add(1))
            PANs[i] = _registerAccount(_senders[i], _accountAddress);
    }

    function _registerAccount(address _sender, address _accountAddress) private
        isUsable
        returns (uint256 PAN)
    {
        BankAccount account = BankAccount(_accountAddress);
        Bank bank = Bank(account.bankAddress());

        require(banksList.addressInUsed(address(bank)), "Bank instance is not valid");
        require(bank.registeredAccount(_accountAddress), "Account instance is not valid");

        PAN = account.registerAccount(_sender);

        if (address(0) != registeredPANs[PAN].holder) {
            // Other BankAccount is using the same BIN range
            require (_accountAddress == registeredPANs[PAN].account, "Account BIN range is conflicted");
        }

        ListLib.Uint256List storage list = holderPANsList[_sender];

        if (list.pushUint256(PAN)) {
            registeredPANsCount = registeredPANsCount.add(1);
            emit RegisteredAccount(_accountAddress, _sender, PAN);
        }

        registeredPANs[PAN] = AccountLink({
            account: _accountAddress,
            holder: _sender
        });
    }

    function unregisterAccount(address _accountAddress, address _beneficentAddress) public
        returns (uint256 PAN)
    {
        return _unregisterAccount(msg.sender, _accountAddress, _beneficentAddress);
    }

    function unregisterAccountByOwner(address[] _senders, address _accountAddress, address[] _beneficentAddresses) public
        onlyOwner
        returns (uint256[] PANs)
    {
        require(_senders.length == _beneficentAddresses.length, "Holder list is not consistent");
        PANs = new uint256[](_senders.length);

        for (uint256 i = 0; _senders.length > i; i = i.add(1))
            PANs[i] = _unregisterAccount(_senders[i], _accountAddress, _beneficentAddresses[i]);
    }

    function _unregisterAccount(address _sender, address _accountAddress, address _beneficentAddress) private
        isUsable
        returns (uint256 PAN)
    {
        BankAccount account = BankAccount(_accountAddress);
        Bank bank = Bank(account.bankAddress());

        require(banksList.addressInUsed(address(bank)), "Bank instance is not valid");
        require(bank.registeredAccount(_accountAddress), "Account instance is not valid");

        PAN = account.unregisterAccount(_sender, _beneficentAddress);

        if (0 != PAN) {
            ListLib.Uint256List storage list = holderPANsList[_sender];

            if (list.removeUint256(PAN)) {
                registeredPANsCount = registeredPANsCount.sub(1);
                emit UnregisteredAccount(_accountAddress, _sender, PAN, _beneficentAddress);
            }

            delete registeredPANs[PAN];
        }
    }

    function registeredBankAccount(address _accountAddress) public view
        returns (bool)
    {
        BankAccount account = BankAccount(_accountAddress);
        Bank bank = Bank(account.bankAddress());

        if (bank.registeredAccount(_accountAddress) && registeredBank(address(bank)))
            return true;

        return false;
    }

    function getPANs(address _holderAddress) public view
        returns (uint256[] items)
    {
        ListLib.Uint256List storage list = holderPANsList[_holderAddress];
        return list.uint256List();
    }

    function getPANsCount(address _holderAddress) public view
        returns (uint256)
    {
        ListLib.Uint256List storage list = holderPANsList[_holderAddress];
        return list.count;
    }

    function getNextPAN(address _holderAddress, uint256 _PAN) public view
        returns (uint256)
    {
        ListLib.Uint256List storage list = holderPANsList[_holderAddress];
        return list.nextUint256(_PAN);
    }

    function needSyncPANs() public view
        isUsable
        returns (bool)
    {
        ListLib.Uint256List storage list = holderPANsList[msg.sender];

        uint256 PAN = list.nextUint256(0);

        while (0 != PAN) {
            // Remove those PAN that bank is not in the list
            BankAccount account = BankAccount(registeredPANs[PAN].account);
            address bankAddress = account.bankAddress();

            if (!banksList.addressInUsed(bankAddress))
                return true;

            PAN = list.nextUint256(PAN);
        }

        return false;
    }

    function syncPANs() public
        isUsable
    {
        ListLib.Uint256List storage list = holderPANsList[msg.sender];

        uint256 rPAN;
        uint256 PAN = list.nextUint256(0);

        while (0 != PAN) {
            // Remove those PAN that bank is not in the list
            BankAccount account = BankAccount(registeredPANs[PAN].account);
            address bankAddress = account.bankAddress();

            if (!banksList.addressInUsed(bankAddress))
                rPAN = PAN;

            PAN = list.nextUint256(PAN);

            if (0 != rPAN) {
                list.removeUint256(rPAN);
                delete registeredPANs[rPAN];

                rPAN = 0;
                registeredPANsCount = registeredPANsCount.sub(1);
            }
        }
    }

    function registeredPANsBatch(uint256[] _PANs) public view
        returns (address[] accounts, address[] holders)
    {
        accounts = new address[](_PANs.length);
        holders = new address[](_PANs.length);

        for (uint256 i = 0; _PANs.length > i; i = i.add(1)) {
            accounts[i] = registeredPANs[_PANs[i]].account;
            holders[i] = registeredPANs[_PANs[i]].holder;
        }
    }

    function addBank(address _bankAddress) public
        onlyOwner
        returns(bool success)
    {
        Bank bank = Bank(_bankAddress);

        require(bank.sealed(), "Bank instance is not sealed");
        require(banksList.pushAddress(_bankAddress), "Duplicated bank instance");

        emit AddedBank(_bankAddress);
        return true;
    }

    function removeBank(address _bankAddress) public
        onlyOwner
        returns(bool success)
    {
        if (banksList.removeAddress(_bankAddress))
            emit RemovedBank(_bankAddress);
        return true;
    }

    function getBanks() public view
        returns (address[])
    {
        return banksList.addressList();
    }

    function getBanksCount() public view
        returns (uint256)
    {
        return banksList.count;
    }

    function getNextBank(address _bankAddress) public view
        returns (address)
    {
        return banksList.nextAddress(_bankAddress);
    }

    function registeredBank(address _bankAddress) public view
        returns (bool)
    {
        return banksList.addressInUsed(_bankAddress);
    }

    function getBankAccount(uint256 _PAN) public view
        returns (Bank holderBank, BankAccount holderAccount, address holderAddress)
    {
        AccountLink storage accountLink = registeredPANs[_PAN];
        require(address(0) != accountLink.account && address(0) != accountLink.holder, "Account PAN not valid");
        
        holderAccount = BankAccount(accountLink.account);
        holderBank = Bank(holderAccount.bankAddress());
        holderAddress = accountLink.holder;

        require(banksList.addressInUsed(address(holderBank)), "Bank is not registered");
        require(holderBank.registeredAccount(address(holderAccount)), "Bank account is not registered");
    }

    function emitAddedBankAccount(address _accountAddress) public {
        require(registeredBank(msg.sender), "Access denied");
        emit AddedBankAccount(msg.sender, _accountAddress);
    }

    function emitRemovedBankAccount(address _accountAddress) public {
        require(registeredBank(msg.sender), "Access denied");
        emit RemovedBankAccount(msg.sender, _accountAddress);
    }

    function emitAddedBankService(address _serviceAddress) public {
        require(registeredBank(msg.sender), "Access denied");
        emit AddedBankService(msg.sender, _serviceAddress);
    }

    function emitRemovedBankService(address _serviceAddress) public {
        require(registeredBank(msg.sender), "Access denied");
        emit RemovedBankService(msg.sender, _serviceAddress);
    }

    function sealRequirement() private view
    {
    }

}
