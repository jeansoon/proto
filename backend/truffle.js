module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!
  networks: {
    development: {
      host: "10.10.10.70",
      port: 8545,
      network_id: "1205", // Match any network id
      gas: 8999999, // 4542786,
      from: "0xe06d0cdf8859fd84026f3f20b34da836e294dc70"
    },
    remote: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "1205", // Match any network id
      gas: 8999999, // 4542786,
      from: "0xe06d0cdf8859fd84026f3f20b34da836e294dc70"
    },
    local: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*", // Match any network id
      gas: 8999999 // 4542786,
    },
    rinkeby: {
      host: "10.10.10.70",
      port: 7545,
      network_id: "*", // Match any network id
      from: "0xe06d0cdf8859fd84026f3f20b34da836e294dc70"
    },
    rinkebyRemote: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*", // Match any network id
      from: "0xe06d0cdf8859fd84026f3f20b34da836e294dc70"
    },
    mainnet: {
      host: "oc-uat.oojibo.com",
      port: 23207,
      network_id: "*", // Match any network id
      from: "0xe06d0cdf8859fd84026f3f20b34da836e294dc70"
    }
  }
};
