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

exports.mineBlocks = mineBlocks
exports.deployGame = deployGame
exports.deployRegistry = deployRegistry
exports.deployDefaultGame = deployDefaultGame