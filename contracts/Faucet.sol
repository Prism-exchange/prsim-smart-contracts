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

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract Faucet is Ownable {
    IERC20 public token0;
    IERC20 public token1;
    IERC20 public token2;
    IERC20 public token3;

    mapping(address => uint256) public timeFaucet;

    uint256 public lockhourPeriods;
    uint256 public amount0;
    uint256 public amount1;
    uint256 public amount2;
    uint256 public amount3;
    bool public isOpen;

    modifier onlyOpen() {
        require(isOpen, 'Facuet Close');
        _;
    }

    constructor(
        address _token0,
        address _token1,
        address _token2,
        address _token3,
        uint256 _amount0,
        uint256 _amount1,
        uint256 _amount2,
        uint256 _amount3,
        uint256 _lockhourPeriods
    ) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        token2 = IERC20(_token2);
        token3 = IERC20(_token3);
        lockhourPeriods = _lockhourPeriods;
        amount0 = _amount0;
        amount1 = _amount1;
        amount2 = _amount2;
        amount3 = _amount3;
        isOpen = true;
    }

    function changeTimeFaucet(
        address user,
        uint256 newTime
    ) external onlyOwner {
        timeFaucet[user] = newTime;
    }

    function changeLockHourPeriods(
        uint256 _newlockhourPeriods
    ) external onlyOwner {
        lockhourPeriods = _newlockhourPeriods;
    }

    function changeAmountToken(
        uint256 _amount0,
        uint256 _amount1,
        uint256 _amount2,
        uint256 _amount3
    ) external onlyOwner {
        amount0 = _amount0;
        amount1 = _amount1;
        amount2 = _amount2;
        amount3 = _amount3;
    }

    function changeToken(
        address _token0,
        address _token1,
        address _token2,
        address _token3
    ) external onlyOwner {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        token2 = IERC20(_token2);
        token3 = IERC20(_token3);
    }

    function togleOpen() external onlyOwner {
        isOpen = !isOpen;
    }

    function withdrawToken(address _token) external onlyOwner {
        IERC20(_token).transfer(
            owner(),
            IERC20(_token).balanceOf(address(this))
        );
    }

    function getFaucet() external onlyOpen {
        if (timeFaucet[msg.sender] == 0) {
            timeFaucet[msg.sender] = block.timestamp;
        }
        require(
            timeFaucet[msg.sender] <= block.timestamp,
            'It is not time please wait'
        );
        timeFaucet[msg.sender] = block.timestamp + (60 * 60 * lockhourPeriods);
        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);
        token2.transfer(msg.sender, amount2);
        token3.transfer(msg.sender, amount3);
    }
}
