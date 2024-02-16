// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IMainValueWallet {
    function balancesSpot(
        address user,
        address addressToken
    ) external view returns (uint256);

    function balancesTrade(
        address user,
        address addressToken
    ) external view returns (uint256);

    function increaseBalancesSpot(
        uint256 amount,
        address user,
        address tokenMain,
        address token0,
        address token1
    ) external;

    function decreaseBalancesSpot(
        uint256 amount,
        address user,
        address tokenMain,
        address token0,
        address token1
    ) external;

    function increaseBalancesTrade(
        uint256 amount,
        address user,
        address tokenMain,
        address token0,
        address token1
    ) external;

    function decreaseBalancesTrade(
        uint256 amount,
        address user,
        address tokenMain,
        address token0,
        address token1
    ) external;

    function increaseBalancesSpotFee(
        uint256 amount,
        address user,
        address tokenMain
    ) external;

    function decreaseBalancesSpotFee(
        uint256 amount,
        address user,
        address tokenMain
    ) external;
}
