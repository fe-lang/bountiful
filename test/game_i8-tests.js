const { expect } = require("chai");
const { ethers } = require("hardhat");
const { deployGame, deployRegistry, mineBlocks } = require('./utils.js');
const { INIT_STATE_SOLVABLE, INIT_STATE_UNSOLVABLE } = require('../scripts/constants.js');

describe("Game i8", function () {
  it("Should go in winning state", async function () {

    [registry, eric, admin] = await deployRegistry()
    const game = await deployGame("contracts/src/main.fe:GameI8", registry.address, INIT_STATE_SOLVABLE);

    await registry.connect(admin).register_challenge(game.address);
    await registry.lock({value: ethers.utils.parseEther("1") });

    expect(await game.is_solved()).to.equal(false);

    // Make winning move
    await game.move_field(15);

    expect(await game.is_solved()).to.equal(true);
  });

  it("The hack", async function () {

    [registry, eric, admin] = await deployRegistry()
    const game = await deployGame("contracts/src/main.fe:GameI8", registry.address, INIT_STATE_UNSOLVABLE);

    await registry.connect(admin).register_challenge(game.address);
    await registry.lock({value: ethers.utils.parseEther("1") });

    expect(await game.is_solved()).to.equal(false);

    // These where the moves that allowed the first bounty to be claimed
    // On-Chain Moves: https://etherscan.io/address/0x8e3c037b9f76de7e1b094c6b7beea6e80dcb3f64/advanced#internaltx
    // Fixed in: 715df01940dcad6ac5c157809a33f4b52ff06a94
    await game.move_field(11);
    await game.move_field(10);
    await game.move_field(14);
    await game.move_field(13);
    await game.move_field(12);
    await game.move_field(8);
    await game.move_field(4);
    await game.move_field(0);
    await game.move_field(1);
    await game.move_field(5);
    await game.move_field(9);
    await game.move_field(10);
    await game.move_field(11);
    await game.move_field(7);
    await game.move_field(6);
    await game.move_field(1)
    await game.move_field(0);
    await game.move_field(4);
    await game.move_field(8);
    await game.move_field(12);
    await game.move_field(13);
    await game.move_field(9);
    await game.move_field(5);
    await game.move_field(6);
    await game.move_field(7);
    await game.move_field(11);
    await game.move_field(15);
    expect(await game.is_solved()).to.equal(true);
  });


  it("Should revert when trying to move_field without having the lock", async function () {

    [registry, eric, admin] = await deployRegistry()
    const game = await deployGame("contracts/src/main.fe:GameI8", registry.address, INIT_STATE_SOLVABLE);

    await registry.connect(admin).register_challenge(game.address);

    expect(await game.is_solved()).to.equal(false);

    // Make winning move
    await expect(game.move_field(15)).to.be.reverted;
  });

});
