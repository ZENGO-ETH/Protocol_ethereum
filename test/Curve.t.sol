// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/AssimilatorFactory.sol";
import "../src/CurveFactoryV2.sol";
import "../src/Curve.sol";
import "../src/interfaces/IERC20Detailed.sol";
import "../src/interfaces/IAssimilator.sol";
import "../src/interfaces/IOracle.sol";

import "./lib/MockUser.sol";
import "./lib/CheatCodes.sol";
import "./lib/Address.sol";
import "./lib/CurveParams.sol";

contract CurveFactoryV2Test is Test {
    using SafeMath for uint256;

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    MockUser treasury;
    MockUser newTreasury;
    MockUser liquidityProvider;

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
        liquidityProvider = new MockUser();
        
        cheats.startPrank(address(treasury));
        assimilatorFactory = new AssimilatorFactory();
        curveFactory = new CurveFactoryV2(
            protocolFee,
            address(treasury),
            address(assimilatorFactory)
        );

        assimilatorFactory.setCurveFactory(address(curveFactory));
        cheats.stopPrank();
    }

    function testUpdatingIncorrectOracles() public { // wrong/malicious info
        cheats.startPrank(address(treasury));
        // Incorrect oracles, with correct token pairing and decimals
        CurveInfo memory badCadcCurveInfo = CurveInfo(
            string.concat("dfx-", cadc.name()),
            string.concat("dfx-", cadc.symbol()),
            // Haechi #5 
            // 1. locks USDC as the quote token
            // 2. removes token decimals field and just retrieves them from the tokens themselves
            // as long as base token remains the same there will be no issues with changing to a new oracle
            address(cadc),
            address(usdc),
            DefaultCurve.BASE_WEIGHT,
            DefaultCurve.QUOTE_WEIGHT,
            eurocOracle,
            18,
            eurocOracle,
            6,
            DefaultCurve.ALPHA,
            DefaultCurve.BETA,
            DefaultCurve.MAX,
            DefaultCurve.EPSILON,
            DefaultCurve.LAMBDA
        );
        dfxCadcCurve = curveFactory.newCurve(badCadcCurveInfo);

        console.log(address(assimilatorFactory.getAssimilator(address(cadc))));

        // Assim address from the factory
        AssimilatorV2 cadcFactoryAssimBefore = assimilatorFactory.getAssimilator(address(cadc));
        AssimilatorV2 usdcFactoryAssimBefore = assimilatorFactory.getAssimilator(address(usdc));

        // Assim address from the curve
        IAssimilator cadcCurveAssimBefore = IAssimilator(dfxCadcCurve.assimilator(address(cadc)));
        IAssimilator usdcCurveAssimBefore = IAssimilator(dfxCadcCurve.assimilator(address(usdc)));

        // Curve vs Factory assim
        assertTrue(cadcCurveAssimBefore == cadcFactoryAssimBefore, "before-update/curve and factory cadc assimilators are not the same");
        assertTrue(usdcCurveAssimBefore == usdcFactoryAssimBefore, "before-update/curve and factory usdc assimilators are not the same");

        uint256 cadcRateBefore = cadcCurveAssimBefore.getRate();
        uint256 usdcRateBefore = usdcCurveAssimBefore.getRate();
        
        // Bad front ran oracles rates should be the same for USDC vs CADC
        assertTrue(cadcCurveAssimBefore.getRate() == usdcCurveAssimBefore.getRate(), "before-update/usdc and cadc rates are not the same");

        // PAUSE THE POOLS
        dfxCadcCurve.setFrozen(true);

        // Only owner revoking assimilators
        assimilatorFactory.revokeAssimilator(address(cadc));
        assimilatorFactory.revokeAssimilator(address(usdc));

        // Create new assimilators for respective tokens
        assimilatorFactory.newAssimilator(
            cadcOracle,
            address(cadc),
            18
        );

        assimilatorFactory.newAssimilator(
            usdcOracle,
            address(usdc),
            6
        );

        IAssimilator cadcFactoryAssimNew = assimilatorFactory.getAssimilator(address(cadc));
        IAssimilator usdcFactoryAssimNew = assimilatorFactory.getAssimilator(address(usdc));

        // New assimilator should be different than the old
        assertTrue(cadcFactoryAssimNew != cadcFactoryAssimBefore, "after-update/curve and factory cadc assimilators are the same");
        assertTrue(usdcFactoryAssimNew != usdcFactoryAssimBefore, "after-update/curve and factory usdc assimilators are the same");

        // Set new assimilators
        dfxCadcCurve.setAssimilator(
            address(cadc),
            address(cadcFactoryAssimNew),
            address(usdc),  
            address(usdcFactoryAssimNew)
        );

        IAssimilator cadcCurveAssimNew = IAssimilator(dfxCadcCurve.assimilator(address(cadc)));
        IAssimilator usdcCurveAssimNew = IAssimilator(dfxCadcCurve.assimilator(address(usdc)));
        
        // Curve vs Factory assim
        assertTrue(cadcFactoryAssimNew == cadcCurveAssimNew, "after-update/curve and factory cadc assimilators are not the same");
        assertTrue(usdcFactoryAssimNew == usdcCurveAssimNew, "after-update/curve and factory usdc assimilators are not the same");

        // Rates should be all different now and non zero
        uint256 cadcRateAfter = cadcCurveAssimNew.getRate();
        uint256 usdcRateAfter = usdcCurveAssimNew.getRate();

        assertTrue(cadcRateAfter != usdcRateAfter, "after-update/cadc and usdc rates are the same");
        console.log(cadcRateAfter, usdcRateAfter);
        assertTrue(cadcRateAfter != 0, "after-update/zero cadc rate");
        assertTrue(usdcRateAfter != 0, "after-update/zero usdc rate");
        
        // Comparing to old rates
        assertTrue(cadcRateAfter != cadcRateBefore, "after-update/cadc rates are the same as before");
        assertTrue(usdcRateAfter != usdcRateBefore, "after-update/usdc rates are the same as before");

        // UNPAUSE THE POOLS
        dfxCadcCurve.setFrozen(false);
        console.log(address(assimilatorFactory.getAssimilator(address(cadc))));
        console.log(address(assimilatorFactory.getAssimilator(address(usdc))));


        // console.log(dfxCadcCurve.assimilator(address(cadc)));
        // console.log(dfxCadcCurve.assimilator(address(usdc)));
        cheats.stopPrank();

        // Check swaps, withdrawals, and deposits
        cheats.startPrank(address(liquidityProvider));
        deal(address(cadc), address(liquidityProvider), 100_000e18);
        deal(address(usdc), address(liquidityProvider), 100_000e6);
        cadc.approve(address(dfxCadcCurve), type(uint).max);
        usdc.approve(address(dfxCadcCurve), type(uint).max); 
        dfxCadcCurve.deposit(100_000e18, block.timestamp + 60);
        
        uint256 cadcBalanceBeforeSwap = cadc.balanceOf(address(liquidityProvider));
        uint256 usdcBalanceBeforeSwap = usdc.balanceOf(address(liquidityProvider));
        console.log(cadcBalanceBeforeSwap);
        console.log(usdcBalanceBeforeSwap);

        dfxCadcCurve.originSwap(address(usdc), address(cadc), 10_000e6, 0, block.timestamp + 60);
        dfxCadcCurve.originSwap(address(cadc), address(usdc), uint256(10_000e18).div(cadcRateAfter).mul(1e8), 0, block.timestamp + 60);

        uint256 cadcBalanceAfterSwap = cadc.balanceOf(address(liquidityProvider));
        uint256 usdcBalanceAfterSwap = usdc.balanceOf(address(liquidityProvider));

        assertApproxEqRel(cadcBalanceAfterSwap, cadcBalanceBeforeSwap, 0.01e18);
        assertApproxEqRel(usdcBalanceAfterSwap, usdcBalanceBeforeSwap, 0.01e18);

        dfxCadcCurve.withdraw(100_000e18, block.timestamp + 60);
        uint256 cadcBalanceAfterWithdraw = cadc.balanceOf(address(liquidityProvider));
        uint256 usdcBalanceAfterWithdraw = usdc.balanceOf(address(liquidityProvider));

        assertApproxEqRel(cadcBalanceAfterWithdraw, 100_000e18, 0.01e18);
        assertApproxEqRel(usdcBalanceAfterWithdraw, 100_000e6, 0.01e18);

        cheats.stopPrank();
    }

    // Make sure random people cant revoke assimilators
    function testFail_notOwnerRevokeAssimilator() public {
        CurveInfo memory goodCadcCurveInfo = CurveInfo(
            string.concat("dfx-", cadc.name()),
            string.concat("dfx-", cadc.symbol()),
            address(cadc),
            address(usdc),
            DefaultCurve.BASE_WEIGHT,
            DefaultCurve.QUOTE_WEIGHT,
            cadcOracle,
            18,
            usdcOracle,
            6,
            DefaultCurve.ALPHA,
            DefaultCurve.BETA,
            DefaultCurve.MAX,
            DefaultCurve.EPSILON,
            DefaultCurve.LAMBDA
        );
        dfxCadcCurve = curveFactory.newCurve(goodCadcCurveInfo);

        // Someone trying to mess up an exisiting assimilators
        assimilatorFactory.revokeAssimilator(address(cadc));
        assimilatorFactory.revokeAssimilator(address(usdc));
    }
    
    function testFail_NotOwnerNewAssimilator() public {
        CurveInfo memory goodCadcCurveInfo = CurveInfo(
            string.concat("dfx-", cadc.name()),
            string.concat("dfx-", cadc.symbol()),
            address(cadc),
            address(usdc),
            DefaultCurve.BASE_WEIGHT,
            DefaultCurve.QUOTE_WEIGHT,
            cadcOracle,
            18,
            usdcOracle,
            6,
            DefaultCurve.ALPHA,
            DefaultCurve.BETA,
            DefaultCurve.MAX,
            DefaultCurve.EPSILON,
            DefaultCurve.LAMBDA
        );
        dfxCadcCurve = curveFactory.newCurve(goodCadcCurveInfo);

        IAssimilator usdcFactoryAssimNew = assimilatorFactory.getAssimilator(address(usdc));

        // Someone trying to mess up an exisiting curve
        dfxCadcCurve.setAssimilator(
            address(usdc),
            address(usdcFactoryAssimNew), 
            address(usdc), 
            address(usdcFactoryAssimNew)
        );
    }
}