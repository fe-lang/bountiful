const { expect } = require("chai");
const { ethers } = require("hardhat");

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


describe("Game", function () {
  it("Should go in winning state", async function () {

    [registry, eric, admin] = await deployRegistry()
    const game = await deployGame(registry.address, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 0, 15]);

    await registry.connect(admin).register_challenge(game.address);
    await registry.lock({value: ethers.utils.parseEther("1") });

    expect(await game.callStatic.is_solved()).to.equal(false);

    // Make winning move
    await game.move_field(15);

    expect(await game.callStatic.is_solved()).to.equal(true);
  });

  it("Should revert when trying to move_field without having the lock", async function () {

    [registry, eric, admin] = await deployRegistry()
    const game = await deployGame(registry.address, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 0, 15]);

    await registry.connect(admin).register_challenge(game.address);

    expect(await game.callStatic.is_solved()).to.equal(false);

    // Make winning move
    await expect(game.move_field(15)).to.be.reverted;
  });

});
