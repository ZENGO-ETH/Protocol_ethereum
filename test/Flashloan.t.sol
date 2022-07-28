
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
import "../src/Router.sol";
import "../src/lib/ABDKMath64x64.sol";

import "./lib/MockUser.sol";
import "./lib/CheatCodes.sol";
import "./lib/Address.sol";
import "./lib/CurveParams.sol";
import "./utils/Utils.sol";

contract FlashloanTest is Test {
    using SafeMath for uint256;

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    Utils utils;

    MockUser multisig;
    MockUser flashloaner;
    MockUser[2] public users;

    IERC20Detailed usdc = IERC20Detailed(Mainnet.USDC);
    IERC20Detailed cadc = IERC20Detailed(Mainnet.CADC);
    IERC20Detailed xsgd = IERC20Detailed(Mainnet.XSGD);
    IERC20Detailed euroc = IERC20Detailed(Mainnet.EUROC);

    uint8 constant fxTokenCount = 3;

    IERC20Detailed[] public foreignStables = [
        cadc,
        xsgd, 
        euroc, 
        usdc
    ];

    IOracle usdcOracle = IOracle(Mainnet.CHAINLINK_USDC_USD);
    IOracle cadcOracle = IOracle(Mainnet.CHAINLINK_CAD_USD);
    IOracle xsgdOracle = IOracle(Mainnet.CHAINLINK_SGD_USD);
    IOracle eurocOracle = IOracle(Mainnet.CHAINLINK_EUR_USD);

    IOracle[] public foreignOracles = [
        cadcOracle,
        xsgdOracle,
        eurocOracle,
        usdcOracle
    ];

    int128 public protocolFee = 50;

    AssimilatorFactory assimilatorFactory;
    CurveFactoryV2 curveFactory;
    Router router;
    Curve[fxTokenCount] dfxCurves;

    function setUp() public {
        multisig = new MockUser();
        flashloaner = new MockUser();
        utils = new Utils();

        for (uint8 i = 0; i < users.length; i++) {
            users[i] = new MockUser();
        }

        assimilatorFactory = new AssimilatorFactory();
        
        curveFactory = new CurveFactoryV2(
            protocolFee,
            address(multisig),
            address(assimilatorFactory)
        );

        router = new Router(address(curveFactory));
        
        assimilatorFactory.setCurveFactory(address(curveFactory));
        
        for (uint8 i = 0; i < fxTokenCount; i++) {
            CurveInfo memory curveInfo = CurveInfo(
                string.concat("dfx-", foreignStables[i].symbol()),
                string.concat("dfx-", foreignStables[i].symbol()),
                address(foreignStables[i]),
                address(usdc),
                DefaultCurve.BASE_WEIGHT,
                DefaultCurve.QUOTE_WEIGHT,
                address(foreignOracles[i]),
                foreignStables[i].decimals(),
                address(usdcOracle),
                usdc.decimals()
            );

            dfxCurves[i] = curveFactory.newCurve(curveInfo);
            dfxCurves[i].setParams(
                DefaultCurve.ALPHA,
                DefaultCurve.BETA,
                DefaultCurve.MAX,
                DefaultCurve.EPSILON,
                DefaultCurve.LAMBDA
            );

            dfxCurves[i].turnOffWhitelisting();
        }
        

        uint256 user1TknAmnt = 300_000;

        // Mint Foreign Stables
        for (uint8 i = 0; i <= fxTokenCount; i++) {
            uint256 decimals = utils.tenToPowerOf(foreignStables[i].decimals());
            deal(address(foreignStables[i]), address(users[0]), user1TknAmnt.mul(decimals));
        }
        
        cheats.startPrank(address(users[0]));
        for (uint8 i = 0; i < fxTokenCount; i++) {            
            foreignStables[i].approve(address(dfxCurves[i]), type(uint).max);
            foreignStables[i].approve(address(router), type(uint).max);
            usdc.approve(address(dfxCurves[i]), type(uint).max);
        }
        usdc.approve(address(router), type(uint).max);
        cheats.stopPrank();

        cheats.startPrank(address(users[0]));
        for (uint8 i = 0; i < fxTokenCount; i++) {           
            dfxCurves[i].deposit(50_000e18, block.timestamp + 60);
        }
        cheats.stopPrank();
    }
    function testFlashloan() public {
        // emit log_uint(foreignStables[0].balanceOf(address(users[0])));
        // emit log_uint(foreignStables[1].balanceOf(address(users[0])));
        // emit log_uint(foreignStables[2].balanceOf(address(users[0])));
        // emit log_uint(foreignStables[3].balanceOf(address(users[0])));
        // cheats.prank(address(users[0]));
        // CADC -> USDC
        // emit log_uint(router. viewOriginSwap(Mainnet.USDC, Mainnet.XSGD, Mainnet.CADC, 900e6));
        emit log_uint(IERC20(Mainnet.CADC).balanceOf(address(dfxCurves[0])));
        emit log_uint(IERC20(Mainnet.USDC).balanceOf(address(dfxCurves[0])));

        (uint256 bal1, uint256 bal2) = dfxCurves[0].flash(address(flashloaner), 1e6, 1e6);
        emit log_uint(bal1);
        emit log_uint(bal2);

        emit log_uint(IERC20(Mainnet.CADC).balanceOf(address(flashloaner)));
        emit log_uint(IERC20(Mainnet.CADC).balanceOf(address(flashloaner)));
    }
}
