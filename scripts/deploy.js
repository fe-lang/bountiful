
const { deployGame } = require('../test/utils.js');
const { LIST_OF_CHALLENGES } = require('./constants.js');

async function deployAll(deployer, admin, init_state, prize_money_in_eth) {

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  console.log("Setting admin address to:", admin.address);
  console.log("Account balance:", (await admin.getBalance()).toString());

  // We get the contract to deploy
  const BountyRegistry = await hre.ethers.getContractFactory("BountyRegistry");
  console.log("Got BountyRegistry")
  const registry = await BountyRegistry.deploy(deployer.address);
  console.log(`Deploying BountyRegistry via tx ${registry.deployTransaction.hash}`)

  await registry.deployed();
  console.log("Registry deployed to:", registry.address);

  for (game of LIST_OF_CHALLENGES) {
    console.log(`Deploying: ${game}`);
    const deployedGame = await deployGame(`contracts/src/main.fe:${game}`, registry.address, init_state);
    console.log(`${game} deployed to: ${deployedGame.address}`);
    let registerTx = await registry.connect(admin).register_challenge(deployedGame.address);
    await registerTx.wait();
    console.log(`Game registered via tx ${registerTx.hash}`);
  }

  //Let's give the registry some prize money
  if (prize_money_in_eth > 0) {
    const tx = await admin.sendTransaction({
      to: registry.address,
      value: ethers.utils.parseEther(`${prize_money_in_eth}`)
    });
    console.log(`Funded registry via tx ${tx}`);
  } else {
    console.log(`Prize money is set to zero. Make sure to fund manually.`);
  }
}

exports.deployAll = deployAll
