// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/AssimilatorFactory.sol";
import "../src/CurveFactoryV2.sol";
import "../src/Curve.sol";
import "../src/interfaces/IERC20Detailed.sol";

import "./lib/MockUser.sol";
import "./lib/CheatCodes.sol";
import "./lib/Address.sol";
import "./lib/CurveParams.sol";

contract CurveFactoryV2Test is Test {
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    MockUser treasury;
    MockUser newTreasury;

    AssimilatorFactory assimilatorFactory;
    CurveFactoryV2 curveFactory;

    IERC20Detailed usdc = IERC20Detailed(Mainnet.USDC);
    IERC20Detailed cadc = IERC20Detailed(Mainnet.CADC);
    IERC20Detailed euroc = IERC20Detailed(Mainnet.EUROC);

    IOracle usdcOracle = IOracle(Mainnet.CHAINLINK_USDC_USD);
    IOracle cadcOracle = IOracle(Mainnet.CHAINLINK_CAD_USD);
    IOracle eurocOracle = IOracle(Mainnet.CHAINLINK_EUR_USD);

    Curve dfxCadcCurve;
    Curve dfxEurocCurve;

    int128 public protocolFee = 50;

    function setUp() public {
        treasury = new MockUser();
        newTreasury = new MockUser();

        assimilatorFactory = new AssimilatorFactory();
        curveFactory = new CurveFactoryV2(
            protocolFee,
            address(treasury),
            address(assimilatorFactory)
        );

        assimilatorFactory.setCurveFactory(address(curveFactory));

        CurveInfo memory curveInfo = CurveInfo(
            string.concat("dfx-", cadc.name()),
            string.concat("dfx-", cadc.symbol()),
            address(cadc),
            address(usdc),
            DefaultCurve.BASE_WEIGHT,
            DefaultCurve.QUOTE_WEIGHT,
            address(cadcOracle),
            cadc.decimals(),
            address(usdcOracle),
            usdc.decimals()
        );

        dfxCadcCurve = curveFactory.newCurve(curveInfo);
        dfxCadcCurve.setParams(
            DefaultCurve.ALPHA,
            DefaultCurve.BETA,
            DefaultCurve.MAX,
            DefaultCurve.EPSILON,
            DefaultCurve.LAMBDA
        );
        dfxCadcCurve.turnOffWhitelisting();
    }

    function testFailDuplicatePairs() public {
        CurveInfo memory curveInfo = CurveInfo(
            string.concat("dfx-", cadc.name()),
            string.concat("dfx-", cadc.symbol()),
            address(cadc),
            address(usdc),
            DefaultCurve.BASE_WEIGHT,
            DefaultCurve.QUOTE_WEIGHT,
            address(cadcOracle),
            cadc.decimals(),
            address(usdcOracle),
            usdc.decimals()
        );
        dfxCadcCurve = curveFactory.newCurve(curveInfo);
        fail("CurveFactory/currency-pair-already-exists");
    }

    function testNewPairs() public {
        CurveInfo memory curveInfo = CurveInfo(
            string.concat("dfx-", euroc.name()),
            string.concat("dfx-", euroc.symbol()),
            address(euroc),
            address(usdc),
            DefaultCurve.BASE_WEIGHT,
            DefaultCurve.QUOTE_WEIGHT,
            address(eurocOracle),
            euroc.decimals(),
            address(usdcOracle),
            usdc.decimals()
        );
        dfxEurocCurve = curveFactory.newCurve(curveInfo);

        address curve0 = curveFactory.getCurve(Mainnet.CADC, Mainnet.USDC);
        address curve1 = curveFactory.getCurve(Mainnet.EUROC, Mainnet.USDC);

        assertEq(curve0, address(dfxCadcCurve));
        assertEq(curve1, address(dfxEurocCurve));
    }

    function testUpdateFee() public {
        int128 newFee = 100;
        curveFactory.updateProtocolFee(newFee);
        assertEq(newFee, curveFactory.getProtocolFee());
    }

    function testFailUpdateFee() public {
        int128 newFee = 101;
        curveFactory.updateProtocolFee(newFee);
        fail("CurveFactory/currency-pair-already-exists");
    }

    function testUpdateTreasury() public {
        assertEq(address(treasury), curveFactory.getProtocolTreasury());
        curveFactory.updateProtocolTreasury(address(newTreasury));
        assertEq(address(newTreasury), curveFactory.getProtocolTreasury());
    }

    function testFailUpdateTreasury() public {
        assertEq(address(treasury), curveFactory.getProtocolTreasury());
        curveFactory.updateProtocolTreasury(address(newTreasury));
        fail("CurveFactory/currency-pair-already-exists");
    }
}