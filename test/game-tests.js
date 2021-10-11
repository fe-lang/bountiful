const { expect } = require("chai");
const { ethers } = require("hardhat");

async function mineBlocks(blockNumber) {
  while (blockNumber > 0) {
    blockNumber--;
    await hre.network.provider.request({
      method: "evm_mine",
      params: [],
    });
  }
}

describe("Game", function () {
  it("Should go in winning state", async function () {
    const Game = await ethers.getContractFactory("Game");
    const game = await Game.deploy([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 0, 15]);
    await game.deployed();

    expect(await game.callStatic.is_winning_state()).to.equal(false);

    // Make winning move
    await game.move_field(15);

    expect(await game.callStatic.is_winning_state()).to.equal(true);
  });
});

describe("BountyRegistry", function () {
  it("Should initially be unlocked", async function () {
    const BountyRegistry = await ethers.getContractFactory("BountyRegistry");
    const registry = await BountyRegistry.deploy();
    await registry.deployed();

    expect(await registry.callStatic.is_locked()).to.equal(false);
  });

  it("Should claim lock", async function () {
    const BountyRegistry = await ethers.getContractFactory("BountyRegistry");
    const registry = await BountyRegistry.deploy();
    await registry.deployed();

    expect(await registry.callStatic.is_locked()).to.equal(false);

    await registry.lock();

    expect(await registry.callStatic.is_locked()).to.equal(true);
  });

  it("Should release lock after timeout", async function () {
    const BountyRegistry = await ethers.getContractFactory("BountyRegistry");
    const registry = await BountyRegistry.deploy();
    await registry.deployed();

    await registry.lock();

    expect(await registry.callStatic.is_locked()).to.equal(true);

    await mineBlocks(1001);

    expect(await registry.callStatic.is_locked()).to.equal(false);
  });
});
