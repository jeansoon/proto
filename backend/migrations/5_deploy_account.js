var fs = require('fs');

var Bank = artifacts.require("./Bank.sol");
var Banks = artifacts.require("./Banks.sol");
var BankAccount = artifacts.require("./BankAccount.sol");

module.exports = (deployer, netowrk) => {
  return deployer.then(() => {
    return run(deployer, netowrk).then(() => {
    }).catch(error => {
      console.log("ERROR:", error);
    });
  });
};

function run(deployer, netowrk) {
  const conf = require(__dirname + "/../config.json");

  let deployment = {};

  return new Promise((resolve, reject) => {
    let run = async () => {
      try {
        console.log();
        console.log("## DEPLOYING BANK ACCOUNT ##");

        for (const [index, confBank] of conf.banks.entries()) {
          const deploymentBank = require(__dirname + "/bank-" + confBank.typeCode + ".json");
          let bank = Bank.at(deploymentBank.contract.address);

          for (const [index, confAccount] of confBank.accounts.entries()) {
            let deploymentFile = __dirname + "/bank-account-" + confBank.typeCode + "-" + confAccount.typeCode + ".json";

            if (fs.existsSync(deploymentFile)) {
              deployment = require(deploymentFile);

              console.log("");
              console.log("SKIPPED, BankAccount Contract:", deployment.contract.address);
              console.log("         BankAccount:", deployment.conf.typeCode + ":", deployment.conf.label, "-", deployment.conf.description);
              console.log("         Gas used:", deployment.contract.gasUsed, "(" + deployment.contract.transactionHash + ")");
              console.log("         Using Bank Contract:", deploymentBank.contract.address);
              console.log("         Bank:", deploymentBank.conf.typeCode + ":", deploymentBank.conf.label, "-", deploymentBank.conf.description);
              console.log("");

              // Check wheather the bank service is registered or not
              if (!(await bank.registeredAccount(deployment.contract.address))) {
                // Register bank account
                await bank.addAccount(deployment.contract.address);
              }
            }
            else {
              let soCurrencyCodes = [];
              let toCurrencyCodes = [];
              let rates = [];

              for (let exchangeRate of conf.exchangeRates) {
                soCurrencyCodes.push(exchangeRate.soCurrencyCode);
                toCurrencyCodes.push(exchangeRate.toCurrencyCode);
                rates.push(web3.toBigNumber(exchangeRate.rate));
              }

              await deployer.deploy(BankAccount, deploymentBank.contract.address, confAccount.typeCode, confAccount.label, confAccount.description,
                confAccount.symbol, confAccount.initialSupply, confAccount.decimals, confAccount.currencyCode, confAccount.BIN,
                soCurrencyCodes, toCurrencyCodes, rates);

              deployment.contract = {
                address: BankAccount.address,
                gasUsed: (await web3.eth.getTransactionReceipt(BankAccount.transactionHash)).gasUsed.toString(),
                transactionHash: BankAccount.transactionHash
              }

              deployment.conf = confAccount;
              deployment.exchangeRates = conf.exchangeRates;

              fs.writeFileSync(deploymentFile, JSON.stringify(deployment));

              console.log("");
              console.log("CREATED, BankAccount Contract:", deployment.contract.address);
              console.log("         BankAccount:", deployment.conf.typeCode + ":", deployment.conf.label, "-", deployment.conf.description);
              console.log("         Gas used:", deployment.contract.gasUsed, "(" + deployment.contract.transactionHash + ")");
              console.log("         Using Bank Contract:", deploymentBank.contract.address);
              console.log("         Bank:", deploymentBank.conf.typeCode + ":", deploymentBank.conf.label, "-", deploymentBank.conf.description);
              console.log("");

              // Register bank account
              await bank.addAccount(deployment.contract.address);
            }

            // Auto register account
            if (0 < confAccount.autoRegisters.length) {
              for (let holder of confAccount.autoRegisters)
                console.log(" + Registering:", holder);

              const deploymentBanks = require(__dirname + "/banks.json");
              let banks = Banks.at(deploymentBanks.contract.address);

              await banks.registerAccountByOwner(confAccount.autoRegisters, deployment.contract.address);
            }
          }
        }

        return resolve();
      }
      catch (error) {
        console.log(error);
      }
    }

    return run();
  });
}
