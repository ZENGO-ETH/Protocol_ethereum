// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "./CurveParams.sol";

// Libraries
import "../src/Curve.sol";
import "../src/Config.sol";

// Factories
import "../src/CurveFactoryV2.sol";

import "./Addresses.sol";
import '../src/interfaces/IERC20Detailed.sol';

// POLYGON DEPLOYMENT
contract ContractScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Assimilator
        AssimilatorFactory deployedAssimFactory = new AssimilatorFactory();

        int128 protocolFee = 50_000;
        
        Config config = new Config(protocolFee, Polygon.MULTISIG);

        
        // Deploy CurveFactoryV2
        CurveFactoryV2 deployedCurveFactory = new CurveFactoryV2(
            address(deployedAssimFactory),
            address(config)
        );

        // Attach CurveFactoryV2 to Assimilator
        deployedAssimFactory.setCurveFactory(address(deployedCurveFactory));

        IOracle usdOracle = IOracle(Polygon.CHAINLINK_USDC_USD);
        IOracle cadOracle = IOracle(Polygon.CHAINLINK_CAD_USD);
        IOracle eurOracle = IOracle(Polygon.CHAINLINK_EUR_USD);
        IOracle sgdOracle = IOracle(Polygon.CHAINLINK_SGD_USD);
        IOracle nzdOracle = IOracle(Polygon.CHAINLINK_NZD_USD);
        IOracle tryOracle = IOracle(Polygon.CHAINLINK_TRY_USD);

        CurveInfo memory cadcCurveInfo = CurveInfo(
            "dfx-cadc-usdc-v2",
            "dfx-cadc-v2",
            Polygon.CADC,
            Polygon.USDC,
            CurveParams.BASE_WEIGHT,
            CurveParams.QUOTE_WEIGHT,
            cadOracle,
            usdOracle,
            CurveParams.ALPHA,
            CurveParams.BETA,
            CurveParams.MAX,
            Polygon.CADC_EPSILON,
            CurveParams.LAMBDA
        );

        CurveInfo memory eursCurveInfo = CurveInfo(
            "dfx-eurs-usdc-v2",
            "dfx-eurs-v2",
            Polygon.EURS,
            Polygon.USDC,
            CurveParams.BASE_WEIGHT,
            CurveParams.QUOTE_WEIGHT,
            eurOracle,
            usdOracle,
            CurveParams.ALPHA,
            CurveParams.BETA,
            CurveParams.MAX,
            Polygon.EURS_EPSILON,
            CurveParams.LAMBDA
        );

        CurveInfo memory xsgdCurveInfo = CurveInfo(
            "dfx-xsgd-usdc-v2",
            "dfx-xsgd-v2",
            Polygon.XSGD,
            Polygon.USDC,
            CurveParams.BASE_WEIGHT,
            CurveParams.QUOTE_WEIGHT,
            sgdOracle,
            usdOracle,
            CurveParams.ALPHA,
            CurveParams.BETA,
            CurveParams.MAX,
            Polygon.XSGD_EPSILON,
            CurveParams.LAMBDA
        );

        CurveInfo memory nzdsCurveInfo = CurveInfo(
            "dfx-nzds-usdc-v2",
            "dfx-nzds-v2",
            Polygon.NZDS,
            Polygon.USDC,
            CurveParams.BASE_WEIGHT,
            CurveParams.QUOTE_WEIGHT,
            nzdOracle,
            usdOracle,
            CurveParams.ALPHA,
            CurveParams.BETA,
            CurveParams.MAX,
            Polygon.NZDS_EPSILON,
            CurveParams.LAMBDA
        );

        CurveInfo memory trybCurveInfo = CurveInfo(
            "dfx-tryb-usdc-v2",
            "dfx-tryb-v2",
            Polygon.TRYB,
            Polygon.USDC,
            CurveParams.BASE_WEIGHT,
            CurveParams.QUOTE_WEIGHT,
            tryOracle,
            usdOracle,
            CurveParams.ALPHA,
            CurveParams.BETA,
            CurveParams.MAX,
            Polygon.TRYB_EPSILON,
            CurveParams.LAMBDA
        );

        // Deploy all new Curves
        deployedCurveFactory.newCurve(cadcCurveInfo);
        deployedCurveFactory.newCurve(eursCurveInfo);
        deployedCurveFactory.newCurve(xsgdCurveInfo);
        deployedCurveFactory.newCurve(nzdsCurveInfo);
        deployedCurveFactory.newCurve(trybCurveInfo);

        vm.stopBroadcast();
    }
}