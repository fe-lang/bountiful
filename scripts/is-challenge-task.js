const { task } = require('hardhat/config');

// npx hardhat withdraw --network goerli

task("is-challenge", "task to check if an address is a registered challenge")
  .addPositionalParam("registry")
  .addPositionalParam("challenge")
  .setAction(async (taskArgs, hre) => {
    console.log(`Checking on network ${hre.network.name} on registry contract ${taskArgs.registry}`);
    await is_challenge(taskArgs.registry, taskArgs.challenge)
  });

  async function is_challenge(registry_address, challenge_address) {
    const BountyRegistryFactory = await ethers.getContractFactory("BountyRegistry");
    const registry = BountyRegistryFactory.attach(registry_address);
    
    if (await registry.is_open_challenge(challenge_address)) {
      console.log(`YES! ${challenge_address} is a registered challenge on registry ${registry_address}`);
    } else {
      console.log(`NO! ${challenge_address} is a NOT registered challenge on registry ${registry_address}`);
    }
  }
