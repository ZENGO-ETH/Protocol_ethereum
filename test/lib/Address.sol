// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

library Mainnet {
    // Tokens
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant DFX = 0x888888435FDe8e7d4c54cAb67f206e4199454c60;
    
    address public constant CADC = 0xcaDC0acd4B445166f12d2C07EAc6E2544FbE2Eef;
    address public constant EUROC = 0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c;
    address public constant XSGD = 0x70e8dE73cE538DA2bEEd35d14187F6959a8ecA96;

    // Oracles
    // 8-decimals
    address public constant CHAINLINK_WETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant CHAINLINK_USDC_USD = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;

    address public constant CHAINLINK_CADC_USD = 0xa34317DB73e77d453b1B8d04550c44D10e981C8e;
    address public constant CHAINLINK_EUR_USD = 0xb49f677943BC038e9857d61E7d053CaA2C1734C1;
    address public constant CHAINLINK_SGD_USD = 0xe25277fF4bbF9081C75Ab0EB13B4A13a721f3E13;
    
}