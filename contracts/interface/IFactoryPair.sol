// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
interface IFactoryPair {
    function getPair(address, address) external view returns (address);
}
