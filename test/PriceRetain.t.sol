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

import "./utils/Utils.sol";

contract PriceRetainsTest is Test {
    using SafeMath for uint256;
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    MockUser public user;
    Utils utils;

    IERC20Detailed usdc = IERC20Detailed(Mainnet.USDC);
    IERC20Detailed xsgd = IERC20Detailed(Mainnet.XSGD);

    Curve xsgdCurve;

    function setUp() public {
        user = new MockUser();
        utils = new Utils();

        xsgdCurve = Curve(Mainnet.XSGD_USDC_POOL);

        uint256 mintAmount = 300_000_000_000_000;
        // mint usdc
        uint256 usdcDecimals = utils.tenToPowerOf(usdc.decimals());
        deal(address(usdc), address(user), mintAmount.mul(usdcDecimals));
        // mint xsgd
        uint256 xsgdDecimals = utils.tenToPowerOf(xsgd.decimals());
        deal(address(xsgd), address(user), mintAmount.mul(xsgdDecimals));

        // now approve
        cheats.startPrank(address(user));
        usdc.approve(address(xsgdCurve), type(uint).max);
        xsgd.approve(address(xsgdCurve), type(uint).max);
        cheats.stopPrank();
    }

    function testTotalSupply() public {
        uint256 originalSupply = xsgdCurve.totalSupply();
        // first stake to get lp tokens
        cheats.startPrank(address(user));
        xsgdCurve.deposit(1000000, block.timestamp + 60);
        uint256 originalLP = xsgdCurve.balanceOf(address(user));
        uint256 originalUSDCBal = usdc.balanceOf(address(xsgdCurve));
        uint256 originalXSGDBal = xsgd.balanceOf(address(xsgdCurve));

        // now directly send tokens
        xsgd.transfer(address(xsgdCurve), 10000);
        usdc.transfer(address(xsgdCurve), 20000);
        uint256 currentLP = xsgdCurve.balanceOf(address(user));
        uint256 currentUSDCBal = usdc.balanceOf(address(xsgdCurve));
        uint256 currentXSGDBal = xsgd.balanceOf(address(xsgdCurve));

        assertApproxEqAbs(originalLP, currentLP,0);
        assertFalse(originalUSDCBal >= currentUSDCBal);
        assertFalse(originalXSGDBal >= currentXSGDBal);
        cheats.stopPrank();
    }

    function testTotalSupplyFuzz(uint256 depositAmt) public {
        cheats.assume(depositAmt >= 1);
        cheats.assume(depositAmt <= 10000000);
        uint256 originalSupply = xsgdCurve.totalSupply();
        // first stake to get lp tokens
        cheats.startPrank(address(user));
        xsgdCurve.deposit(depositAmt.mul(10), block.timestamp + 60);
        uint256 originalLP = xsgdCurve.balanceOf(address(user));
        uint256 originalUSDCBal = usdc.balanceOf(address(xsgdCurve));
        uint256 originalXSGDBal = xsgd.balanceOf(address(xsgdCurve));

        // now directly send tokens
        xsgd.transfer(address(xsgdCurve), depositAmt);
        usdc.transfer(address(xsgdCurve), depositAmt.mul(3));
        uint256 currentLP = xsgdCurve.balanceOf(address(user));
        uint256 currentUSDCBal = usdc.balanceOf(address(xsgdCurve));
        uint256 currentXSGDBal = xsgd.balanceOf(address(xsgdCurve));

        assertApproxEqAbs(originalLP, currentLP,0);
        assertFalse(originalUSDCBal >= currentUSDCBal);
        assertFalse(originalXSGDBal >= currentXSGDBal);
        cheats.stopPrank();
    }

}