// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IFlashLoanCallee {
    function IFlashLoanCall(
        address receiver,
        address[] memory _token,
        uint256[] memory _amount,
        uint256[] memory _amountPay,
        bytes calldata data
    ) external;
}
