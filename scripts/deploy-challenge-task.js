const { task } = require('hardhat/config');
const {INIT_STATE_SOLVABLE, INIT_STATE_UNSOLVABLE} = require('./constants.js');
const { deployGame, getDeployerAndAdmin } = require('../test/utils.js');

// npx hardhat deploy-challenge <registry_adress> <challenge_name> --network goerli (--solvable)

task("deploy-challenge", "task to deploy and add a single challenge to an existing registry")
  .addPositionalParam("registry")
  .addPositionalParam("challengeName")
  .addFlag("solvable")
  .setAction(async (taskArgs, hre) => {
    await hre.run("compile");

    console.log(`Deploying on network ${hre.network.name}`);

    const init_state = taskArgs.solvable ? INIT_STATE_SOLVABLE : INIT_STATE_UNSOLVABLE;
    try {
      let [deployer, admin] = await getDeployerAndAdmin();
      await deploySingleChallenge(deployer, admin, init_state, taskArgs.registry, taskArgs.challengeName)
    } catch (err) {
      console.log(err);
    }
  });


async function deploySingleChallenge(deployer, admin, init_state, registry_address, challenge_name) {

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  console.log("Setting admin address to:", admin.address);
  console.log("Account balance:", (await admin.getBalance()).toString());

  const BountyRegistryFactory = await ethers.getContractFactory("BountyRegistry");
  const registry = BountyRegistryFactory.attach(registry_address);
  console.log("Assuming registry deployed to:", registry.address);

  console.log(`Deploying: ${challenge_name}`);
  const deployedChallenge = await deployGame(`contracts/src/main.fe:${challenge_name}`, registry.address, init_state);
  console.log(`${challenge_name} deployed to: ${deployedChallenge.address}`);

  let registerTx = await registry.connect(admin).register_challenge(deployedChallenge.address);
  await registerTx.wait();
  console.log(`Game registered via tx ${registerTx.hash}`);
}