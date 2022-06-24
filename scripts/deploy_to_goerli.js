// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { deployAll } = require('./deploy.js');

async function main() {

  if (process.env.GOERLI_DEPLOYER_ADDRESS === undefined || process.env.GOERLI_ADMIN_ADDRESS) {
    console.error(`ENV Vars missing GOERLI_DEPLOYER_ADDRESS: ${process.env.GOERLI_DEPLOYER_ADDRESS}`)
    console.error(`ENV Vars missing GOERLI_ADMIN_ADDRESS: ${process.env.GOERLI_ADMIN_ADDRESS}`)
    return
  }

  const deployer = await hre.ethers.getSigner(process.env.GOERLI_DEPLOYER);
  const admin = await hre.ethers.getSigner(process.env.GOERLI_ADMIN);

  await deployAll(deployer, admin)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
