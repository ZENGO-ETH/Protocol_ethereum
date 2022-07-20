
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../src/interfaces/IAssimilator.sol";
import "../src/interfaces/IOracle.sol";
import "../src/AssimilatorFactory.sol";
import "../src/CurveFactoryV2.sol";
import "../src/Curve.sol";
import "../src/Structs.sol";

import "./lib/MockUser.sol";
import "./lib/CheatCodes.sol";
import "./lib/Address.sol";

contract SwapTest is Test {
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    MockUser user1;
    MockUser user2;
    MockUser multisig;

    IERC20 usdc = IERC20(Mainnet.USDC);
    IERC20 cadc = IERC20(Mainnet.CADC);
    IERC20 xsgd = IERC20(Mainnet.XSGD);
    IERC20 euroc = IERC20(Mainnet.EUROC);

    IOracle cadcOracle = IOracle(Mainnet.CHAINLINK_CADC_USD);
    IOracle usdcOracle = IOracle(Mainnet.CHAINLINK_USDC_USD);
    
    int128 public protocolFee = 1;
    
    string public name = "dfx-cadc";
    string public symbol = "dfx-cadc-usdc";
    address public baseCurrency = address(cadc);
    address public quoteCurrency = address(usdc);
    uint256 public baseWeight = 4e17;
    uint256 public quoteWeight = 6e17;
    address public baseOracle = address(cadcOracle);
    // TODO: change it so its can just read off the existing tokens
    uint256 public baseDec = 18;
    address public quoteOracle = address(usdcOracle);
    uint256 public quoteDec = 6;

    // TODO: export out
    uint256 ALPHA = 5e17;
    uint256 BETA = 35e16;
    uint256 MAX = 15e16;
    uint256 EPSILON = 4e14;
    uint256 LAMBDA = 3e17;

    AssimilatorFactory assimilatorFactory;
    CurveFactoryV2 curveFactory;
    Curve cadcCurve;
    Curve eurocCurve;
    
    CurveInfo curveInfo = CurveInfo(
        name,
        symbol,
        baseCurrency,
        quoteCurrency,
        baseWeight,
        quoteWeight,
        baseOracle,
        baseDec,
        quoteOracle,
        quoteDec
    );

    function setUp() public {
        user1 = new MockUser();
        user2 = new MockUser();
        multisig = new MockUser();

        assimilatorFactory = new AssimilatorFactory();
        
        curveFactory = new CurveFactoryV2(
            protocolFee,
            address(multisig),
            address(assimilatorFactory)
        );

        assimilatorFactory.setCurveFactory(address(curveFactory));

        cadcCurve = curveFactory.newCurve(curveInfo);

        // TODO: export out
        cadcCurve.setParams(
            ALPHA,
            BETA,
            MAX,
            EPSILON,
            LAMBDA            
        );
        
        deal(address(usdc), address(user1), 300_000_000e6);
        deal(address(cadc), address(user1), 300_000_000e18);
        deal(address(euroc), address(user1), 300_000_000e6);
        deal(address(xsgd), address(user1), 300_000_000e6);

        deal(address(cadc), address(user2), 1_000_000e18);

        cheats.startPrank(address(user2));
        cadc.approve(address(cadcCurve), type(uint).max);
        usdc.approve(address(cadcCurve), type(uint).max);
        cheats.stopPrank();

        // TODO: export out
        cheats.startPrank(address(user1));
        cadc.approve(address(cadcCurve), type(uint).max);
        usdc.approve(address(cadcCurve), type(uint).max);
        cheats.stopPrank();

        cadcCurve.turnOffWhitelisting();
    }


    // Fuzzing
    function test_swap(uint256 tokenAmount) public {
        // Change decimals
        cheats.assume(tokenAmount > 1e18);
        cheats.assume(tokenAmount < 100_000e18);

        cheats.prank(address(user1));
        cadcCurve.deposit(1_000_000e18, block.timestamp + 60);

        emit log_uint(cadc.balanceOf(address(cadcCurve)));
        emit log_uint(usdc.balanceOf(address(cadcCurve)));

        cheats.startPrank(address(user2));
        cadcCurve.originSwap(Mainnet.CADC, Mainnet.USDC, tokenAmount, 0, block.timestamp + 60);

        emit log_uint(cadc.balanceOf(address(cadcCurve)));
        emit log_uint(usdc.balanceOf(address(cadcCurve)));

        uint256 user2USDCBal = usdc.balanceOf(address(user2));
        cadcCurve.originSwap(Mainnet.USDC, Mainnet.CADC, user2USDCBal, 0, block.timestamp + 60);

        emit log_uint(cadc.balanceOf(address(cadcCurve)));
        emit log_uint(usdc.balanceOf(address(cadcCurve)));
    }
}