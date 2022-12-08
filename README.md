# bountiful

This is work in progress code for an upcoming bug bounty challenge for Fe. It uses an early version of the Fe support for [hardhat](https://hardhat.org/) provided by the [`hardhat-fe`](https://www.npmjs.com/package/@developerdao/hardhat-fe) plugin. It also requires Fe version `0.17.0` to be build.

## Find bugs, get ETH

Bountiful is a registry for contracts that should uphold certain conditions. If the contract can be brought into a state where such condition no longer holds it means that either a bug in the Fe language or in the contract was found and exploited. In that case, the exploiter can claim prize money in ETH without having to obtain any further permission.

## Current challenges:

- Different implementations of the [15 puzzle game](https://15puzzle.netlify.app/) which start from an unsolvable game state


## Mainnet deployment

1. `npx hardhat deploy --network mainnet`
2. After the deployment went through, send the prize money to the registry contract manually.

## How to run the tests

1. Run `git clone https://github.com/cburgdorf/bountiful.git`
2. Run `npx hardhat test`

## Administrative money withdrawal

Unless the system is in `locked` state, the admin can withdraw the prize money at any time. This would be used to migrate
to a newer version of the system.

Run: `npx hardhat withdraw <address-of-registry>--network mainnet`


## Claiming process

[Ethereum is a dark forest](https://www.paradigm.xyz/2020/08/ethereum-is-a-dark-forest) which is why we need a front running prevention mechanism. In short, if it is possible to send a transaction that will make the sender richer (in our case by exploiting a Fe bug and claiming ETH prize money) we can be sure that somewhere there's a bot noticing it who will perform the same transaction faster leaving the honest claimer empty handed.

To avoid this we've come up with a very simple front-running prevention mechanism. Here is how it works:

1. As a bounty hunter we first try to find an exploit by attacking the contracts locally on our own development machine

2. Let's suppose we have found a way to bring the code challenge into its `solved` state on our own local machine

3. To replicate our success on the actual bug bounty registry and claim the prize we first have to aquire an exclusive lock via `registry.lock()`

4. Now that we have acquired an exclusive lock we have a window of `1000` blocks (roughly 3 hours) to bring *any* of the challenges into the *solved* state. Cautious as we are we will wait a few more blocks before we present the solution.

5. Now it's time to solve one of the challenges, which means we exploit the contract in the same way that we have successfully done before on our local development machine. It is important to point out that no other party can interfere with any of the code challenges because we have obtained an exclusive lock.

6. Next we call `registry.claim(address_of_challenge)` to claim the prize money.

7. Profit! 💸

