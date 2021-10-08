# An implementation of the 15 puzzle game in Fe

This is work in progress code for an upcoming bug bounty challenge for Fe. It uses an early version of the upcoming Fe support for [hardhat](https://hardhat.org/) as well as a [custom build of the Fe compiler](https://github.com/cburgdorf/fe/tree/christoph/puzzle-build)

# How to run

1. Create a custom Fe binary using [this branch](https://github.com/cburgdorf/fe/tree/christoph/puzzle-build)

2. Change the path in `fe_path_name` to the path to the local binary

3. Run `npx hardhat test`

4. Profit 🎉
