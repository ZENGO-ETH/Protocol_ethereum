// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../lib/Address.sol";
import "../lib/CheatCodes.sol";

contract Tip is Test{
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    function eurs(address _recipient, uint256 _amount) external {
        cheats.store(
            Mainnet.EURS,
            keccak256(abi.encode(_recipient, 0)), // slot 0
            bytes32(_amount)
        );
    }
}