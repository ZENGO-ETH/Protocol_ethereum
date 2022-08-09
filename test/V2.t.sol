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

    IERC20Detailed usdc;
    IOracle usdcOracle;

    MockOracleFactory oracleFactory;
    MockChainlinkOracle goldOracle;

    Curve goldUsdcCurve;
    CurveFactoryV2 curveFactory;
    AssimilatorFactory assimFactory;
    uint256 public goldDecimals;
    uint256 public usdcDecimals;

    function setUp() public {

        utils = new Utils();
        depositor = new MockUser();
        trader = new MockUser();
        treasury = new MockUser();

        gold = new MockToken();
        usdc = IERC20Detailed(Mainnet.USDC);

        oracleFactory = new MockOracleFactory();
        // gold : silver usd ratio is 6 : 1
        // decimal is 6, usd price is $15
        goldOracle = oracleFactory.newOracle(
            address(gold), "goldOracle",9, 20000000000
        );

        usdcOracle = IOracle(Mainnet.CHAINLINK_USDC_USD);

        assimFactory = new AssimilatorFactory();
        curveFactory = new CurveFactoryV2(
            50, address(treasury), address(assimFactory)
        );
        assimFactory.setCurveFactory(address(curveFactory));

        CurveInfo memory curveInfo = CurveInfo(
            "dfx-gold-usdc",
            "dgs",
            address(gold),
            address(usdc),
            DefaultCurve.BASE_WEIGHT,
            DefaultCurve.QUOTE_WEIGHT,
            address(goldOracle),
            gold.decimals(),
            address(usdcOracle),
            usdc.decimals()
        );
        goldUsdcCurve = curveFactory.newCurve(curveInfo);
        goldUsdcCurve.setParams(
            DefaultCurve.ALPHA,
            DefaultCurve.BETA,
            DefaultCurve.MAX,
            DefaultCurve.EPSILON,
            DefaultCurve.LAMBDA
        );
        goldUsdcCurve.turnOffWhitelisting();

        // now mint gold & silver tokens
        uint256 mintAmt = 300_000_000_000;
        goldDecimals = utils.tenToPowerOf(gold.decimals());
        usdcDecimals = utils.tenToPowerOf(usdc.decimals());

        gold.mint(address(depositor), mintAmt.mul(goldDecimals));
        deal(address(usdc), address(depositor), mintAmt.mul(usdcDecimals));
        // mint only 1k gold tokens 
        
        // now approve
        cheats.startPrank(address(depositor));
        gold.approve(address(goldUsdcCurve), type(uint).max);
        usdc.approve(address(goldUsdcCurve), type(uint).max);
        cheats.stopPrank();
    }
    /**
    deploy gold,usdc tokens, their price oracles, assimilators & test swap
    check if v2 factory & it's deployed curve works properly based on both token's price
    assuming both tokens are foreign stable coins
    gold usdc ratio is 1 : 20
     */
    function testSwap(uint256 amt) public {
        cheats.assume(amt > 100);
        cheats.assume(amt < 10000000);

        // mint gold to trader
        gold.mint(address(trader), amt * goldDecimals);

        uint256 noDecGoldBal = gold.balanceOf(address(trader));
        noDecGoldBal = noDecGoldBal.div(goldDecimals);

        cheats.startPrank(address(trader));
        gold.approve(address(goldUsdcCurve), type(uint).max);
        usdc.approve(address(goldUsdcCurve), type(uint).max);
        cheats.stopPrank();

        // first deposit
        cheats.startPrank(address(depositor));
        goldUsdcCurve.deposit(2000000000 * goldDecimals, block.timestamp + 60);
        cheats.stopPrank();

        cheats.startPrank(address(trader));
        uint256 originalGoldBal = gold.balanceOf(address(trader));
        // now swap gold to usdc
        goldUsdcCurve.originSwap(
            address(gold),
            address(usdc), 
            originalGoldBal,
            0,
            block.timestamp + 60
        );
        cheats.stopPrank();

        uint256 noDecUsdcBal = usdc.balanceOf(address(trader));
        noDecUsdcBal = noDecUsdcBal.div(usdcDecimals);
        console.logUint(noDecGoldBal);
        console.logUint(noDecUsdcBal);
        // price ratio is 1:20, balance ration also needs to be approx 1:20
        assertApproxEqAbs(noDecGoldBal.mul(20), noDecUsdcBal, noDecUsdcBal.div(100));
    }

    // checks if directly sending pool tokens, not by calling deposit func of the pool
    // see if the pool token total supply is changed
    // directly tranferring tokens to the pool shouldn't change the pool total supply
    function testTotalSupply(uint256 amount) public {
        cheats.assume(amount > 1);
        cheats.assume(amount < 10000000);
        uint256 originalSupply = goldUsdcCurve.totalSupply();
        // first stake to get lp tokens
        uint256 originalLP = goldUsdcCurve.balanceOf(address(gold));
        uint256 originalGoldBal = gold.balanceOf(address(gold));
        uint256 originalUSDCBal = usdc.balanceOf(address(usdc));

        // now directly send tokens
        gold.mint(address(goldUsdcCurve), amount.div(100));
        deal(address(usdc),address(goldUsdcCurve), amount.div(50));
        uint256 currentLP = goldUsdcCurve.balanceOf(address(gold));
        uint256 currentGoldBal = gold.balanceOf(address(gold));
        uint256 currentUSDCBal = usdc.balanceOf(address(usdc));
        assertApproxEqAbs(originalLP, currentLP,0);
    }

    /*
    * user swaps gold to usdc then does reverse swap into gold from usdc
    swap amount is relatively huge compare to the pool balance
    after 2 rounds of swap, user gets almost same amount of gold to the original gold balance
     */
    function testSwapDifference (uint256 percentage) public {
        cheats.assume(percentage > 0);
        cheats.assume(percentage < 30);
        // first deposit from the depositor
        cheats.startPrank(address(depositor));
        goldUsdcCurve.deposit(10000000 * goldDecimals, block.timestamp + 60);
        cheats.stopPrank();
        uint256 poolGoldBal = gold.balanceOf(address(goldUsdcCurve));
        // mint gold to trader
        gold.mint(address(trader), poolGoldBal.div(100).mul(percentage));
        cheats.startPrank(address(trader));
        gold.approve(address(goldUsdcCurve), type(uint).max);
        usdc.approve(address(goldUsdcCurve), type(uint).max);
        uint256 originalGoldBal = gold.balanceOf(address(trader));
        // first swap gold into usdc
        goldUsdcCurve.originSwap(
            address(gold),
            address(usdc),
            originalGoldBal,
            0,
            block.timestamp + 60);
        // now swaps back usdc into gold
        goldUsdcCurve.originSwap(
            address(usdc),
            address(gold),
            usdc.balanceOf(address(trader)),
            0,
            block.timestamp + 60
        );
        uint256 currentGoldBal = gold.balanceOf(address(trader));
        assertApproxEqAbs(
            originalGoldBal,
            currentGoldBal,
            originalGoldBal.div(100)
        );
        cheats.stopPrank();
    }

    function testInvariant (uint256 percentage) public {
        cheats.assume(percentage > 0);
        cheats.assume(percentage < 100);
        cheats.startPrank(address(depositor));
        goldUsdcCurve.deposit(10000000 * goldDecimals, block.timestamp + 60);
        cheats.stopPrank();
        uint256 poolGoldBal = gold.balanceOf(address(goldUsdcCurve));
        uint256 poolUSDCBal = usdc.balanceOf(address(goldUsdcCurve));
        // mint some % of goldBal of the pool to the trader to swap
        gold.mint(address(trader),  poolGoldBal.mul(9000000));
        deal(address(usdc),address(trader), poolUSDCBal.mul(9000000));
        // now deposit huge amount to the pool
        cheats.startPrank(address(trader));
        gold.approve(address(goldUsdcCurve), type(uint).max);
        usdc.approve(address(goldUsdcCurve), type(uint).max);
        goldUsdcCurve.deposit(poolGoldBal.div(percentage).mul(100), block.timestamp + 60);
        cheats.stopPrank();
    }

    function testProtocolFee (uint256 traderGoldBal) public{
        cheats.assume(traderGoldBal > 10 * goldDecimals);
        cheats.assume(traderGoldBal < 100000 * goldDecimals);
        cheats.startPrank(address(depositor));
        goldUsdcCurve.deposit(10000000 * goldDecimals, block.timestamp + 60);
        cheats.stopPrank();

        gold.mint(address(trader), traderGoldBal);

        cheats.startPrank(address(trader));
        gold.approve(address(goldUsdcCurve), type(uint256).max);
        usdc.approve(address(goldUsdcCurve), type(uint256).max);

        goldUsdcCurve.originSwap(
            address(gold),
            address(usdc),
            traderGoldBal,
            0,
            block.timestamp + 60
            );
        uint256 treasuryGoldBal = gold.balanceOf(address(treasury));
        uint256 treasuryUsdcBal = usdc.balanceOf(address(treasury));
        uint256 traderUsdcBal = usdc.balanceOf(address(trader));
        // first swap
        console.logString("1st swap");
        console.logUint(traderUsdcBal);
        console.logUint(treasuryUsdcBal);
        console.logString("trader usdc bal");
        console.logUint(traderUsdcBal);
        // second swap
        goldUsdcCurve.originSwap(
            address(usdc),
            address(gold),
            usdc.balanceOf(address(trader)),
            0,
            block.timestamp + 60
            );
        console.logString("2nd swap");
        console.logUint(gold.balanceOf(address(treasury)));
        console.logUint(usdc.balanceOf(address(treasury)));

    }
}
