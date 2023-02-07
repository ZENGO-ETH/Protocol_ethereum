// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../../src/AssimilatorFactory.sol";
import "../../src/CurveFactoryV2.sol";
import "../../src/Curve.sol";
import "../../src/interfaces/IERC20Detailed.sol";

import ".././lib/MockUser.sol";
import ".././lib/CheatCodes.sol";
import ".././lib/Address.sol";
import ".././lib/CurveParams.sol";

contract FactoryAddressCheck is Test {
    AssimilatorFactory assimilatorFactory;

    function setUp() public {
        assimilatorFactory = new AssimilatorFactory();
    }

    function testFailZeroFactoryAddress() public {
        assimilatorFactory.setCurveFactory(address(0));
        fail("AssimFactory/curve factory zero address!");
    }
}

