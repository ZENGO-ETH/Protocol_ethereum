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

contract V2Test is Test {
    using SafeMath for uint256;
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    Utils utils;

    MockUser public depositor;// one who provides lp to the pool
    MockUser public trader;// one to buys & sells in the pool
    MockUser public treasury; //team treasury

    MockToken gold;//mock erc20 token,
    MockToken silver;//mock erc20 token

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
        
        // now approve
        cheats.startPrank(address(depositor));
        gold.approve(address(goldSilverCurve), type(uint).max);
        silver.approve(address(goldSilverCurve), type(uint).max);
        cheats.stopPrank();
    }
    /**
    deploy gold,silver tokens, their price oracles, assimilators & test swap
    check if v2 factory & it's deployed curve works properly based on both token's price
    assuming both tokens are foreign stable coins
     */
    function testSwap(uint256 amt) public {
        cheats.assume(amt > 0);
        cheats.assume(amt < 100000);
        // mint gold to trader
        gold.mint(address(trader), amt * goldDecimals);
        cheats.startPrank(address(trader));
        gold.approve(address(goldSilverCurve), type(uint).max);
        silver.approve(address(goldSilverCurve), type(uint).max);
        cheats.stopPrank();
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
        uint256 goldTokenDec = gold.decimals();
        uint256 silverTokenDec = silver.decimals();
        uint256 balanceRatio = (
            currentSilverBal.mul(1000).div(silverTokenDec).mul(goldTokenDec).div(originalGoldBal)
        );
        // price ratio is 6:1, balance ration also needs to be approx 6:1
        assertApproxEqAbs(balanceRatio, 6 * 1000, balanceRatio.div(100));
    }

    // checks if directly sending pool tokens, not by calling deposit func of the pool
    // see if the pool token total supply is changed
    // directly tranferring tokens to the pool shouldn't change the pool total supply
    function testTotalSupply(uint256 amount) public {
        cheats.assume(amount > 1);
        cheats.assume(amount < 10000000);
        uint256 originalSupply = goldSilverCurve.totalSupply();
        // first stake to get lp tokens
        uint256 originalLP = goldSilverCurve.balanceOf(address(gold));
        uint256 originalGoldBal = gold.balanceOf(address(gold));
        uint256 originalSilverBal = silver.balanceOf(address(silver));

        // now directly send tokens
        gold.mint(address(goldSilverCurve), amount.div(100));
        silver.mint(address(goldSilverCurve), amount.div(50));
        uint256 currentLP = goldSilverCurve.balanceOf(address(gold));
        uint256 currentGoldBal = gold.balanceOf(address(gold));
        uint256 currentSilverBal = silver.balanceOf(address(silver));
        console.logUint(originalLP);
        console.logUint(currentLP);
        assertApproxEqAbs(originalLP, currentLP,0);
    }

    /*
    * user swaps gold to silver then does reverse swap into gold from silver
    swap amount is relatively huge compare to the pool balance
    after 2 rounds of swap, user gets almost same amount of gold to the original gold balance
     */
    function testSwapDifference (uint256 percentage) public {
        cheats.assume(percentage > 0);
        cheats.assume(percentage < 50);
        // first deposit from the depositor
        cheats.startPrank(address(depositor));
        goldSilverCurve.deposit(10000000 * goldDecimals, block.timestamp + 60);
        cheats.stopPrank();
        uint256 poolGoldBal = gold.balanceOf(address(goldSilverCurve));
        // mint gold to trader
        gold.mint(address(trader), poolGoldBal.div(100).mul(percentage));
        cheats.startPrank(address(trader));
        gold.approve(address(goldSilverCurve), type(uint).max);
        silver.approve(address(goldSilverCurve), type(uint).max);
        uint256 originalGoldBal = gold.balanceOf(address(trader));
        // first swap gold into silver
        goldSilverCurve.originSwap(
            address(gold),
            address(silver),
            originalGoldBal,
            0,
            block.timestamp + 60);
        // now swaps back silver into gold
        goldSilverCurve.originSwap(
            address(silver),
            address(gold),
            silver.balanceOf(address(trader)),
            0,
            block.timestamp + 60
        );
        uint256 currentGoldBal = gold.balanceOf(address(trader));
        assertApproxEqAbs(
            originalGoldBal,
            currentGoldBal,
            originalGoldBal.div(1000)
        );
        cheats.stopPrank();
    }

    function testInvariant () public {
        cheats.startPrank(address(depositor));
        goldSilverCurve.deposit(10000000 * goldDecimals, block.timestamp + 60);
        cheats.stopPrank();
        uint256 poolGoldBal = gold.balanceOf(address(goldSilverCurve));
        uint256 poolSilverBal = silver.balanceOf(address(goldSilverCurve));
        console.logUint(poolGoldBal);
        // mint some % of goldBal of the pool to the trader to swap
        gold.mint(address(trader),  poolGoldBal);
        silver.mint(address(trader), poolSilverBal);
        // now deposit huge amount to the pool
        console.logUint(gold.balanceOf(address(trader)));
        console.logUint(silver.balanceOf(address(trader)));
        cheats.startPrank(address(trader));
        gold.approve(address(goldSilverCurve), type(uint).max);
        silver.approve(address(goldSilverCurve), type(uint).max);
        goldSilverCurve.deposit(poolGoldBal.div(100), block.timestamp + 60);
        cheats.stopPrank();
    }

}