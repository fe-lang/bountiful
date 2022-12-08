require("@nomiclabs/hardhat-waffle");
require("@developerdao/hardhat-fe");

require("./scripts/deploy-task");
require("./scripts/withdraw-task");
require("./scripts/ischallenge-task");



// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.4",
  fe: {
    version: "0.20.0-alpha",
  },
  networks: {
    goerli: {
      url: `${process.env.GOERLI_JSON_RPC}`,
      accounts: [`${process.env.GOERLI_DEPLOYER_PK}`]
    },
    mainnet: {
      url: `${process.env.MAINNET_JSON_RPC}`,
      accounts: [`${process.env.MAINNET_DEPLOYER_PK}`]
    }
  }
};
