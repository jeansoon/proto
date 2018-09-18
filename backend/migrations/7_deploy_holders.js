var fs = require('fs');

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

  return new Promise((resolve, reject) => {
    let run = async () => {
      console.log("");
      console.log("## DEPLOYING BANK SERVICE ##");

      const deploymentBanks = require(__dirname + "/banks.json");
      let banks = Banks.at(deploymentBanks.contract.address);

      let holders = {};

      for (const [index, confBank] of conf.banks.entries()) {
        for (const [index, confAccount] of confBank.accounts.entries()) {
          if (0 < confAccount.autoRegisters.length) {
            for (let holder of confAccount.autoRegisters) {
              if (!holders[holder])
                holders[holder] = {};
            }
          }
        }
      }

      let indexHolder = 0;

      console.log("");

      for (holder in holders)
        console.log(">> HOLDER PANS:", ++indexHolder, holder, "(" + (await banks.getPANs(holder)).join(", ") + ")");

      if (0 >= indexHolder)
        console.log(">> NO HOLDER REGISTERED");

      console.log("");

      return resolve();
    }

    return run();
  });
}
