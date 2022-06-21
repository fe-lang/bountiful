const { expect } = require("chai");
const { ethers } = require("hardhat");
const { deployContract } = require('./utils.js');


describe("BoardIterator", function () {
  it("Should not revert (assertions are native in Fe)", async function () {
    await deployContract("contracts/src/main.fe:BoardIteratorTest");
  });
});
