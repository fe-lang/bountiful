const { expect } = require("chai");
const { ethers } = require("hardhat");

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
