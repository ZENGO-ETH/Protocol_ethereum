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

// Arbitrum DEPLOYMENT
contract GYENCADCScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy CurveFactoryV2
        CurveFactoryV2 deployedCurveFactory = CurveFactoryV2(Arbitrum.CURVE_FACTORY);

        IOracle usdOracle = IOracle(Arbitrum.CHAINLINK_USDC_USD);
        IOracle yenOracle = IOracle(Arbitrum.CHAINLINK_YEN_USD);
        IOracle cadOracle = IOracle(Arbitrum.CHAINLINK_CAD_USD);

        CurveInfo memory gyenCurveInfo = CurveInfo(
            "dfx-gyen-usdc-v2",
            "dfx-gyen-v2",
            Arbitrum.GYEN,
            Arbitrum.USDC,
            CurveParams.BASE_WEIGHT,
            CurveParams.QUOTE_WEIGHT,
            yenOracle,
            usdOracle,
            CurveParams.ALPHA,
            CurveParams.BETA,
            CurveParams.MAX,
            Arbitrum.GYEN_EPSILON,
            CurveParams.LAMBDA
        );

        CurveInfo memory cadcCurveInfo = CurveInfo(
            "dfx-cadc-usdc-v2",
            "dfx-cadc-v2",
            Arbitrum.CADC,
            Arbitrum.USDC,
            CurveParams.BASE_WEIGHT,
            CurveParams.QUOTE_WEIGHT,
            cadOracle,
            usdOracle,
            CurveParams.ALPHA,
            CurveParams.BETA,
            CurveParams.MAX,
            Arbitrum.CADC_EPSILON,
            CurveParams.LAMBDA
        );

        // Deploy all new Curves
        deployedCurveFactory.newCurve(gyenCurveInfo);
        deployedCurveFactory.newCurve(cadcCurveInfo);

        vm.stopBroadcast();
    }
}
