// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
interface ISettingExchange {
    
    function Fee() external view returns (uint256);

    function FeeCollector() external view returns (address);

    function durationPaidFee() external view returns (uint256);

    function minAmountToken0(address) external view returns (uint256);

    function minAmountToken1(address) external view returns (uint256);

    function allowlistAddressToken1(address) external view returns (bool);

    function testERC20Token(address token) external view returns (bool);

    function isSaveAddressToken(address token) external view returns (bool);

    function setAddressToken(address token) external;

    function platformFee() external view returns (uint256);

    function userFee() external view returns (uint256);
}
