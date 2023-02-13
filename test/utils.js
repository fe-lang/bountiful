
async function mineBlocks(blockNumber) {
  while (blockNumber > 0) {
    blockNumber--;
    await hre.network.provider.request({
      method: "evm_mine",
      params: [],
    });
  }
}

async function deployGame(identifier, bounty_registry, state) {
  const Game = await ethers.getContractFactory(identifier);
  const game = await Game.deploy(bounty_registry, state);
  await game.deployed();
  return game
}

async function deployDefaultGame(bounty_registry, state) {
  return await deployGame("contracts/src/main.fe:Game", bounty_registry, state)
}

async function deployRegistry() {
  const BountyRegistry = await ethers.getContractFactory("BountyRegistry");
  [eric, admin] = await ethers.getSigners();
  const registry = await BountyRegistry.deploy(admin.address);
  await registry.deployed();
  return [registry, eric, admin]
}

async function deployContract(identifier) {
  const BoardIterator = await ethers.getContractFactory(identifier);
  const target = await BoardIterator.deploy();
  await target.deployed();
  return target
}

async function getDeployerAndAdmin() {
  if (hre.network.name === "goerli") {
    if (process.env.GOERLI_DEPLOYER_ADDRESS === undefined || process.env.GOERLI_ADMIN_ADDRESS === undefined) {
      console.log(`Check ENV Vars`);
      console.error(`ENV Vars GOERLI_DEPLOYER_ADDRESS: ${process.env.GOERLI_DEPLOYER_ADDRESS}`);
      console.error(`ENV Vars GOERLI_ADMIN_ADDRESS: ${process.env.GOERLI_ADMIN_ADDRESS}`);
      throw new Error("Missing ENV vars")
    }

    const deployer = await hre.ethers.getSigner(process.env.GOERLI_DEPLOYER);
    const admin = await hre.ethers.getSigner(process.env.GOERLI_ADMIN);
    return [deployer, admin]
  } else if (hre.network.name === "mainnet") {

    if (process.env.MAINNET_DEPLOYER_ADDRESS === undefined || process.env.MAINNET_ADMIN_ADDRESS === undefined) {
      console.log(`Check ENV Vars`);
      console.error(`ENV Vars MAINNET_DEPLOYER_ADDRESS: ${process.env.MAINNET_DEPLOYER_ADDRESS}`);
      console.error(`ENV Vars MAINNET_ADMIN_ADDRESS: ${process.env.MAINNET_ADMIN_ADDRESS}`);
      throw new Error("Missing ENV vars")
    }

    const deployer = await hre.ethers.getSigner(process.env.MAINNET_DEPLOYER);
    const admin = await hre.ethers.getSigner(process.env.MAINNET_ADMIN);
    return [deployer, admin]
  } else {
    const deployer = await hre.ethers.getSigner();
    const admin = await hre.ethers.getSigner();
    return [deployer, admin]
  }
}

exports.mineBlocks = mineBlocks
exports.deployGame = deployGame
exports.deployRegistry = deployRegistry
exports.deployDefaultGame = deployDefaultGame
exports.deployContract = deployContract
exports.getDeployerAndAdmin = getDeployerAndAdmin