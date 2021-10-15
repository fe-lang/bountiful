async function mineBlocks(blockNumber) {
  while (blockNumber > 0) {
    blockNumber--;
    await hre.network.provider.request({
      method: "evm_mine",
      params: [],
    });
  }
}

async function deployGame(bounty_registry, state) {
  const Game = await ethers.getContractFactory("Game");
  const game = await Game.deploy(bounty_registry, state);
  await game.deployed();
  return game
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