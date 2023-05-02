// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "./CurveParams.sol";

// Libraries
import "../src/Curve.sol";
import "../src/Config.sol";
import "../src/Zap.sol";
import "../src/Router.sol";

// Factories
import "../src/CurveFactoryV2.sol";

import "./Addresses.sol";
import '../src/interfaces/IERC20Detailed.sol';

// ARBITRUM DEPLOYMENT
contract ContractScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Router deployedRouter = new Router(0x9544995B5312B26acDf09e66E699c34310b7c856);
        Zap deployedZap = new Zap();

        // Deploy Assimilator
        // AssimilatorFactory deployedAssimFactory = new AssimilatorFactory();

        // int128 protocolFee = 50_000;
        
        // Config config = new Config(protocolFee, Arbitrum.MULTISIG);

        
        // Deploy CurveFactoryV2
        // CurveFactoryV2 deployedCurveFactory = new CurveFactoryV2(
        //     address(deployedAssimFactory),
        //     address(config)
        // );

        // Attach CurveFactoryV2 to Assimilator
        // deployedAssimFactory.setCurveFactory(address(deployedCurveFactory));

        // IOracle usdOracle = IOracle(Arbitrum.CHAINLINK_USDC_USD);
        // IOracle eurOracle = IOracle(Arbitrum.CHAINLINK_EUR_USD);

        // CurveInfo memory eurocCurveInfo = CurveInfo(
        //     "dfx-euroc-usdc-v2",
        //     "dfx-euroc-v2",
        //     Arbitrum.EUROC,
        //     Arbitrum.USDC,
        //     CurveParams.BASE_WEIGHT,
        //     CurveParams.QUOTE_WEIGHT,
        //     eurOracle,
        //     usdOracle,
        //     CurveParams.ALPHA,
        //     CurveParams.BETA,
        //     CurveParams.MAX,
        //     Arbitrum.EUROC_EPSILON,
        //     CurveParams.LAMBDA
        // );

        // Deploy all new Curves
        // deployedCurveFactory.newCurve(eurocCurveInfo);

        vm.stopBroadcast();
    }
}