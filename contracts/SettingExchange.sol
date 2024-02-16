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
import './interface/IMainValueWallet.sol';
import './interface/IFactoryPair.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';

contract SettingExchange is Ownable {
    IFactoryPair public factoryPair;

    mapping(address => bool) public allowlistAddressToken1;
    address[] public allAllowlistAddressToken1;

    mapping(address => bool) public isSaveAddressToken;
    address[] public allAddressToken;

    address public FeeCollector;

    uint256 public Fee; // 10,000 = 100%

    uint256 public platformFee;
    uint256 public userFee;

    // Duration of rewards to be paid out (in seconds)
    uint256 public durationPaidFee;

    mapping(address => uint256) public minAmountToken0;
    mapping(address => uint256) public minAmountToken1;

    modifier validCaller() {
        require(address(factoryPair) == msg.sender, 'invalid caller');
        _;
    }

    constructor(address _FeeCollector) {
        Fee = 10; // 10 = 0.1% , 100 = 1%
        FeeCollector = _FeeCollector;
        platformFee = 30;
        userFee = 70;
    }

    function setFactoryPair(address _factoryPair) public onlyOwner {
        factoryPair = IFactoryPair(_factoryPair);
    }

    function allAddressTokenLength() external view returns (uint) {
        return allAddressToken.length;
    }

    function setAddressToken(address token) external validCaller {
        // if not set yet
        if (!isSaveAddressToken[token]) {
            isSaveAddressToken[token] = true;
            allAddressToken.push(token);
        }
    }

    function allAllowlistAddressToken1Length() external view returns (uint) {
        return allAllowlistAddressToken1.length;
    }

    function addAllowlistAddressToken1(address token1) external onlyOwner {
        require(!allowlistAddressToken1[token1], 'Already_ADD');
        allowlistAddressToken1[token1] = true;
        allAllowlistAddressToken1.push(token1);
    }

    function removeAllowlistAddressToken1(uint256 index) external onlyOwner {
        address token1 = allAllowlistAddressToken1[index];
        uint256 length = allAllowlistAddressToken1.length;
        require(allowlistAddressToken1[token1], 'Not_ADD');
        allowlistAddressToken1[token1] = false;
        allAllowlistAddressToken1[index] = allAllowlistAddressToken1[
            length - 1
        ];
        allAllowlistAddressToken1.pop();
    }

    function changeFeeCollector(address newFeeCollector) external onlyOwner {
        FeeCollector = newFeeCollector;
    }

    function changeMinAmountToken0(
        address PairOrder,
        uint256 newAmountToken0
    ) external onlyOwner {
        minAmountToken0[PairOrder] = newAmountToken0;
    }

    function changeMinAmountToken1(
        address PairOrder,
        uint256 newAmountToken1
    ) external onlyOwner {
        minAmountToken1[PairOrder] = newAmountToken1;
    }

    function changeFee(uint256 newFee) external onlyOwner {
        require(newFee <= 100); // Fee must <= 1%
        Fee = newFee;
    }

    function setDurationPaidFee(uint256 _durationPaidFee) external onlyOwner {
        require(_durationPaidFee <= 7 days);
        durationPaidFee = _durationPaidFee;
    }

    function setPlatformAndUserFee(
        uint256 _platformFee,
        uint256 _userFee
    ) external onlyOwner {
        require(_platformFee + _userFee == 100);
        platformFee = _platformFee;
        userFee = _userFee;
    }

    function testERC20Token(address token) external view returns (bool) {
        uint size;
        assembly {
            size := extcodesize(token)
        }
        require(size > 0, 'this address not contract');
        try IERC20Metadata(token).symbol() {} catch {
            revert('this address not erc20');
        }
        try IERC20Metadata(token).decimals() {} catch {
            revert('this address not erc20');
        }
        try IERC20Metadata(token).totalSupply() {} catch {
            revert('this address not erc20');
        }
        try IERC20Metadata(token).balanceOf(address(this)) {} catch {
            revert('this address not erc20');
        }
        return true;
    }
}
