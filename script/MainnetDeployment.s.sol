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
contract MainnetScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Assimilator
        // AssimilatorFactory deployedAssimFactory = new AssimilatorFactory();

        // int128 protocolFee = 50_000;
        
        // Config config = new Config(protocolFee, Mainnet.MULTISIG);
        Config config = Config(0xFC7B7795aa5D8a813b9bbF4D7f2cc05Df5aA843a);
        config.toggleGlobalGuarded();
        config.setGlobalGuardAmount(100_000e18);
        Router deployedRouter = new Router(0x5dccE0942B2Be4Fd70Cb052c1A51DACde1f0Fe89);
        Zap deployedZap = new Zap();

        // Deploy CurveFactoryV2
        // CurveFactoryV2 deployedCurveFactory = new CurveFactoryV2(
            // address(deployedAssimFactory),
            // address(config)
        // );

        // Attach CurveFactoryV2 to Assimilator
        // deployedAssimFactory.setCurveFactory(address(deployedCurveFactory));

        IOracle usdOracle = IOracle(Mainnet.CHAINLINK_USDC_USD);
        // IOracle cadOracle = IOracle(Mainnet.CHAINLINK_CAD_USD);
        // IOracle eurOracle = IOracle(Mainnet.CHAINLINK_EUR_USD);
        // IOracle sgdOracle = IOracle(Mainnet.CHAINLINK_SGD_USD);
        // IOracle nzdOracle = IOracle(Mainnet.CHAINLINK_NZD_USD);
        // IOracle tryOracle = IOracle(Mainnet.CHAINLINK_TRY_USD);
        // IOracle yenOracle = IOracle(Mainnet.CHAINLINK_YEN_USD);
        // IOracle idrOracle = IOracle(Mainnet.CHAINLINK_IDR_USD);
        // IOracle gbpOracle = IOracle(Mainnet.);

        // CurveInfo memory cadcCurveInfo = CurveInfo(
        //     "dfx-cadc-usdc-v2",
        //     "dfx-cadc-v2",
        //     Mainnet.CADC,
        //     Mainnet.USDC,
        //     CurveParams.BASE_WEIGHT,
        //     CurveParams.QUOTE_WEIGHT,
        //     cadOracle,
        //     usdOracle,
        //     CurveParams.ALPHA,
        //     CurveParams.BETA,
        //     CurveParams.MAX,
        //     Mainnet.CADC_EPSILON,
        //     CurveParams.LAMBDA
        // );

        // CurveInfo memory eurocCurveInfo = CurveInfo(
        //     "dfx-euroc-usdc-v2",
        //     "dfx-euroc-v2",
        //     Mainnet.EUROC,
        //     Mainnet.USDC,
        //     CurveParams.BASE_WEIGHT,
        //     CurveParams.QUOTE_WEIGHT,
        //     eurOracle,
        //     usdOracle,
        //     CurveParams.ALPHA,
        //     CurveParams.BETA,
        //     CurveParams.MAX,
        //     Mainnet.EUROC_EPSILON,
        //     CurveParams.LAMBDA
        // );

        // CurveInfo memory xsgdCurveInfo = CurveInfo(
        //     "dfx-xsgd-usdc-v2",
        //     "dfx-xsgd-v2",
        //     Mainnet.XSGD,
        //     Mainnet.USDC,
        //     CurveParams.BASE_WEIGHT,
        //     CurveParams.QUOTE_WEIGHT,
        //     sgdOracle,
        //     usdOracle,
        //     CurveParams.ALPHA,
        //     CurveParams.BETA,
        //     CurveParams.MAX,
        //     Mainnet.XSGD_EPSILON,
        //     CurveParams.LAMBDA
        // );

        // CurveInfo memory nzdsCurveInfo = CurveInfo(
        //     "dfx-nzds-usdc-v2",
        //     "dfx-nzds-v2",
        //     Mainnet.NZDS,
        //     Mainnet.USDC,
        //     CurveParams.BASE_WEIGHT,
        //     CurveParams.QUOTE_WEIGHT,
        //     nzdOracle,
        //     usdOracle,
        //     CurveParams.ALPHA,
        //     CurveParams.BETA,
        //     CurveParams.MAX,
        //     Mainnet.NZDS_EPSILON,
        //     CurveParams.LAMBDA
        // );

        // CurveInfo memory trybCurveInfo = CurveInfo(
        //     "dfx-tryb-usdc-v2",
        //     "dfx-tryb-v2",
        //     Mainnet.TRYB,
        //     Mainnet.USDC,
        //     CurveParams.BASE_WEIGHT,
        //     CurveParams.QUOTE_WEIGHT,
        //     tryOracle,
        //     usdOracle,
        //     CurveParams.ALPHA,
        //     CurveParams.BETA,
        //     CurveParams.MAX,
        //     Mainnet.TRYB_EPSILON,
        //     CurveParams.LAMBDA
        // );

        // CurveInfo memory gyenCurveInfo = CurveInfo(
        //     "dfx-gyen-usdc-v2",
        //     "dfx-gyen-v2",
        //     Mainnet.GYEN,
        //     Mainnet.USDC,
        //     CurveParams.BASE_WEIGHT,
        //     CurveParams.QUOTE_WEIGHT,
        //     yenOracle,
        //     usdOracle,
        //     CurveParams.ALPHA,
        //     CurveParams.BETA,
        //     CurveParams.MAX,
        //     Mainnet.GYEN_EPSILON,
        //     CurveParams.LAMBDA
        // );

        // CurveInfo memory xidrCurveInfo = CurveInfo(
        //     "dfx-xidr-usdc-v2",
        //     "dfx-xidr-v2",
        //     Mainnet.XIDR,
        //     Mainnet.USDC,
        //     CurveParams.BASE_WEIGHT,
        //     CurveParams.QUOTE_WEIGHT,
        //     idrOracle,
        //     usdOracle,
        //     CurveParams.ALPHA,
        //     CurveParams.BETA,
        //     CurveParams.MAX,
        //     Mainnet.XIDR_EPSILON,
        //     CurveParams.LAMBDA
        // );

        // Deploy all new Curves
        // deployedCurveFactory.newCurve(cadcCurveInfo);
        // deployedCurveFactory.newCurve(eurocCurveInfo);
        // deployedCurveFactory.newCurve(xsgdCurveInfo);
        // deployedCurveFactory.newCurve(nzdsCurveInfo);
        // deployedCurveFactory.newCurve(trybCurveInfo);
        // deployedCurveFactory.newCurve(gyenCurveInfo);
        // deployedCurveFactory.newCurve(xidrCurveInfo);

        vm.stopBroadcast();
    }
}
