# DFX Protocol V2

A decentralized foreign exchange protocol optimized for stablecoins.

[![Discord](https://img.shields.io/discord/786747729376051211.svg?color=768AD4&label=discord&logo=https%3A%2F%2Fdiscordapp.com%2Fassets%2F8c9701b98ad4372b58f13fd9f65f966e.svg)](http://discord.dfx.finance/)
[![Twitter Follow](https://img.shields.io/twitter/follow/DFXFinance.svg?label=DFXFinance&style=social)](https://twitter.com/DFXFinance)

## Overview

DFX v2 is an update from DFX protocol v0.5 with some additional features including the protocol fee, which is set by the percentage of the platform fee(which incurs for each swap on all the pools across the platform), fixing issues of invariant check. The major change from the previous version is, V2 is more generalized for users, meaning anybody can create their curves(pools) while V0.5 only allowed the DFX team to create pools.

There are two major parts to the protocol: **Assimilators** and **Curves**. Assimilators allow the AMM to handle pairs of different value while also retrieving reported oracle prices for respective currencies. Curves allow the custom parameterization of the bonding curve with dynamic fees, halting bounderies, etc.

### Assimilators

Assimilators are a key part of the protocol, it converts all amounts to a "numeraire" which is essentially a base value used for computations across the entire protocol. This is necessary as we are dealing with pairs of different values. **AssimilatorFactory** is responsible for deploying new AssimilatorV2.

Oracle price feeds are also piped in through the assimilator as they inform what numeraire amounts should be set. Since oracle price feeds report their values in USD, all assimilators attempt to convert token values to a numeraire amount based on USD.

### Curve Parameter Terminology

High level overview.

| Name      | Description                                                                                               |
| --------- | --------------------------------------------------------------------------------------------------------- |
| Weights   | Weighting of the pair (only 50/50)                                                                        |
| Alpha     | The maximum and minimum allocation for each reserve                                                       |
| Beta      | Liquidity depth of the exchange; The higher the value, the flatter the curve at the reported oracle price |
| Delta/Max | Slippage when exchange is not at the reported oracle price                                                |
| Epsilon   | Fixed fee                                                                                                 |
| Lambda    | Dynamic fee captured when slippage occurs                                                                 |

In order to prevent anti-slippage being greater than slippate, DFX V2 requires deployers to set Lambda to 1(1e18).

For a more in-depth discussion, refer to [section 3 of the shellprotocol whitepaper](https://github.com/cowri/shell-solidity-v1/blob/master/Shell_White_Paper_v1.0.pdf)

### Major changes from the Shell Protocol

The main changes between V2 and the original code can be found in the following files:

- All the assimilators
- `AssimilatorV2.sol`
- `CurveFactoryV2.sol`
- `CurveMath.sol`
- `ProportionalLiquidity.sol`
- `Swaps.sol`
- `Structs.sol`

#### Different Valued Pairs

In the original implementation, all pools are assumed to be baskets of like-valued tokens. In our implementation, all pools are assumed to be pairs of different-valued FX stablecoins (of which one side is always USDC).

This is achieved by having custom assimilators that normalize the foreign currencies to their USD counterparts. We're sourcing our FX price feed from chainlink oracles. See above for more information about assimilators.

Withdrawing and depositing related operations will respect the existing LP ratio. As long as the pool ratio hasn't changed since the deposit, amount in ~= amount out (minus fees), even if the reported price on the oracle changes. The oracle is only here to assist with efficient swaps.

## Third Party Libraries

- [Openzeppelin contracts (v3.3.0)](https://github.com/OpenZeppelin/openzeppelin-contracts/releases/tag/v3.3.0)
- [ABDKMath (v2.4)](https://github.com/abdk-consulting/abdk-libraries-solidity/releases/tag/v2.4)
- [Shell Protocol@48dac1c](https://github.com/cowri/shell-solidity-v1/tree/48dac1c1a18e2da292b0468577b9e6cbdb3786a4)


## Test Locally

1. Install Foundy

   - [Foundry Docs](https://jamesbachini.com/foundry-tutorial/)

2. Download all dependencies. 
    ```
    forge install
    ```
2. Run Ethereum mainnet forked testnet on your local in one terminal:

   ```
   anvil -f https://mainnet.infura.io/v3/<INFURA KEY> --fork-block-number 15129966
   ```

3. In another terminal, run V2 test script:

   ```
   forge test --match-contract V2Test -vvv -f http://127.0.0.1:8545
   ```

4. Run Protocol Fee test:

    ```
    forge test --match-contract ProtocolFeeTest -vvv -f http://127.0.0.1:8545
    ```

## Test Cases

1. testDeployTokenAndSwap

    - deploy a random erc20 token (we call it `gold` token) and it's price oralce (`gold oracle`), gold : usdc ratio is set to 1:20 in the test
    - deploy a new curve from Curve Factory
    - try swaps back and forth between `gold` and `usdc`
    - in each swap, usdc and gold swap in and out amount are correct based on the gold oracle's price

2. testForeignStableCoinSwap
    
    - test uses the EURC and CADC tokens deployed on the ethereum mainnet
    - this test is to ensure deploying curves by curveFactoryV2 doesn't break any stable swap features from the previous version

3. testTotalSupply

    - this test has nothing to do with V2 update
    - in the test, we directly transfer erc20 tokens to the curve without calling deposit function
    - the test ensures total supply of curve lpt remains unchanged when tokens are transferred directly to the curve
4. testSwapDifference

    - this test is to ensure there is no anti-slippage occurred
    - We frist swap relatively large amount of token(saying from token A to token B) to change the pool ratio
    - we swap back all output amount of B to A
    - this test ensures the user gets all of his original A amount except the fee
5. testInvariant

    - this test ensures anybody can deposit any amount of LPs to the curve
6. testProtocolFeeUsdcCadcSwap

    - For each trade on DFX, platform fee is applied, it is set by Epsilon when deploying the curve
    - platform fee is splitted into 2 parts, some of the fee is sent back to the pool, while rest amount is sent to the protocol's treasury address (we call this `protocol fee`)
    - `protocol fee` is calculated by the following formular
    ```
    protocol fee = platform fee * CurveFactoryV2.protocolFee / 100000
    ```
    if protocolFee is set to 50000, then the platform fee is divided evenly to the treasury & curve
