const { task } = require('hardhat/config');

// npx hardhat withdraw --network goerli

task("is-challenge", "task to check if an address is a registered challenge")
  .addPositionalParam("registry")
  .addPositionalParam("challenge")
  .setAction(async (taskArgs, hre) => {
    console.log(`Checking on network ${hre.network.name} on registry contract ${taskArgs.registry}`);
    
    if (hre.network.name === "goerli") {
      if (process.env.GOERLI_DEPLOYER_ADDRESS === undefined || process.env.GOERLI_ADMIN_ADDRESS === undefined) {
        console.log(`Check ENV Vars`);
        console.error(`ENV Vars GOERLI_DEPLOYER_ADDRESS: ${process.env.GOERLI_DEPLOYER_ADDRESS}`);
        console.error(`ENV Vars GOERLI_ADMIN_ADDRESS: ${process.env.GOERLI_ADMIN_ADDRESS}`);
        return
      }

      await is_challenge(taskArgs.registry, taskArgs.challenge)
    } else if (hre.network.name === "mainnet") {

      if (process.env.MAINNET_DEPLOYER_ADDRESS === undefined || process.env.MAINNET_ADMIN_ADDRESS === undefined) {
        console.log(`Check ENV Vars`);
        console.error(`ENV Vars MAINNET_DEPLOYER_ADDRESS: ${process.env.MAINNET_DEPLOYER_ADDRESS}`);
        console.error(`ENV Vars MAINNET_ADMIN_ADDRESS: ${process.env.MAINNET_ADMIN_ADDRESS}`);
        return
      }

      await is_challenge(taskArgs.registry, taskArgs.challenge)
    } else {
      await is_challenge(taskArgs.registry, taskArgs.challenge)
    }
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
