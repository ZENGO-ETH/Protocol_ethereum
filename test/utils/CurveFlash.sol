pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import '@uniswap/v3-core/contracts/libraries/LowGasSafeMath.sol';
import "../../src/Curve.sol";
import "../../src/interfaces/ICurve.sol";
import "../../src/interfaces/IFlashCallback.sol";
import "./FlashStructs.sol";
import "../lib/Address.sol";

contract CurveFlash is IFlashCallback, Test {
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for int256;
    using SafeERC20 for IERC20;

    Curve public dfxCurve;
    
    function flashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external override {    
        FlashCallbackData memory decoded = abi.decode(data, (FlashCallbackData));
        
        address curve = decoded.poolAddress;
        
        address token0 = ICurve(curve).derivatives(0);
        address token1 = ICurve(curve).derivatives(1);

        // Have the additional flashed tokens to do whatever
        assertEq(IERC20(token0).balanceOf(address(this)), uint256(100_000e18).add(decoded.amount0));
        assertEq(IERC20(token1).balanceOf(address(this)), uint256(100_000e6).add(decoded.amount1));

        uint256 amount0Owed = LowGasSafeMath.add(decoded.amount0, fee0);
        uint256 amount1Owed = LowGasSafeMath.add(decoded.amount1, fee1);

        IERC20(token0).safeTransfer(decoded.poolAddress, amount0Owed);
        IERC20(token1).safeTransfer(decoded.poolAddress, amount1Owed);
    }

    function initFlash(address _dfxCurve, FlashParams memory params) external {
        dfxCurve = Curve(_dfxCurve);

        dfxCurve.flash(
            address(this),
            params.amount0,
            params.amount1,
            abi.encode(
                FlashCallbackData({
                    amount0: params.amount0,
                    amount1: params.amount1,
                    poolAddress: _dfxCurve
                })
            )
        );
    }
}