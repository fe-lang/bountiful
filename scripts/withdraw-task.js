const { task } = require('hardhat/config');
const { getDeployerAndAdmin } = require('../test/utils.js');

// npx hardhat withdraw --network goerli

task("withdraw", "task to withdraw the prize money")
  .addPositionalParam("registry")
  .setAction(async (taskArgs, hre) => {
    console.log(`Withdrawing on network ${hre.network.name} on registry contract ${taskArgs.registry}`);

    try {
      let [deployer, admin] = await getDeployerAndAdmin();
      await withdraw(admin, taskArgs.registry)
    } catch (err) {
      console.log(err);
    }
});

  async function withdraw(admin, address) {
    const BountyRegistryFactory = await ethers.getContractFactory("BountyRegistry");
    const registry = BountyRegistryFactory.attach(address);
    let tx = await registry.connect(admin).withdraw();
    console.log(`Withdrawing via tx ${tx.hash}`);
  }
