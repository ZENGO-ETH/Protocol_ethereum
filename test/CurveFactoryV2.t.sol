// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../src/interfaces/IAssimilator.sol";
import "../src/interfaces/IOracle.sol";
import "../src/interfaces/IERC20Detailed.sol";
import "../src/AssimilatorFactory.sol";
import "../src/CurveFactoryV2.sol";
import "../src/Curve.sol";
import "../src/Structs.sol";
import "../src/lib/ABDKMath64x64.sol";

import "./lib/MockUser.sol";
import "./lib/CheatCodes.sol";
import "./lib/Address.sol";
import "./lib/CurveParams.sol";
import "./lib/MockChainlinkOracle.sol";
import "./lib/MockOracleFactory.sol";
import "./lib/MockToken.sol";

import "./utils/Utils.sol";

contract CurveFactoryV2Test is Test {
    using SafeMath for uint256;

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    Utils utils;

    MockUser public depositor;
    MockUser public trader;
    MockUser public treasury;

    MockToken gold;
    MockToken silver;

    MockOracleFactory oracleFactory;
    MockChainlinkOracle goldOracle;
    MockChainlinkOracle silverOracle;

    Curve goldSilverCurve;
    CurveFactoryV2 curveFactory;
    AssimilatorFactory assimFactory;
    uint256 public goldDecimals;
    uint256 public silverDecimals;

    function setUp() public {

        utils = new Utils();
        depositor = new MockUser();
        trader = new MockUser();
        treasury = new MockUser();

        gold = new MockToken();
        silver = new MockToken();

        oracleFactory = new MockOracleFactory();
        // gold : silver usd ratio is 6 : 1
        // decimal is 6, usd price is $15
        goldOracle = oracleFactory.newOracle(
            address(gold), "goldOracle",6, 15000000
        );
        // decimal is 4, usd price is $2.5
        silverOracle = oracleFactory.newOracle(
            address(silver), "silverOracle", 4, 25000
        );

        assimFactory = new AssimilatorFactory();
        curveFactory = new CurveFactoryV2(
            50, address(treasury), address(assimFactory)
        );
        assimFactory.setCurveFactory(address(curveFactory));

        CurveInfo memory curveInfo = CurveInfo(
            "dfx-gold-silver",
            "dgs",
            address(gold),
            address(silver),
            DefaultCurve.BASE_WEIGHT,
            DefaultCurve.QUOTE_WEIGHT,
            address(goldOracle),
            gold.decimals(),
            address(silverOracle),
            silver.decimals()
        );
        goldSilverCurve = curveFactory.newCurve(curveInfo);
        goldSilverCurve.setParams(
            DefaultCurve.ALPHA,
            DefaultCurve.BETA,
            DefaultCurve.MAX,
            DefaultCurve.EPSILON,
            DefaultCurve.LAMBDA
        );
        goldSilverCurve.turnOffWhitelisting();

        // now mint gold & silver tokens
        uint256 mintAmt = 300_000_000;
        goldDecimals = utils.tenToPowerOf(gold.decimals());
        silverDecimals = utils.tenToPowerOf(silver.decimals());

        gold.mint(address(depositor), mintAmt.mul(goldDecimals));
        silver.mint(address(depositor), mintAmt.mul(silverDecimals));
        // mint only 1k gold tokens 
        gold.mint(address(trader), 4 * goldDecimals);
        // now approve
        cheats.startPrank(address(depositor));
        gold.approve(address(goldSilverCurve), type(uint).max);
        silver.approve(address(goldSilverCurve), type(uint).max);
        cheats.stopPrank();
        cheats.startPrank(address(trader));
        gold.approve(address(goldSilverCurve), type(uint).max);
        silver.approve(address(goldSilverCurve), type(uint).max);
        cheats.stopPrank();
    }

    function testSwap () public {
        // first deposit
        cheats.startPrank(address(depositor));
        goldSilverCurve.deposit(10000000 * goldDecimals, block.timestamp + 60);
        cheats.stopPrank();
        cheats.startPrank(address(trader));
        uint256 originalGoldBal = gold.balanceOf(address(trader));
        // now swap gold to silver
        goldSilverCurve.originSwap(
            address(gold),
            address(silver), 
            originalGoldBal,
            0,
            block.timestamp + 60
        );
        uint256 currentSilverBal = silver.balanceOf(address(trader));
        cheats.stopPrank();
    }
}