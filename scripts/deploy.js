// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function deployAll(deployer, admin) {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  console.log("Setting admin address to:", admin.address);
  console.log("Account balance:", (await admin.getBalance()).toString());

  // We get the contract to deploy
  const BountyRegistry = await hre.ethers.getContractFactory("BountyRegistry");
  const registry = await BountyRegistry.deploy(deployer.address);

  await registry.deployed();

  console.log("Registry deployed to:", registry.address);
}

exports.deployAll = deployAll
