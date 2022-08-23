const { task } = require('hardhat/config');

// npx hardhat withdraw --network goerli

task("withdraw", "task to deploy the bountiful suite")
  .addPositionalParam("registry")
  .setAction(async (taskArgs, hre) => {
    console.log(`Withdrawing on network ${hre.network.name} on registry contract ${taskArgs.registry}`);
    
    if (hre.network.name === "goerli") {
      if (process.env.GOERLI_DEPLOYER_ADDRESS === undefined || process.env.GOERLI_ADMIN_ADDRESS === undefined) {
        console.log(`Check ENV Vars`);
        console.error(`ENV Vars GOERLI_DEPLOYER_ADDRESS: ${process.env.GOERLI_DEPLOYER_ADDRESS}`);
        console.error(`ENV Vars GOERLI_ADMIN_ADDRESS: ${process.env.GOERLI_ADMIN_ADDRESS}`);
        return
      }

      const admin = await hre.ethers.getSigner(process.env.GOERLI_ADMIN);
      await withdraw(admin, taskArgs.registry)
    } else if (hre.network.name === "mainnet") {

      if (process.env.MAINNET_DEPLOYER_ADDRESS === undefined || process.env.MAINNET_ADMIN_ADDRESS === undefined) {
        console.log(`Check ENV Vars`);
        console.error(`ENV Vars MAINNET_DEPLOYER_ADDRESS: ${process.env.MAINNET_DEPLOYER_ADDRESS}`);
        console.error(`ENV Vars MAINNET_ADMIN_ADDRESS: ${process.env.MAINNET_ADMIN_ADDRESS}`);
        return
      }

      const admin = await hre.ethers.getSigner(process.env.MAINNET_ADMIN);
      await withdraw(admin, taskArgs.registry)
    } else {
      const admin = await hre.ethers.getSigner();
      await withdraw(admin, taskArgs.registry)
    }
  });

  async function withdraw(admin, address) {
    const BountyRegistryFactory = await ethers.getContractFactory("BountyRegistry");
    const registry = BountyRegistryFactory.attach(address);
    let tx = await registry.connect(admin).withdraw();
    console.log(`Withdrawing via tx ${tx.hash}`);
  }
