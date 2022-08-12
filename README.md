# DFX Protocol V2
A decentralized foreign exchange protocol optimized for stablecoins.

[![Discord](https://img.shields.io/discord/786747729376051211.svg?color=768AD4&label=discord&logo=https%3A%2F%2Fdiscordapp.com%2Fassets%2F8c9701b98ad4372b58f13fd9f65f966e.svg)](http://discord.dfx.finance/)
[![Twitter Follow](https://img.shields.io/twitter/follow/DFXFinance.svg?label=DFXFinance&style=social)](https://twitter.com/DFXFinance)

## Testing

1. Download all dependencies. 
```
forge install
```
2. Run local node hardfork.
```
anvil -f <YOUR_RPC_URL> --fork-block-number 15129966
```
3. Run tests.
```
forge test -vvv -f http://127.0.0.1:8545
```