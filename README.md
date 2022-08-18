# bountiful

This is work in progress code for an upcoming bug bounty challenge for Fe. It uses an early version of the Fe support for [hardhat](https://hardhat.org/) provided by the [`hardhat-fe`](https://www.npmjs.com/package/@developerdao/hardhat-fe) plugin. It also requires Fe version `0.17.0` to be build.

## Find bugs, get ETH

Bountiful is a registry for contracts that should uphold certain conditions. If the contract can be brought into a state where such condition no longer holds it means that either a bug in the Fe language or in the contract was found and exploited. In that case, the exploiter can claim prize money in ETH without having to obtain any further permission.

## Current challenges:

- Different implementations of the [15 puzzle game](https://15puzzle.netlify.app/) which start from an unsolvable game state


## Mainnet deployment

1. `npx hardhat deploy --network mainnet`
2. After the deployment went through, send the prize money to the registry contract manually.

## Claiming process

COMING SOON

## How to run

1. Run `git clone https://github.com/cburgdorf/bountiful.git`
2. Run `npx hardhat test`