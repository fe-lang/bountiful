const { task } = require('hardhat/config');
const { getDeployerAndAdmin } = require('../test/utils.js');

// npx hardhat remove-challenge <registry_address> <challenge_address> --network goerli

task("remove-challenge", "task to remove a challenge")
  .addPositionalParam("registry")
  .addPositionalParam("challenge")
  .setAction(async (taskArgs, hre) => {

    await hre.run("compile");

    console.log(`Removing challenge ${taskArgs.challenge} on network ${hre.network.name} on registry contract ${taskArgs.registry}`);
    
    try {
      let [deployer, admin] = await getDeployerAndAdmin();
      await remove(admin, taskArgs.registry, taskArgs.challenge)
    } catch (err) {
      console.log(err);
    }
  });

  async function remove(admin, registry_address, challenge) {
    const BountyRegistryFactory = await ethers.getContractFactory("BountyRegistry");
    const registry = BountyRegistryFactory.attach(registry_address);
    let tx = await registry.connect(admin).remove_challenge(challenge);
    console.log(`Removing challenge via tx ${tx.hash}`);
  }
