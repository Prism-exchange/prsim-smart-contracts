/* SPDX-License-Identifier: MIT


PPPPPPPPPPPPPPPPP   RRRRRRRRRRRRRRRRR   IIIIIIIIII   SSSSSSSSSSSSSSS MMMMMMMM               MMMMMMMM
P::::::::::::::::P  R::::::::::::::::R  I::::::::I SS:::::::::::::::SM:::::::M             M:::::::M
P::::::PPPPPP:::::P R::::::RRRRRR:::::R I::::::::IS:::::SSSSSS::::::SM::::::::M           M::::::::M
PP:::::P     P:::::PRR:::::R     R:::::RII::::::IIS:::::S     SSSSSSSM:::::::::M         M:::::::::M
  P::::P     P:::::P  R::::R     R:::::R  I::::I  S:::::S            M::::::::::M       M::::::::::M
  P::::P     P:::::P  R::::R     R:::::R  I::::I  S:::::S            M:::::::::::M     M:::::::::::M
  P::::PPPPPP:::::P   R::::RRRRRR:::::R   I::::I   S::::SSSS         M:::::::M::::M   M::::M:::::::M
  P:::::::::::::PP    R:::::::::::::RR    I::::I    SS::::::SSSSS    M::::::M M::::M M::::M M::::::M
  P::::PPPPPPPPP      R::::RRRRRR:::::R   I::::I      SSS::::::::SS  M::::::M  M::::M::::M  M::::::M
  P::::P              R::::R     R:::::R  I::::I         SSSSSS::::S M::::::M   M:::::::M   M::::::M
  P::::P              R::::R     R:::::R  I::::I              S:::::SM::::::M    M:::::M    M::::::M
  P::::P              R::::R     R:::::R  I::::I              S:::::SM::::::M     MMMMM     M::::::M
PP::::::PP          RR:::::R     R:::::RII::::::IISSSSSSS     S:::::SM::::::M               M::::::M
P::::::::P          R::::::R     R:::::RI::::::::IS::::::SSSSSS:::::SM::::::M               M::::::M
P::::::::P          R::::::R     R:::::RI::::::::IS:::::::::::::::SS M::::::M               M::::::M
PPPPPPPPPP          RRRRRRRR     RRRRRRRIIIIIIIIII SSSSSSSSSSSSSSS   MMMMMMMM               MMMMMMMM


 */

pragma solidity ^0.8.0;

import './interface/ISettingExchange.sol';
import './Pair.sol';

/**
 * @title FactoryPair
 * @author Prism exchange
 * @dev This contract is Factory for create contract PairNewOrder each pair in Prism exchange such as BTC/USD , ETH/USD
 */
contract FactoryPair {
    //=======================================
    //========= State Variables =============
    //=======================================

    // Mapping from address token0 => address token1  => address Pair
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    address public mainValueWallet;
    address public settingExchange;
    address public feeController;

    //=======================================
    //=============== Events ================
    //=======================================

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    /**
     * @dev Constructor function that initializes address mainValueWallet,settingExchange
     * @param _mainValueWallet - The address of the mainValueWallet
     * @param _settingExchange - The address of the settingExchange
     */
    constructor(
        address _mainValueWallet,
        address _settingExchange,
        address _feeController
    ) {
        mainValueWallet = _mainValueWallet;
        settingExchange = _settingExchange;
        feeController = _feeController;
    }

    //=======================================
    //============ Functions ================
    //=======================================

    /**
     * @dev Function used to get length allPairs
     * @return uint256 - The length of allPairs
     */
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    /**
     * @notice Function used to createPair in Prism exchange such as BTC/USD , ETH/USD
     * @param token0 - The address of token0
     * @param token1 - The address of token1
     * @return pair - The address of pair
     */
    function createPair(
        address token0,
        address token1
    ) external returns (address pair) {
        require(token0 != token1, 'IDENTICAL_ADDRESSES');
        require(token0 != address(0), 'ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'PAIR_EXISTS'); // single check is sufficient
        require(
            ISettingExchange(settingExchange).allowlistAddressToken1(token1),
            'AddressToken1 not in allowlist'
        );
        require(
            ISettingExchange(settingExchange).testERC20Token(token0),
            'this address not erc20'
        );

        bytes32 _salt = keccak256(abi.encodePacked(token0, token1));
        Pair newPair = new Pair{salt: _salt}(
            token0,
            token1,
            mainValueWallet,
            settingExchange,
            feeController
        );
        require(address(newPair) != address(0), 'Fail_Create');
        getPair[token0][token1] = address(newPair);
        getPair[token1][token0] = address(newPair); // populate mapping in the reverse direction
        allPairs.push(address(newPair));

        // add token in settingExchange for check deposit/withdrawn allowlist in Prism exchange
        ISettingExchange(settingExchange).setAddressToken(token0);
        ISettingExchange(settingExchange).setAddressToken(token1);

        emit PairCreated(token0, token1, address(newPair), allPairs.length);
        return address(newPair);
    }
}
