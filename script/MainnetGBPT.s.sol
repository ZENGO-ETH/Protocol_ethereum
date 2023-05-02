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

// Mainnet DEPLOYMENT
contract GBPTScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy CurveFactoryV2
        CurveFactoryV2 deployedCurveFactory = CurveFactoryV2(Mainnet.CURVE_FACTORY);

        IOracle usdOracle = IOracle(Mainnet.CHAINLINK_USDC_USD);
        IOracle gbpOracle = IOracle(Mainnet.CHAINLINK_GBP_USD);

        CurveInfo memory gbptCurveInfo = CurveInfo(
            "dfx-gbpt-usdc-v2",
            "dfx-gbpt-v2",
            Mainnet.GBPT,
            Mainnet.USDC,
            CurveParams.BASE_WEIGHT,
            CurveParams.QUOTE_WEIGHT,
            gbpOracle,
            usdOracle,
            CurveParams.ALPHA,
            CurveParams.BETA,
            CurveParams.MAX,
            Mainnet.GBPT_EPSILON,
            CurveParams.LAMBDA
        );

        // Deploy all new Curves
        deployedCurveFactory.newCurve(gbptCurveInfo);

        vm.stopBroadcast();
    }
}
