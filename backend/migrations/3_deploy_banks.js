var fs = require('fs');

var ListLib = artifacts.require("./ListLib.sol");
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
  const deploymentFile = __dirname + "/banks.json";

  let deployment = {};

  return new Promise((resolve, reject) => {
    let run = async () => {
      const deploymentXCoin = require(__dirname + "/xcoin.json");

      if (fs.existsSync(deploymentFile)) {
        deployment = require(deploymentFile);

        console.log("");
        console.log("SKIPPED, Banks Contract:", deployment.contract.address);
        console.log("         Banks:", deployment.conf.typeCode + ":", deployment.conf.label, "-", deployment.conf.description);
        console.log("         Gas used:", deployment.contract.gasUsed, "(" + deployment.contract.transactionHash + ")");
        console.log("         Using Exchange Coin Contract:", deploymentXCoin.contract.address);
        console.log("         Exchange Coin:", deploymentXCoin.conf.typeCode + ":", deploymentXCoin.conf.label, "-", deploymentXCoin.conf.description);
        console.log("");

        return resolve();
      }

      await deployer.deploy(ListLib);
      deployer.link(ListLib, Banks);

      return deployer.deploy(Banks, deploymentXCoin.contract.address, conf.typeCode, conf.label, conf.description).then(async () => {
        deployment.contract = {
          address: Banks.address,
          gasUsed: (await web3.eth.getTransactionReceipt(Banks.transactionHash)).gasUsed.toString(),
          transactionHash: Banks.transactionHash
        }

        deployment.conf = {
          typeCode: conf.typeCode,
          label: conf.label,
          description: conf.description
        }

        fs.writeFileSync(deploymentFile, JSON.stringify(deployment));

        console.log("");
        console.log("CREATED, Banks Contract:", deployment.contract.address);
        console.log("         Banks:", deployment.conf.typeCode + ":", deployment.conf.label, "-", deployment.conf.description);
        console.log("         Gas used:", deployment.contract.gasUsed, "(" + deployment.contract.transactionHash + ")");
        console.log("         Using Exchange Coin Contract:", deploymentXCoin.contract.address);
        console.log("         Exchange Coin:", deploymentXCoin.conf.typeCode + ":", deploymentXCoin.conf.label, "-", deploymentXCoin.conf.description);
        console.log("");

        return resolve();
      }).catch(error => {
        reject(error);
      });
    }

    return run();
  });
}
