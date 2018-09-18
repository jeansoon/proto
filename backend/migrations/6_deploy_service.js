var fs = require('fs');

var Bank = artifacts.require("./Bank.sol");
var BSTransfer = artifacts.require("./BSTransfer.sol");
var BSPayroll = artifacts.require("./BSPayroll.sol");
var BSRetail = artifacts.require("./BSRetail.sol");
var BSTravelInsurance = artifacts.require("./BSTravelInsurance.sol");

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
      console.log();
      console.log("## DEPLOYING BANK SERVICE ##");

      for (const [index, confBank] of conf.banks.entries()) {
        const deploymentBank = require(__dirname + "/bank-" + confBank.typeCode + ".json");
        let bank = Bank.at(deploymentBank.contract.address);

        for (let typeCode in confBank.services) {
          let confService = confBank.services[typeCode];
          let deploymentFile = __dirname + "/bank-service-" + confBank.typeCode + "-" + typeCode + ".json";

          if (fs.existsSync(deploymentFile)) {
            deployment = require(deploymentFile);

            // Check wheather the bank service is registered or not
            if ((await bank.registeredService(deployment.contract.address))) {
              console.log("");
              console.log("SKIPPED, BankService Contract:", deployment.contract.address);
              console.log("         BankService:", deployment.conf.typeCode + ":", deployment.conf.label, "-", deployment.conf.description);
              console.log("         Gas used:", deployment.contract.gasUsed, "(" + deployment.contract.transactionHash + ")");
              console.log("         Using Bank Contract:", deploymentBank.contract.address);
              console.log("         Bank:", deploymentBank.conf.typeCode + ":", deploymentBank.conf.label, "-", deploymentBank.conf.description);
              console.log("");

              continue;
            }
          }
          else {
            let service;

            switch (typeCode) {
              case "TRANSFER": service = BSTransfer; break;
              case "PAYROLL": service = BSPayroll; break;
              case "RETAIL": service = BSRetail; break;
              case "TRAVEL_INSURANCE": service = BSTravelInsurance; break;
            }

            if (!service) {
              console.log("");
              console.log("### UNKNOWN BANK SERVICE:", typeCode);
              console.log("");
            }
            else {
              await deployer.deploy(service, deploymentBank.contract.address, confService.label, confService.description);
                  
              deployment.contract = {
                address: service.address,
                gasUsed: (await web3.eth.getTransactionReceipt(service.transactionHash)).gasUsed.toString(),
                transactionHash: service.transactionHash
              }
      
              deployment.conf = confService;
              deployment.conf.typeCode = typeCode; 
      
              fs.writeFileSync(deploymentFile, JSON.stringify(deployment));
    
              console.log("");
              console.log("CREATED, BankService Contract:", deployment.contract.address);
              console.log("         BankService:", deployment.conf.typeCode + ":", deployment.conf.label, "-", deployment.conf.description);
              console.log("         Gas used:", deployment.contract.gasUsed, "(" + deployment.contract.transactionHash + ")");
              console.log("         Using Bank Contract:", deploymentBank.contract.address);
              console.log("         Bank:", deploymentBank.conf.typeCode + ":", deploymentBank.conf.label, "-", deploymentBank.conf.description);
              console.log("");
            }
          }

          // Register bank service
          await bank.addService(deployment.contract.address);
        }
      }

      return resolve();
    }

    return run();
  });
}
