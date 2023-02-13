const { task } = require('hardhat/config');
const { deployAll } = require('./deploy.js');
const { getDeployerAndAdmin } = require('../test/utils.js');
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

    try {
      let [deployer, admin] = await getDeployerAndAdmin();
      await deployAll(deployer, admin, init_state, prize_money)
    } catch (err) {
      console.log(err);
      return
    }

  });
