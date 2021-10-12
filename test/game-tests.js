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

async function deployGame(state) {
  const Game = await ethers.getContractFactory("Game");
  const game = await Game.deploy([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 0, 15]);
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

    const game = await deployGame([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 0, 15]);

    expect(await game.callStatic.is_solved()).to.equal(false);

    // Make winning move
    await game.move_field(15);

    expect(await game.callStatic.is_solved()).to.equal(true);
  });
});

describe("BountyRegistry", function () {
  it("Should initially be unlocked", async function () {
    [registry, eric, admin] = await deployRegistry()

    expect(await registry.callStatic.is_locked()).to.equal(false);
  });

  it("Should claim lock", async function () {
    [registry, eric, admin] = await deployRegistry()

    expect(await registry.callStatic.is_locked()).to.equal(false);

    await registry.lock();

    expect(await registry.callStatic.is_locked()).to.equal(true);
  });

  it("Should release lock after timeout", async function () {
    [registry, eric, admin] = await deployRegistry()

    await registry.lock();

    expect(await registry.callStatic.is_locked()).to.equal(true);

    await mineBlocks(1001);

    expect(await registry.callStatic.is_locked()).to.equal(false);
  });

  it("Should revert if non-admin tries to register challenge", async function () {
    [registry, eric, admin] = await deployRegistry()

    let challenge = ethers.utils.getAddress("0x8ba1f109551bd432803012645ac136ddd64dba72")

    expect(await registry.callStatic.is_open_challenge(challenge)).to.equal(false);

    await expect(registry.register_challenge(challenge)).to.be.reverted;
  });

  it("Should revert if non-admin tries to remove challenge", async function () {
    [registry, eric, admin] = await deployRegistry()

    let challenge = ethers.utils.getAddress("0x8ba1f109551bd432803012645ac136ddd64dba72")

    await registry.connect(admin).register_challenge(challenge);

    expect(await registry.callStatic.is_open_challenge(challenge)).to.equal(true);

    await expect(registry.remove_challenge(challenge)).to.be.reverted;
  });

  it("Should register challenge as an admin", async function () {
    [registry, eric, admin] = await deployRegistry()

    let challenge = ethers.utils.getAddress("0x8ba1f109551bd432803012645ac136ddd64dba72")

    expect(await registry.callStatic.is_open_challenge(challenge)).to.equal(false);

    await registry.connect(admin).register_challenge(challenge);

    expect(await registry.callStatic.is_open_challenge(challenge)).to.equal(true);
  });

  it("Should revert if admin tries to remove challenge while it is locked", async function () {
    [registry, eric, admin] = await deployRegistry()

    let challenge = ethers.utils.getAddress("0x8ba1f109551bd432803012645ac136ddd64dba72")

    await registry.connect(admin).register_challenge(challenge);

    expect(await registry.callStatic.is_open_challenge(challenge)).to.equal(true);

    await registry.lock();

    await expect(registry.connect(admin).remove_challenge(challenge)).to.be.reverted;
  });

  it("Should allow admin to remove challenge when it isn't locked", async function () {
    [registry, eric, admin] = await deployRegistry()

    let challenge = ethers.utils.getAddress("0x8ba1f109551bd432803012645ac136ddd64dba72")

    await registry.connect(admin).register_challenge(challenge);

    expect(await registry.callStatic.is_open_challenge(challenge)).to.equal(true);

    await registry.connect(admin).remove_challenge(challenge);

    expect(await registry.callStatic.is_open_challenge(challenge)).to.equal(false);
  });

  it("Should solve challenge and claim bounty", async function () {

    // Deploy challenge
    const game = await deployGame([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 0, 15]);

    // Deploy Bounty registry
    [registry, eric, admin] = await deployRegistry()

    await registry.connect(admin).register_challenge(game.address);
    expect(await registry.callStatic.is_open_challenge(game.address)).to.equal(true);
    await registry.lock();
    expect(await game.callStatic.is_solved()).to.equal(false);

    // Make winning move
    await game.move_field(15);
    expect(await game.callStatic.is_solved()).to.equal(true);
    // Claim bounty
    await registry.claim(game.address);

  });

  it("Should revert if random person tries to claim bounty", async function () {

    // Deploy challenge
    const game = await deployGame([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 0, 15]);

    // Deploy Bounty registry
    [registry, eric, admin] = await deployRegistry()

    await registry.connect(admin).register_challenge(game.address);
    expect(await registry.callStatic.is_open_challenge(game.address)).to.equal(true);
    await registry.lock();
    expect(await game.callStatic.is_solved()).to.equal(false);

    // Make winning move
    await game.move_field(15);
    expect(await game.callStatic.is_solved()).to.equal(true);
    // Admin can't claim as he doesn't have the lock
    await expect(registry.connect(admin).claim(game.address)).to.be.reverted;
  });

  it("Should revert when trying to claim without lock", async function () {

    // Deploy challenge
    const game = await deployGame([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 0, 15]);

    // Deploy Bounty registry
    [registry, eric, admin] = await deployRegistry()

    await registry.connect(admin).register_challenge(game.address);
    expect(await registry.callStatic.is_open_challenge(game.address)).to.equal(true);
    expect(await game.callStatic.is_solved()).to.equal(false);

    // Make winning move
    await game.move_field(15);
    expect(await game.callStatic.is_solved()).to.equal(true);
    // Claim bounty
    await expect(registry.claim(game.address)).to.be.reverted;

  });

  it("Should revert when trying to claim an unregistered challenge", async function () {

    // Deploy challenge
    const game = await deployGame([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 0, 15]);

    // Deploy Bounty registry
    [registry, eric, admin] = await deployRegistry()

    await registry.lock();
    expect(await game.callStatic.is_solved()).to.equal(false);

    // Make winning move
    await game.move_field(15);
    expect(await game.callStatic.is_solved()).to.equal(true);
    // Claim bounty
    await expect(registry.claim(game.address)).to.be.reverted;

  });

  it("Should revert when trying to claim an unsolved challenge", async function () {

    // Deploy challenge
    const game = await deployGame([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 0, 15]);

    // Deploy Bounty registry
    [registry, eric, admin] = await deployRegistry()

    await registry.connect(admin).register_challenge(game.address);
    expect(await registry.callStatic.is_open_challenge(game.address)).to.equal(true);
    await registry.lock();
    expect(await game.callStatic.is_solved()).to.equal(false);
    // Claim bounty
    await expect(registry.claim(game.address)).to.be.reverted;

  });

});
