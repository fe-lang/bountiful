const { task } = require('hardhat/config');

// npx hardhat remove-challenge <registry_address> <challenge_address> --network goerli

task("remove-challenge", "task to remove a challenge")
  .addPositionalParam("registry")
  .addPositionalParam("challenge")
  .setAction(async (taskArgs, hre) => {

    await hre.run("compile");

    console.log(`Removing challenge ${taskArgs.challenge} on network ${hre.network.name} on registry contract ${taskArgs.registry}`);
    
    if (hre.network.name === "goerli") {
      if (process.env.GOERLI_DEPLOYER_ADDRESS === undefined || process.env.GOERLI_ADMIN_ADDRESS === undefined) {
        console.log(`Check ENV Vars`);
        console.error(`ENV Vars GOERLI_DEPLOYER_ADDRESS: ${process.env.GOERLI_DEPLOYER_ADDRESS}`);
        console.error(`ENV Vars GOERLI_ADMIN_ADDRESS: ${process.env.GOERLI_ADMIN_ADDRESS}`);
        return
      }

      const admin = await hre.ethers.getSigner(process.env.GOERLI_ADMIN);
      await remove(admin, taskArgs.registry, taskArgs.challenge)
    } else if (hre.network.name === "mainnet") {

      if (process.env.MAINNET_DEPLOYER_ADDRESS === undefined || process.env.MAINNET_ADMIN_ADDRESS === undefined) {
        console.log(`Check ENV Vars`);
        console.error(`ENV Vars MAINNET_DEPLOYER_ADDRESS: ${process.env.MAINNET_DEPLOYER_ADDRESS}`);
        console.error(`ENV Vars MAINNET_ADMIN_ADDRESS: ${process.env.MAINNET_ADMIN_ADDRESS}`);
        return
      }

      const admin = await hre.ethers.getSigner(process.env.MAINNET_ADMIN);
      await remove(admin, taskArgs.registry, taskArgs.challenge)
    } else {
      const admin = await hre.ethers.getSigner();
      await remove(admin, taskArgs.registry, taskArgs.challenge)
    }
  });

  async function remove(admin, registry_address, challenge) {
    const BountyRegistryFactory = await ethers.getContractFactory("BountyRegistry");
    const registry = BountyRegistryFactory.attach(registry_address);
    let tx = await registry.connect(admin).remove_challenge(challenge);
    console.log(`Removing challenge via tx ${tx.hash}`);
  }
