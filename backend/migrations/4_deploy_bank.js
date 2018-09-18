var fs = require('fs');

var Bank = artifacts.require("./Bank.sol");
var Banks = artifacts.require("./Banks.sol");

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
    const deploymentBanks = require(__dirname + "/banks.json");
    let banks = Banks.at(deploymentBanks.contract.address);

    let run = async () => {
      for (const [index, confBank] of conf.banks.entries()) {
        let deploymentFile = __dirname + "/bank-" + confBank.typeCode + ".json";

        if (fs.existsSync(deploymentFile)) {
          deployment = require(deploymentFile);

          console.log("");
          console.log("SKIPPED, Bank Contract:", deployment.contract.address);
          console.log("         Bank:", deployment.conf.typeCode + ":", deployment.conf.label, "-", deployment.conf.description);
          console.log("         Gas used:", deployment.contract.gasUsed, "(" + deployment.contract.transactionHash + ")");
          console.log("         Using Banks Contract:", deploymentBanks.contract.address);
          console.log("         Banks:", deploymentBanks.conf.typeCode + ":", deploymentBanks.conf.label, "-", deploymentBanks.conf.description);
          console.log("");

          // Check wheather the bank is registered or not
          if (!(await banks.registeredBank(deployment.contract.address))) {
            // register bank
            await banks.addBank(deployment.contract.address);
          }
        }
        else {
          console.log();
          console.log("## DEPLOYING BANK ##");

          await deployer.deploy(Bank, deploymentBanks.contract.address, confBank.typeCode, confBank.label, confBank.description, confBank.countryCode);

          deployment.contract = {
            address: Bank.address,
            gasUsed: (await web3.eth.getTransactionReceipt(Bank.transactionHash)).gasUsed.toString(),
            transactionHash: Bank.transactionHash
          }

          deployment.conf = confBank;

          fs.writeFileSync(deploymentFile, JSON.stringify(deployment));

          console.log("");
          console.log("CREATED, Bank Contract:", deployment.contract.address);
          console.log("         Bank:", deployment.conf.typeCode + ":", deployment.conf.label, "-", deployment.conf.description);
          console.log("         Gas used:", deployment.contract.gasUsed, "(" + deployment.contract.transactionHash + ")");
          console.log("         Using Banks Contract:", deploymentBanks.contract.address);
          console.log("         Banks:", deploymentBanks.conf.typeCode + ":", deploymentBanks.conf.label, "-", deploymentBanks.conf.description);
          console.log("");

          // register bank
          await banks.addBank(deployment.contract.address);
        }
      }

      return resolve();
    }

    return run();
  });
}
