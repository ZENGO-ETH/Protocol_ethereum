// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../../src/interfaces/IAssimilator.sol";
import "../../src/interfaces/IOracle.sol";
import "../../src/interfaces/IERC20Detailed.sol";
import "../../src/AssimilatorFactory.sol";
import "../../src/CurveFactoryV2.sol";
import "../../src/Curve.sol";
import "../../src/Config.sol";
import "../../src/Structs.sol";
import "../../src/lib/ABDKMath64x64.sol";

import ".././lib/MockUser.sol";
import ".././lib/CheatCodes.sol";
import ".././lib/Address.sol";
import ".././lib/CurveParams.sol";
import ".././lib/MockChainlinkOracle.sol";
import ".././lib/MockOracleFactory.sol";
import ".././lib/MockToken.sol";

import ".././utils/Utils.sol";

contract MinDepositTest is Test {
    using SafeMath for uint256;
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    Utils utils;

    // account order is lp provider, trader, treasury
    MockUser[] public accounts;

    MockOracleFactory oracleFactory;
    // token order is gold, euroc, cadc, usdc
    IERC20Detailed[] public tokens;
    IOracle[] public oracles;
    Curve[] public curves;
    uint256[] public decimals;

    CurveFactoryV2 curveFactory;
    AssimilatorFactory assimFactory;
    Config config;

    int128 public protocolFee = 50000;

    function setUp() public {
        utils = new Utils();
        // create temp accounts
        for (uint256 i = 0; i < 4; ++i) {
            accounts.push(new MockUser());
        }
        // deploy gold token & init 3 stable coins
        MockToken gold = new MockToken();
        tokens.push(IERC20Detailed(address(gold)));
        tokens.push(IERC20Detailed(Mainnet.EUROC));
        tokens.push(IERC20Detailed(Mainnet.CADC));
        tokens.push(IERC20Detailed(Mainnet.USDC));

        // deploy mock oracle factory for deployed token (named gold)
        oracleFactory = new MockOracleFactory();
        oracles.push(
            oracleFactory.newOracle(
                address(tokens[0]),
                "goldOracle",
                9,
                20000000000
            )
        );
        oracles.push(IOracle(Mainnet.CHAINLINK_EUR_USD));
        oracles.push(IOracle(Mainnet.CHAINLINK_CAD_USD));
        oracles.push(IOracle(Mainnet.CHAINLINK_USDC_USD));

        config = new Config(protocolFee,address(accounts[2]));

        // deploy new assimilator factory & curveFactory v2
        assimFactory = new AssimilatorFactory();
        curveFactory = new CurveFactoryV2(
            address(assimFactory),
            address(config)
        );
        assimFactory.setCurveFactory(address(curveFactory));
        // now deploy curves
        cheats.startPrank(address(accounts[2]));
        for (uint256 i = 0; i < 3; ++i) {
            CurveInfo memory curveInfo = CurveInfo(
                string(abi.encode("dfx-curve-", i)),
                string(abi.encode("lp-", i)),
                address(tokens[i]),
                address(tokens[3]),
                DefaultCurve.BASE_WEIGHT,
                DefaultCurve.QUOTE_WEIGHT,
                oracles[i],
                oracles[3],
                DefaultCurve.ALPHA,
                DefaultCurve.BETA,
                DefaultCurve.MAX,
                DefaultCurve.EPSILON,
                DefaultCurve.LAMBDA
            );
            Curve _curve = curveFactory.newCurve(curveInfo);
            curves.push(_curve);
        }
        cheats.stopPrank();

        // now mint gold & silver tokens
        uint256 mintAmt = 300_000_000_000;
        for (uint256 i = 0; i < 4; ++i) {
            decimals.push(utils.tenToPowerOf(tokens[i].decimals()));
            if (i == 0) {
                tokens[0].mint(address(accounts[0]), mintAmt.mul(decimals[i]));
            } else {
                deal(
                    address(tokens[i]),
                    address(accounts[0]),
                    mintAmt.mul(decimals[i])
                );
            }
        }
        // now approve
        cheats.startPrank(address(accounts[0]));
        for (uint256 i = 0; i < 3; ++i) {
            tokens[i].approve(address(curves[i]), type(uint256).max);
            tokens[3].approve(address(curves[i]), type(uint256).max);
        }
        cheats.stopPrank();
    }

    function testMinDeposit() public {
        uint256 amt = 1000000;
        // mint token to trader
        deal(address(tokens[1]), address(accounts[1]), amt * decimals[1]);

        uint256 eurocToSend = 1000000;
        // mint tokens to attacker
        deal(address(tokens[1]), address(curves[1]), eurocToSend);
        deal(address(tokens[3]), address(curves[1]), eurocToSend * 100);

        uint256 forexBalance = tokens[1].balanceOf(address(accounts[1]));

        cheats.startPrank(address(accounts[1]));
        tokens[1].approve(address(curves[1]), type(uint256).max);
        tokens[3].approve(address(curves[1]), type(uint256).max);
        cheats.stopPrank();
        // destroy balance by first sending 100:1 Usdc : Euroc ratio

        uint256 minEurocToDeposit = 500000000000000;
        uint256 minUsdcToDeposit = 350000000000000;
        // first deposit
        cheats.startPrank(address(accounts[0]));
        curves[1].deposit(1000000000 * 1e18, 0, 0,type(uint256).max,type(uint256).max, block.timestamp + 60);
        cheats.stopPrank();

        // read bal
        uint256 crvEurocBal = tokens[1].balanceOf(address(curves[1]));
        uint256 crvUsdcBal = tokens[3].balanceOf(address(curves[1]));
        console.logString("original balance");
        console.log(eurocToSend);
        console.log(eurocToSend * 100);
        console.logString("new balance");
        console.log(crvEurocBal);
        console.log(crvUsdcBal);
    }

    function testFailMinDeposit() public {
        uint256 amt = 1000000;
        // mint token to trader
        deal(address(tokens[1]), address(accounts[1]), amt * decimals[1]);

        uint256 eurocToSend = 1000000;
        // destroy balance by first sending 100:1 Usdc : Euroc ratio
        deal(address(tokens[1]), address(curves[1]), eurocToSend);
        deal(address(tokens[3]), address(curves[1]), eurocToSend * 100);

        uint256 forexBalance = tokens[1].balanceOf(address(accounts[1]));

        cheats.startPrank(address(accounts[1]));
        tokens[1].approve(address(curves[1]), type(uint256).max);
        tokens[3].approve(address(curves[1]), type(uint256).max);
        cheats.stopPrank();

        uint256 minEurocToDeposit = 500000000000000;
        uint256 minUsdcToDeposit = 350000000000000;
        // deposit
        cheats.startPrank(address(accounts[0]));
        curves[1].deposit(
            1000000000 * 1e18,
            minUsdcToDeposit,
            minEurocToDeposit,
            0,
            0,
            block.timestamp + 60
        );
        cheats.stopPrank();
    }

    function testFailMaxDeposit() public {
        uint256 amt = 10000000;
        // mint token to trader
        deal(address(tokens[1]), address(accounts[1]), amt * decimals[1]);

        // mint 100 euro, 1 usdc to the pool
        deal(address(tokens[1]), address(curves[1]), 100 * decimals[1]);
        deal(address(tokens[3]), address(curves[1]), 1 * decimals[3]);

        uint256 forexBalance = tokens[1].balanceOf(address(accounts[1]));

        cheats.startPrank(address(accounts[1]));
        tokens[1].approve(address(curves[1]), type(uint256).max);
        tokens[3].approve(address(curves[1]), type(uint256).max);
        cheats.stopPrank();

        uint256 maxEurocToDeposit = 600000*decimals[1];
        uint256 maxUsdcToDeposit = 700000 * decimals[3];
        // deposit
        cheats.startPrank(address(accounts[0]));
        curves[1].deposit(
            1000000 * 1e18,
            0,
            0,
            maxUsdcToDeposit,
            maxEurocToDeposit,
            block.timestamp + 60
        );
        cheats.stopPrank();
    }
}