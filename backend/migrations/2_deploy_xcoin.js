var fs = require('fs');

var XCoin = artifacts.require("./XCoin.sol");

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
  const deploymentFile = __dirname + "/xcoin.json";

  let deployment = {};

  return new Promise((resolve, reject) => {
    let run = async () => {
      if (fs.existsSync(deploymentFile)) {
        let deployment = require(deploymentFile);

        console.log("");
        console.log("SKIPPED, Exchange Coin Contract:", deployment.contract.address);
        console.log("         Exchange Coin:", deployment.conf.typeCode + ":", deployment.conf.label, "-", deployment.conf.description);
        console.log("         Gas used:", deployment.contract.gasUsed, "(" + deployment.contract.transactionHash + ")");
        console.log("");

        return resolve();
      }

      console.log();
      console.log("## DEPLOYING EXCHANGE COIN ##");

      let soCurrencyCodes = [];
      let toCurrencyCodes = [];
      let rates = [];
  
      for (let exchangeRate of conf.exchangeRates) {
        soCurrencyCodes.push(exchangeRate.soCurrencyCode);
        toCurrencyCodes.push(exchangeRate.toCurrencyCode);
        rates.push(web3.toBigNumber(exchangeRate.rate));
  
        console.log(" + Exchange rate:", exchangeRate.soCurrencyCode, "-", exchangeRate.toCurrencyCode, ":", exchangeRate.rate);
      }
  
      return deployer.deploy(XCoin, conf.xCoin.typeCode, conf.xCoin.label, conf.xCoin.description, conf.xCoin.symbol,
        conf.xCoin.initialSupply, conf.xCoin.decimals, conf.xCoin.currencyCode, soCurrencyCodes, toCurrencyCodes, rates).then(async () => {
          let gasUsed = (await web3.eth.getTransactionReceipt(XCoin.transactionHash)).gasUsed;

          console.log("");
          console.log("CREATED, Exchange Coin Contract:", XCoin.address);
          console.log("         Exchange Coin:", conf.xCoin.typeCode + ",", conf.xCoin.label, ":", conf.xCoin.description);
          console.log("         Gas used:", gasUsed, "(" + XCoin.transactionHash + ")");
          console.log("");

          deployment.contract = {
            address: XCoin.address,
            gasUsed: gasUsed.toString(),
            transactionHash: XCoin.transactionHash
          }

          deployment.conf = conf.xCoin;
          deployment.conf.exchangeRates = conf.exchangeRates;

          fs.writeFileSync(deploymentFile, JSON.stringify(deployment));

          return resolve();
        }).catch(error => {
          reject(error);
        });
    }

    return run();
  });
}
