const { task } = require('hardhat/config');
const { deployAll } = require('./deploy.js');
const {INIT_STATE_SOLVABLE, PRIZE_MONEY_IN_ETH, INIT_STATE_UNSOLVABLE} = require('./constants.js');

// npx hardhat deploy --network goerli (--solvable and --funded)


task("deploy", "task to deploy the bountiful suite")
  .addFlag("solvable")
  .addFlag("funded")
  .setAction(async (taskArgs, hre) => {

    await hre.run("compile");

    console.log(`Deploying on network ${hre.network.name}`);
    
    const init_state = taskArgs.solvable ? INIT_STATE_SOLVABLE : INIT_STATE_UNSOLVABLE;
    const prize_money = taskArgs.funded ? PRIZE_MONEY_IN_ETH : 0

    if (hre.network.name === "goerli") {
      if (process.env.GOERLI_DEPLOYER_ADDRESS === undefined || process.env.GOERLI_ADMIN_ADDRESS === undefined) {
        console.log(`Check ENV Vars`);
        console.error(`ENV Vars GOERLI_DEPLOYER_ADDRESS: ${process.env.GOERLI_DEPLOYER_ADDRESS}`);
        console.error(`ENV Vars GOERLI_ADMIN_ADDRESS: ${process.env.GOERLI_ADMIN_ADDRESS}`);
        return
      }
  
      const deployer = await hre.ethers.getSigner(process.env.GOERLI_DEPLOYER);
      const admin = await hre.ethers.getSigner(process.env.GOERLI_ADMIN);
      await deployAll(deployer, admin, init_state, prize_money)
    } else if (hre.network.name === "mainnet") {

      if (process.env.MAINNET_DEPLOYER_ADDRESS === undefined || process.env.MAINNET_ADMIN_ADDRESS === undefined) {
        console.log(`Check ENV Vars`);
        console.error(`ENV Vars MAINNET_DEPLOYER_ADDRESS: ${process.env.MAINNET_DEPLOYER_ADDRESS}`);
        console.error(`ENV Vars MAINNET_ADMIN_ADDRESS: ${process.env.MAINNET_ADMIN_ADDRESS}`);
        return
      }

      const deployer = await hre.ethers.getSigner(process.env.MAINNET_DEPLOYER);
      const admin = await hre.ethers.getSigner(process.env.MAINNET_ADMIN);
      await deployAll(deployer, admin, init_state, prize_money)
    } else {
      const deployer = await hre.ethers.getSigner();
      const admin = await hre.ethers.getSigner();
      await deployAll(deployer, admin, init_state, prize_money)
    }

  });
