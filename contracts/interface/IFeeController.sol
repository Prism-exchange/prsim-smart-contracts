// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface IFeeController {
    function createPosition(
        uint256 _amount,
        uint256 _price,
        address _user,
        address _pair,
        uint8 _isBuy,
        uint256 tickFeeID,
        bool craeteTickFeeID
    ) external returns (uint256);

    function withdrawnPosition(
        uint256 _amount,
        address _user,
        address _pair,
        uint8 _isBuy,
        uint256 tickFeeID
    ) external;

    function getCurrentTickFee(
        address _pair,
        uint8 _isBuy
    ) external view returns (uint256);

    function collectFeeReward(
        address _pair,
        uint256[2] calldata _amount,
        uint8[2] calldata _isBuy
    ) external;
}
