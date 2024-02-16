// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
 
interface IBlast {
    function configureClaimableGas() external;
    function configureGovernor(address _governor) external;

}
