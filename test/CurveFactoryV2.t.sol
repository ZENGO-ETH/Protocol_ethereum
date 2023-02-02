// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/AssimilatorFactory.sol";
import "../src/CurveFactoryV2.sol";
import "../src/Curve.sol";
import "../src/Router.sol";
import "../src/Config.sol";
import "../src/interfaces/IERC20Detailed.sol";

import "./lib/MockUser.sol";
import "./lib/CheatCodes.sol";
import "./lib/Address.sol";
import "./lib/CurveParams.sol";
import "./lib/MockChainlinkOracle.sol";
import "./lib/MockOracleFactory.sol";

contract CurveFactoryV2Test is Test {
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    MockUser treasury;
    MockUser newTreasury;
    MockUser liquidityProvider;

    AssimilatorFactory assimilatorFactory;
    CurveFactoryV2 curveFactory;

    Config config;

    IERC20Detailed usdc = IERC20Detailed(Mainnet.USDC);
    IERC20Detailed cadc = IERC20Detailed(Mainnet.CADC);
    IERC20Detailed euroc = IERC20Detailed(Mainnet.EUROC);

    MockOracleFactory oracleFactory;
    MockUser swapper;
    IOracle fakeCadcOracles;

    IOracle usdcOracle = IOracle(Mainnet.CHAINLINK_USDC_USD);
    IOracle cadcOracle = IOracle(Mainnet.CHAINLINK_CAD_USD);
    IOracle eurocOracle = IOracle(Mainnet.CHAINLINK_EUR_USD);

    Curve dfxCadcCurve;
    Curve dfxEurocCurve;

    int128 public protocolFee = 50;

    Router router;

    function setUp() public {
        treasury = new MockUser();
        newTreasury = new MockUser();
        liquidityProvider = new MockUser();
        swapper = new MockUser();

        config = new Config(protocolFee,address(treasury));

        assimilatorFactory = new AssimilatorFactory();
        curveFactory = new CurveFactoryV2(
            address(assimilatorFactory),
            address(config)
        );

        router = new Router(address(curveFactory));

        // deploy mock oracle factory for deployed token (named gold)
        oracleFactory = new MockOracleFactory();
        fakeCadcOracles = oracleFactory.newOracle(
            // equiv to 1.91 because its 8 decimals
            address(cadc), "CADC-USDC-ORACLE", 8, 1_91_427_874
        );

        assimilatorFactory.setCurveFactory(address(curveFactory));

        cheats.startPrank(address(treasury));
        // Cadc Curve
        CurveInfo memory cadcCurveInfo = CurveInfo(
            string.concat("dfx-", cadc.name()),
            string.concat("dfx-", cadc.symbol()),
            address(cadc),
            address(usdc),
            DefaultCurve.BASE_WEIGHT,
            DefaultCurve.QUOTE_WEIGHT,
            fakeCadcOracles,
            usdcOracle,
            DefaultCurve.ALPHA,
            DefaultCurve.BETA,
            DefaultCurve.MAX,
            DefaultCurve.EPSILON,
            DefaultCurve.LAMBDA
        );

        dfxCadcCurve = curveFactory.newCurve(cadcCurveInfo);
        // Euroc Curve
        CurveInfo memory eurocCurveInfo = CurveInfo(
            string.concat("dfx-", euroc.name()),
            string.concat("dfx-", euroc.symbol()),
            address(euroc),
            address(usdc),
            DefaultCurve.BASE_WEIGHT,
            DefaultCurve.QUOTE_WEIGHT,
            eurocOracle,
            usdcOracle,
            DefaultCurve.ALPHA,
            DefaultCurve.BETA,
            DefaultCurve.MAX,
            DefaultCurve.EPSILON,
            DefaultCurve.LAMBDA
        );

        dfxEurocCurve = curveFactory.newCurve(eurocCurveInfo);
        cheats.stopPrank();
    }

    function testFailDuplicatePairs() public {
        CurveInfo memory curveInfo = CurveInfo(
            string.concat("dfx-", cadc.name()),
            string.concat("dfx-", cadc.symbol()),
            address(cadc),
            address(usdc),
            DefaultCurve.BASE_WEIGHT,
            DefaultCurve.QUOTE_WEIGHT,
            cadcOracle,
            usdcOracle,
            DefaultCurve.ALPHA,
            DefaultCurve.BETA,
            DefaultCurve.MAX,
            DefaultCurve.EPSILON,
            DefaultCurve.LAMBDA
        );
        dfxCadcCurve = curveFactory.newCurve(curveInfo);
        fail("CurveFactory/currency-pair-already-exists");
    }

    function testUpdateFee() public {
        int128 newFee = 100_000;
        config.updateProtocolFee(newFee);
        assertEq(newFee, curveFactory.getProtocolFee());
    }

    function testFailUpdateFee() public {
        int128 newFee = 100_001;
        config.updateProtocolFee(newFee);
    }

    function testUpdateTreasury() public {
        assertEq(address(treasury), curveFactory.getProtocolTreasury());
        config.updateProtocolTreasury(address(newTreasury));
        assertEq(address(newTreasury), curveFactory.getProtocolTreasury());
    }

    // Global Transactable State Frozen
    function testFail_OwnerSetGlobalFrozen() public {
        cheats.prank(address(liquidityProvider));
        IConfig(address(config)).setGlobalFrozen(true);
    }

    function testFail_GlobalFrozenDeposit() public {
        IConfig(address(config)).setGlobalFrozen(true);
        
        cheats.prank(address(liquidityProvider));
        dfxCadcCurve.deposit(100_000,0,0,type(uint256).max, type(uint256).max, block.timestamp + 60);
    }

    function test_GlobalFrozeWithdraw() public {
        deal(address(cadc), address(liquidityProvider), 100_000e18);
        deal(address(usdc), address(liquidityProvider), 100_000e6);

        cheats.startPrank(address(liquidityProvider));
        cadc.approve(address(dfxCadcCurve), type(uint).max);
        usdc.approve(address(dfxCadcCurve), type(uint).max);

        dfxCadcCurve.deposit(100_000e18,0,0,type(uint256).max, type(uint256).max, block.timestamp + 60);
        (uint256 one, uint256[] memory derivatives) = dfxCadcCurve.viewDeposit(100_000e18);
        cheats.stopPrank();

        assertApproxEqAbs(dfxCadcCurve.balanceOf(address(liquidityProvider)), 100_000e18, 1e6);

        cheats.prank(address(this));
        IConfig(address(config)).setGlobalFrozen(true);
        
        // can still withdraw after global freeze
        cheats.prank(address(liquidityProvider));
        dfxCadcCurve.withdraw(100_000e18 - 1e6, block.timestamp + 60);
    }

    function test_depositGlobalGuard(uint256 _gGuardAmt) public {
        cheats.assume(_gGuardAmt > 10_000e18);
        cheats.assume(_gGuardAmt < 100_000_000e18);
        // enable global guard
        config.toggleGlobalGuarded();
        // set global guard amount to 100k
        config.setGlobalGuardAmount(_gGuardAmt);

        deal(address(cadc), address(liquidityProvider), _gGuardAmt * 2);
        deal(address(usdc), address(liquidityProvider), _gGuardAmt / 1e12);

        cheats.startPrank(address(liquidityProvider));
        cadc.approve(address(dfxCadcCurve), type(uint).max);
        usdc.approve(address(dfxCadcCurve), type(uint).max);

        dfxCadcCurve.deposit(_gGuardAmt,0,0,type(uint256).max, type(uint256).max, block.timestamp + 60);
        cheats.stopPrank();
    }

    function testFail_depositGlobalGuard(uint256 _extraAmt) public {
        cheats.assume(_extraAmt > 1);
        cheats.assume(_extraAmt < 100_100e18);
        // enable global guard
        config.toggleGlobalGuarded();
        // set global guard amount to 100k
        config.setGlobalGuardAmount(100_000e18);

        deal(address(cadc), address(liquidityProvider), 200_000e18);
        deal(address(usdc), address(liquidityProvider), 200_000e6);

        cheats.startPrank(address(liquidityProvider));
        cadc.approve(address(dfxCadcCurve), type(uint).max);
        usdc.approve(address(dfxCadcCurve), type(uint).max);

        dfxCadcCurve.deposit(100_000e18 + _extraAmt, 0, 0,type(uint256).max, type(uint256).max, block.timestamp + 60);
        cheats.stopPrank();
    }

    function test_depositPoolGuard(uint256 _extraAmt) public {
        cheats.assume(_extraAmt > 1);
        cheats.assume(_extraAmt < 20_000e18);
        // enable global guard
        config.toggleGlobalGuarded();
        // set global guard amount to 100k
        config.setGlobalGuardAmount(100_000e18);
        // while global guard amt is 100k, Euroc pool guard amt is 80k
        config.setPoolGuarded( address(dfxEurocCurve), true );
        config.setPoolGuardAmount(address(dfxEurocCurve), 80_000e18);

        deal(address(euroc), address(liquidityProvider), 300_000e6);
        deal(address(usdc), address(liquidityProvider), 300_000e6);

        cheats.startPrank(address(liquidityProvider));
        euroc.approve(address(dfxEurocCurve), type(uint).max);
        usdc.approve(address(dfxEurocCurve), type(uint).max);
        // deposit less than 80k
        dfxEurocCurve.deposit(80_000e18 - _extraAmt,0,0,type(uint256).max, type(uint256).max, block.timestamp + 60);
        cheats.stopPrank();
    }

    function testFail_depositPoolGuard(uint256 _extraAmt) public {
        cheats.assume(_extraAmt > 1);
        cheats.assume(_extraAmt < 20_000e18);
        // enable global guard
        config.toggleGlobalGuarded();
        // set global guard amount to 100k
        config.setGlobalGuardAmount(100_000e18);
        // while global guard amt is 100k, Euroc pool guard amt is 80k
        config.setPoolGuarded( address(dfxEurocCurve), true );
        config.setPoolGuardAmount(address(dfxEurocCurve), 80_000e18);

        deal(address(euroc), address(liquidityProvider), 300_000e6);
        deal(address(usdc), address(liquidityProvider), 300_000e6);

        cheats.startPrank(address(liquidityProvider));
        euroc.approve(address(dfxEurocCurve), type(uint).max);
        usdc.approve(address(dfxEurocCurve), type(uint).max);
        // deposit more than 80k
        dfxEurocCurve.deposit(80_000e18 + _extraAmt,0,0,type(uint256).max, type(uint256).max, block.timestamp + 60);
        cheats.stopPrank();
    }

    function test_depositPoolCap() public {
        // set pool cap to 100k
        config.setPoolCap(address(dfxEurocCurve), 100_000e18);

        deal(address(euroc), address(liquidityProvider), 200_000e6);
        deal(address(usdc), address(liquidityProvider), 200_000e6);

        cheats.startPrank(address(liquidityProvider));
        euroc.approve(address(dfxEurocCurve), type(uint).max);
        usdc.approve(address(dfxEurocCurve), type(uint).max);

        dfxEurocCurve.deposit(100_000e18,0,0,type(uint256).max, type(uint256).max, block.timestamp + 60);
        cheats.stopPrank();
    }

    function testFail_depositPoolCap(uint256 _extraAmt) public {
        cheats.assume(_extraAmt > 1);
        cheats.assume(_extraAmt < 10_000e18);
        // set pool cap to 100k
        config.setPoolCap(address(dfxEurocCurve), 100_000e18);

        deal(address(euroc), address(liquidityProvider), 200_000e6);
        deal(address(usdc), address(liquidityProvider), 200_000e6);

        cheats.startPrank(address(liquidityProvider));
        euroc.approve(address(dfxEurocCurve), type(uint).max);
        usdc.approve(address(dfxEurocCurve), type(uint).max);

        dfxEurocCurve.deposit(100_000e18 + _extraAmt,0,0,type(uint256).max, type(uint256).max, block.timestamp + 60);
        cheats.stopPrank();
    }

    function testFail_TargetSwapFreeMoney() public { 
        // set this for no fuzzing 
        // CADC is worth 1.9 USDC right here
        uint256 price = 191427874;
        // this is like 500k of USDC (249k * 1.9)
        uint256 router_amounts = 490_00e6;
        uint256 amounts = 250_000e18;
        
        cheats.startPrank(address(liquidityProvider));
        deal(address(cadc), address(liquidityProvider), 1500000e18 * 1e8 / price); 
        deal(address(usdc), address(liquidityProvider), 1500000e6); 
        cadc.approve(address(dfxCadcCurve), type(uint256).max); 
        usdc.approve(address(dfxCadcCurve), type(uint256).max);
        
        // the LP provides $2M worth of LP
        dfxCadcCurve.deposit(2_000_000e18,0,0,type(uint256).max, type(uint256).max, block.timestamp + 60);
        cheats.stopPrank();
        
        cheats.startPrank(address(swapper));
        deal(address(usdc), address(swapper), 1_500_000e6);
        
        cadc.approve(address(dfxCadcCurve), type(uint256).max);
        usdc.approve(address(dfxCadcCurve), type(uint256).max);

        cadc.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);
        
        // TARGET CADC amounts should be in cadc
        uint256 amountReal = dfxCadcCurve.targetSwap(address(usdc), address(cadc), type(uint256).max, amounts, block.timestamp + 60);
        uint256 amountRecv = dfxCadcCurve.originSwap(address(cadc), address(usdc), cadc.balanceOf(address(swapper)), 0, block.timestamp + 60);

        cheats.stopPrank();

        require(usdc.balanceOf(address(swapper)) >= 1510000e6, "free money!!");
    }
    
    function testFail_invalidNewCurveBase() public {
        cheats.startPrank(address(treasury));
        CurveInfo memory invalidCurveInfo = CurveInfo(
            string.concat("dfx-", cadc.name()),
            string.concat("dfx-", cadc.symbol()),
            // USDC as base
            address(usdc),
            address(usdc),
            DefaultCurve.BASE_WEIGHT,
            DefaultCurve.QUOTE_WEIGHT,
            cadcOracle,
            usdcOracle,
            DefaultCurve.ALPHA,
            DefaultCurve.BETA,
            DefaultCurve.MAX,
            DefaultCurve.EPSILON,
            DefaultCurve.LAMBDA
        );
        
        dfxEurocCurve = curveFactory.newCurve(invalidCurveInfo);
        cheats.stopPrank();
    }

    function testFail_invalidNewCurveQuote() public {
        cheats.startPrank(address(treasury));
        CurveInfo memory invalidCurveInfo = CurveInfo(
            string.concat("dfx-", cadc.name()),
            string.concat("dfx-", cadc.symbol()),
            // Non USDC as quote
            address(usdc),
            address(cadc),
            DefaultCurve.BASE_WEIGHT,
            DefaultCurve.QUOTE_WEIGHT,
            cadcOracle,
            usdcOracle,
            DefaultCurve.ALPHA,
            DefaultCurve.BETA,
            DefaultCurve.MAX,
            DefaultCurve.EPSILON,
            DefaultCurve.LAMBDA
        );
        
        dfxEurocCurve = curveFactory.newCurve(invalidCurveInfo);
        cheats.stopPrank();
    }

    function testFail_invalidNewCurveWeights() public {
        cheats.startPrank(address(treasury));
        CurveInfo memory invalidCurveInfo = CurveInfo(
            string.concat("dfx-", cadc.name()),
            string.concat("dfx-", cadc.symbol()),
            address(cadc),
            address(usdc),
            // Smaller weight
            5e16,
            5e16,
            cadcOracle,
            usdcOracle,
            DefaultCurve.ALPHA,
            DefaultCurve.BETA,
            DefaultCurve.MAX,
            DefaultCurve.EPSILON,
            DefaultCurve.LAMBDA
        );
        
        dfxEurocCurve = curveFactory.newCurve(invalidCurveInfo);
        cheats.stopPrank();
    }
}
