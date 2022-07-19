
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./lib/MockUser.sol";
import "./lib/CheatCodes.sol";
import "./lib/Address.sol";

import "./utils/Tip.sol";

contract RouterTest is Test {
    
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    MockUser user1;
    MockUser user2;
    Tip tipToken;
    
    IERC20 eurs = IERC20(Mainnet.EURS);

    function setUp() public {
        user1 = new MockUser();
        user2 = new MockUser();
        tipToken = new Tip();
    }


    function test_router() public {
        assertEq(uint(1), uint(1));
        // tipEurs(address(this), 69e18);
        // tipToken.eurs(address(this), 69e18);
        // emit log_uint(eurs.balanceOf(address(this)));
    }
}