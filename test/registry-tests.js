const { expect } = require("chai");
const { ethers } = require("hardhat");
const { deployDefaultGame, deployRegistry, mineBlocks } = require('./utils.js');

const ONE_ETH = ethers.utils.parseEther("1.0");


describe("BountyRegistry", function () {

  it("Should initially be unlocked", async function () {
    [registry, eric, admin] = await deployRegistry()

    expect(await registry.callStatic.is_locked()).to.be.false;
  });

  it("Should revert when trying to lock without minimum deposit", async function () {
    [registry, eric, admin] = await deployRegistry()

    expect(await registry.callStatic.is_locked()).to.be.false;

    await expect(registry.lock()).to.be.reverted;
  });

  it("Should lock", async function () {
    [registry, eric, admin] = await deployRegistry()

    expect(await registry.callStatic.is_locked()).to.be.false;

    await registry.lock({value: ONE_ETH });

    expect(await registry.callStatic.is_locked()).to.be.true;
  });

  it("Should release lock after timeout", async function () {
    [registry, eric, admin] = await deployRegistry()

    await registry.lock({value: ONE_ETH });

    expect(await registry.callStatic.is_locked()).to.be.true;

    await mineBlocks(1001);

    expect(await registry.callStatic.is_locked()).to.be.false;
  });

  it("Should revert if non-admin tries to register challenge", async function () {
    [registry, eric, admin] = await deployRegistry()

    let challenge = ethers.utils.getAddress("0x8ba1f109551bd432803012645ac136ddd64dba72")

    expect(await registry.callStatic.is_open_challenge(challenge)).to.be.false;

    await expect(registry.register_challenge(challenge)).to.be.reverted;
  });

  it("Should revert if non-admin tries to remove challenge", async function () {
    [registry, eric, admin] = await deployRegistry()

    let challenge = ethers.utils.getAddress("0x8ba1f109551bd432803012645ac136ddd64dba72")

    await registry.connect(admin).register_challenge(challenge);

    expect(await registry.callStatic.is_open_challenge(challenge)).to.be.true;

    await expect(registry.remove_challenge(challenge)).to.be.reverted;
  });

  it("Should register challenge as an admin", async function () {
    [registry, eric, admin] = await deployRegistry()

    let challenge = ethers.utils.getAddress("0x8ba1f109551bd432803012645ac136ddd64dba72")

    expect(await registry.callStatic.is_open_challenge(challenge)).to.be.false;

    await registry.connect(admin).register_challenge(challenge);

    expect(await registry.callStatic.is_open_challenge(challenge)).to.be.true;
  });

  it("Should revert if admin tries to remove challenge while it is locked", async function () {
    [registry, eric, admin] = await deployRegistry()

    let challenge = ethers.utils.getAddress("0x8ba1f109551bd432803012645ac136ddd64dba72")

    await registry.connect(admin).register_challenge(challenge);

    expect(await registry.callStatic.is_open_challenge(challenge)).to.be.true;

    await registry.lock({value: ONE_ETH });

    await expect(registry.connect(admin).remove_challenge(challenge)).to.be.reverted;
  });

  it("Should allow admin to remove challenge when it isn't locked", async function () {
    [registry, eric, admin] = await deployRegistry()

    let challenge = ethers.utils.getAddress("0x8ba1f109551bd432803012645ac136ddd64dba72")

    await registry.connect(admin).register_challenge(challenge);

    expect(await registry.callStatic.is_open_challenge(challenge)).to.be.true;

    await registry.connect(admin).remove_challenge(challenge);

    expect(await registry.callStatic.is_open_challenge(challenge)).to.be.false;
  });

  it("Should solve challenge and claim bounty", async function () {

    // Deploy Bounty registry
    [registry, eric, admin] = await deployRegistry()

    // Deploy challenge
    const game = await deployDefaultGame(registry.address, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 0, 15]);

    //Let's give the registry some prize money
    await admin.sendTransaction({
      to: registry.address,
      value: ethers.utils.parseEther("10")
    })

    await registry.connect(admin).register_challenge(game.address);
    expect(await registry.callStatic.is_open_challenge(game.address)).to.be.true;

    let eric_initial_balance = await registry.provider.getBalance(eric.address);
    expect(await registry.provider.getBalance(registry.address)).to.equal(ethers.utils.parseEther("10"));
    await registry.lock({value: ONE_ETH });
    let eric_new_balance = await registry.provider.getBalance(eric.address);

    // It doesn't match exactly. Probably because of what is lost to tx fees
    expect(eric_new_balance.lte(eric_initial_balance.sub(ONE_ETH))).to.be.true;
    expect(await registry.provider.getBalance(registry.address)).to.equal(ethers.utils.parseEther("11"));
    expect(await game.callStatic.is_solved()).to.be.false;

    // Make winning move
    await game.move_field(15);
    expect(await game.callStatic.is_solved()).to.be.true;
    // Claim bounty
    await registry.claim(game.address);

    expect(await registry.provider.getBalance(registry.address)).to.equal(0);
    let eric_latest_balance = await registry.provider.getBalance(eric.address);

    // It doesn't match exactly. Probably because of what is lost to tx fees
    expect(eric_latest_balance.gte(eric_initial_balance.add(ethers.utils.parseEther("9.9")))).to.be.true;
  });

  it("Should revert if random person tries to claim bounty", async function () {

    // Deploy Bounty registry
    [registry, eric, admin] = await deployRegistry()

    // Deploy challenge
    const game = await deployDefaultGame(registry.address, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 0, 15]);

    await registry.connect(admin).register_challenge(game.address);
    expect(await registry.callStatic.is_open_challenge(game.address)).to.be.true;
    await registry.lock({value: ONE_ETH });
    expect(await game.callStatic.is_solved()).to.be.false;

    // Make winning move
    await game.move_field(15);
    expect(await game.callStatic.is_solved()).to.be.true;
    // Admin can't claim as he doesn't have the lock
    await expect(registry.connect(admin).claim(game.address)).to.be.reverted;
  });

  it("Should revert when trying to claim without lock", async function () {

    // Deploy Bounty registry
    [registry, eric, admin] = await deployRegistry()

    // Deploy challenge in an already solved state only so that we can demonstrate
    // that even then a lock would still be needed.
    const game = await deployDefaultGame(registry.address, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 0]);

    await registry.connect(admin).register_challenge(game.address);
    expect(await registry.callStatic.is_open_challenge(game.address)).to.be.true;

    expect(await game.callStatic.is_solved()).to.be.true;
    // Claim bounty
    await expect(registry.claim(game.address)).to.be.reverted;

  });

  it("Should revert when trying to claim an unregistered challenge", async function () {

    // Deploy Bounty registry
    [registry, eric, admin] = await deployRegistry()

    // Deploy challenge
    const game = await deployDefaultGame(registry.address, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 0, 15]);

    await registry.lock({value: ONE_ETH });
    expect(await game.callStatic.is_solved()).to.be.false;

    // Make winning move
    await game.move_field(15);
    expect(await game.callStatic.is_solved()).to.be.true;
    // Claim bounty
    await expect(registry.claim(game.address)).to.be.reverted;

  });

  it("Should revert when trying to claim an unsolved challenge", async function () {

    // Deploy Bounty registry
    [registry, eric, admin] = await deployRegistry()

    // Deploy challenge
    const game = await deployDefaultGame(registry.address, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 0, 15]);

    await registry.connect(admin).register_challenge(game.address);
    expect(await registry.callStatic.is_open_challenge(game.address)).to.be.true;
    await registry.lock({value: ONE_ETH });
    expect(await game.callStatic.is_solved()).to.be.false;
    // Claim bounty
    await expect(registry.claim(game.address)).to.be.reverted;

  });

  it("Should allow admin to withdraw funds when not locked", async function () {
    [registry, eric, admin] = await deployRegistry()

    let ten_eth = ethers.utils.parseEther("10");
    let zero_eth = ethers.utils.parseEther("0")
    //Let's give the registry some prize money
    await admin.sendTransaction({
      to: registry.address,
      value: ten_eth
    })

    let admin_balance = await registry.provider.getBalance(admin.address);
    expect(await registry.provider.getBalance(registry.address)).to.equal(ten_eth);

    await registry.connect(admin).withdraw();

    expect(await registry.provider.getBalance(registry.address)).to.equal(zero_eth);
    let new_admin_balance = await registry.provider.getBalance(admin.address);
    expect(new_admin_balance.gte(admin_balance.add(ethers.utils.parseEther("9.9")))).to.be.true;
  });

  it("Should revert if admin tries to withdraw when platform is locked", async function () {
    // Deploy Bounty registry
    [registry, eric, admin] = await deployRegistry()

    // Deploy challenge
    const game = await deployDefaultGame(registry.address, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 0, 15]);

    await registry.connect(admin).register_challenge(game.address);
    expect(await registry.callStatic.is_open_challenge(game.address)).to.be.true;
    await registry.lock({value: ONE_ETH });

    await expect(registry.connect(admin).withdraw()).to.be.reverted;
  });

  it("Should revert if non-admin tries to withdraw funds", async function () {
    [registry, eric, admin] = await deployRegistry()

    await expect(registry.connect(eric).withdraw()).to.be.reverted;
  });

});
