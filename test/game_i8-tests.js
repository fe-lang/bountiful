const { expect } = require("chai");
const { ethers } = require("hardhat");
const { deployGame, deployRegistry, mineBlocks } = require('./utils.js');

describe("Game i8", function () {
  it("Should go in winning state", async function () {

    [registry, eric, admin] = await deployRegistry()
    const game = await deployGame("contracts/src/main.fe:GameI8", registry.address, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 0, 15]);

    await registry.connect(admin).register_challenge(game.address);
    await registry.lock({value: ethers.utils.parseEther("1") });

    expect(await game.callStatic.is_solved()).to.equal(false);

    // Make winning move
    await game.move_field(15);

    expect(await game.callStatic.is_solved()).to.equal(true);
  });

  it("Should revert when trying to move_field without having the lock", async function () {

    [registry, eric, admin] = await deployRegistry()
    const game = await deployGame("contracts/src/main.fe:GameI8", registry.address, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 0, 15]);

    await registry.connect(admin).register_challenge(game.address);

    expect(await game.callStatic.is_solved()).to.equal(false);

    // Make winning move
    await expect(game.move_field(15)).to.be.reverted;
  });

});
