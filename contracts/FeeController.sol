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

import './interface/IFactoryPair.sol';
import './interface/IMainValueWallet.sol';
import './interface/IPair.sol';
import './interface/ISettingExchange.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract FeeController is Ownable {
    //=======================================
    //========= State Variables =============
    //=======================================

    IFactoryPair public factoryPair;
    IMainValueWallet public mainValueWallet;
    ISettingExchange public settingExchange;

    mapping(address => mapping(uint8 => mapping(uint256 => uint256)))
        public finishAt;

    mapping(address => mapping(uint8 => mapping(uint256 => uint256)))
        public updatedAt;

    mapping(address => mapping(uint8 => mapping(uint256 => uint256)))
        public rewardRate;

    mapping(address => mapping(uint8 => mapping(uint256 => uint256)))
        public rewardPerTokenStored;

    mapping(address => mapping(uint8 => mapping(uint256 => mapping(address => uint256))))
        public userRewardPerTokenPaid;

    mapping(address => mapping(uint8 => mapping(uint256 => mapping(address => uint256))))
        public rewards;

    mapping(address => mapping(uint8 => mapping(uint256 => uint256)))
        public totalSupply;

    mapping(address => mapping(uint8 => mapping(uint256 => mapping(address => uint256))))
        public balanceOf;

    mapping(address => uint256) public currentTickFee;

    mapping(address => mapping(uint256 => TickFee)) public infoTickFee;

    mapping(address => mapping(uint8 => mapping(uint256 => mapping(address => bool))))
        public defaultOwnerStake;

    struct TickFee {
        uint256 upperTickPrice;
        uint256 lowerTickPrice;
    }

    constructor(address _mainValueWallet, address _settingExchange) {
        mainValueWallet = IMainValueWallet(_mainValueWallet);
        settingExchange = ISettingExchange(_settingExchange);
    }

    //=======================================
    //=============== modifier  =============
    //=======================================

    modifier validCaller(address _pair) {
        require(
            factoryPair.getPair(
                IPair(_pair).token0(),
                IPair(_pair).token1()
            ) == msg.sender,
            'invalid caller'
        );
        _;
    }

    //=======================================
    //================ Functions ============
    //=======================================

    function createPosition(
        uint256 _amount,
        uint256 _price,
        address _user,
        address _pair,
        uint8 _isBuy,
        uint256 tickFeeID,
        bool craeteTickFeeID
    ) external validCaller(_pair) returns (uint256) {
        _updateReward(_user, _pair, _isBuy, tickFeeID);
        require(_amount > 0, 'amount = 0');
        uint256 _currentTickFee = currentTickFee[_pair];
        if (_currentTickFee == 0) {
            // First time no price yet
            tickFeeID = 0;
        } else {
            if (craeteTickFeeID) {
                tickFeeID = _updateTickFee(_pair, _price, false);
            }
            require(
                _verifyTickFee(_pair, _price, tickFeeID),
                'tickFeeID not correct'
            );
        }
        totalSupply[_pair][_isBuy][tickFeeID] += _amount;
        balanceOf[_pair][_isBuy][tickFeeID][_user] += _amount;

        // default set feeController stake 1
        address feeController = settingExchange.FeeCollector();
        if (!defaultOwnerStake[_pair][_isBuy][tickFeeID][feeController]) {
            defaultOwnerStake[_pair][_isBuy][tickFeeID][feeController] = true;
            totalSupply[_pair][_isBuy][tickFeeID] += 1;
            balanceOf[_pair][_isBuy][tickFeeID][feeController] += 1;
        }
        emit Staked(_pair, _amount, _user, _isBuy);
        return tickFeeID;
    }

    function withdrawnPosition(
        uint256 _amount,
        address _user,
        address _pair,
        uint8 _isBuy,
        uint256 tickFeeID
    ) external validCaller(_pair) {
        _updateReward(_user, _pair, _isBuy, tickFeeID);
        require(_amount > 0, 'amount = 0');
        require(
            balanceOf[_pair][_isBuy][tickFeeID][_user] >= _amount,
            'balance insufficient'
        );
        balanceOf[_pair][_isBuy][tickFeeID][_user] -= _amount;
        totalSupply[_pair][_isBuy][tickFeeID] -= _amount;
        emit Withdrawn(msg.sender, _amount, _user, _isBuy);
    }

    function claimFee(address _pair, uint8 _isBuy, uint256 tickFeeID) external {
        require(_isBuy <= 1, 'invalid input isBuy');
        _updateReward(msg.sender, _pair, _isBuy, tickFeeID);
        uint256 reward = rewards[_pair][_isBuy][tickFeeID][msg.sender];
        require(reward > 0, 'reward = 0');
        address addressReward = getAddressReward(_pair, _isBuy);
        rewards[_pair][_isBuy][tickFeeID][msg.sender] = 0;

        mainValueWallet.decreaseBalancesSpotFee(
            reward,
            address(this),
            addressReward
        );
        mainValueWallet.increaseBalancesSpotFee(
            reward,
            msg.sender,
            addressReward
        );
        // rewardsToken.safeTransfer(msg.sender, reward);
        emit ClaimFee(msg.sender, reward, msg.sender, _isBuy);
    }

    function collectFeeReward(
        address _pair,
        uint256[2] calldata _amount,
        uint8[2] calldata _isBuy
    ) external validCaller(_pair) {
        uint256 tickFeeID = currentTickFee[_pair];
        if (tickFeeID == 0) {
            // First time
            tickFeeID = 2 ** 256 / 2;
            currentTickFee[_pair] = tickFeeID;
            uint256 currentPrice = IPair(_pair).price();
            infoTickFee[_pair][tickFeeID] = TickFee(
                (currentPrice * 105) / 100, // 5% up from current price
                (currentPrice * 95) / 100 // 5% down from current price
            );
        } else {
            _updateTickFee(_pair, IPair(_pair).price(), true);
        }
        _updateReward(address(0), _pair, _isBuy[0], tickFeeID);
        _updateReward(address(0), _pair, _isBuy[1], tickFeeID);

        uint256 duration = settingExchange.durationPaidFee();

        for (uint256 i = 0; i < _amount.length; i++) {
            if (block.timestamp >= finishAt[_pair][_isBuy[i]][tickFeeID]) {
                rewardRate[_pair][_isBuy[i]][tickFeeID] = _amount[i] / duration;
            } else {
                uint256 remainingRewards = (finishAt[_pair][_isBuy[i]][
                    tickFeeID
                ] - block.timestamp) * rewardRate[_pair][_isBuy[i]][tickFeeID];
                rewardRate[_pair][_isBuy[i]][tickFeeID] =
                    (_amount[i] + remainingRewards) /
                    duration;
            }

            require(
                rewardRate[_pair][_isBuy[i]][tickFeeID] > 0,
                'reward rate = 0'
            );
            require(
                rewardRate[_pair][_isBuy[i]][tickFeeID] * duration <=
                    mainValueWallet.balancesSpot(
                        address(this),
                        getAddressReward(_pair, _isBuy[i])
                    ),
                'reward amount > balance'
            );

            finishAt[_pair][_isBuy[i]][tickFeeID] = block.timestamp + duration;
            updatedAt[_pair][_isBuy[i]][tickFeeID] = block.timestamp;

            emit CollectFeeReward(_amount[i], _pair, _isBuy[i]);
        }
    }

    function _updateReward(
        address _account,
        address _pair,
        uint8 _isBuy,
        uint256 tickFeeID
    ) internal {
        rewardPerTokenStored[_pair][_isBuy][tickFeeID] = rewardPerToken(
            _pair,
            _isBuy,
            tickFeeID
        );
        updatedAt[_pair][_isBuy][tickFeeID] = lastTimeRewardApplicable(
            _pair,
            _isBuy,
            tickFeeID
        );

        if (_account != address(0)) {
            rewards[_pair][_isBuy][tickFeeID][_account] = earned(
                _account,
                _pair,
                _isBuy,
                tickFeeID
            );
            userRewardPerTokenPaid[_pair][_isBuy][tickFeeID][
                _account
            ] = rewardPerTokenStored[_pair][_isBuy][tickFeeID];
        }
    }

    function _updateTickFee(
        address _pair,
        uint256 _price,
        bool updateCurrentTickFee
    ) internal returns (uint256) {
        uint256 tickFeeID = currentTickFee[_pair];
        TickFee memory tickFee = infoTickFee[_pair][tickFeeID];
        // out of range fee
        while (
            tickFee.upperTickPrice < _price || _price < tickFee.lowerTickPrice
        ) {
            // up
            if (_price > tickFee.upperTickPrice) {
                tickFeeID++;
                TickFee memory tempTickFee = infoTickFee[_pair][tickFeeID];
                // check first time tickFee
                if (
                    tempTickFee.upperTickPrice == 0 &&
                    tempTickFee.lowerTickPrice == 0
                ) {
                    //  First time tickFee
                    infoTickFee[_pair][tickFeeID] = TickFee(
                        (tickFee.upperTickPrice * 110) / 100, // 5% up from current price
                        tickFee.upperTickPrice // 5% down from current price
                    );
                }
                // down
            } else if (_price < tickFee.lowerTickPrice) {
                tickFeeID--;
                TickFee memory tempTickFee = infoTickFee[_pair][tickFeeID];
                // check first time tickFee
                if (
                    tempTickFee.upperTickPrice == 0 &&
                    tempTickFee.lowerTickPrice == 0
                ) {
                    //  First time tickFee
                    infoTickFee[_pair][tickFeeID] = TickFee(
                        tickFee.lowerTickPrice, // 5% up from current price
                        (tickFee.lowerTickPrice * 100) / 110 // 5% down from current price
                    );
                }
            }

            tickFee = infoTickFee[_pair][tickFeeID];
        }
        if (updateCurrentTickFee) {
            currentTickFee[_pair] = tickFeeID;
        }
        return tickFeeID;
    }

    //=======================================
    //=========== View Functions ============
    //=======================================

    function findTickFeeByPrice(
        address _pair,
        uint256 _price
    ) public view returns (bool, uint256) {
        require(_price > 0, 'price = 0');
        uint256 tickFeeID = currentTickFee[_pair];
        TickFee memory tickFee = infoTickFee[_pair][tickFeeID];

        while (
            tickFee.upperTickPrice < _price || _price < tickFee.lowerTickPrice
        ) {
            // up
            if (_price > tickFee.upperTickPrice) {
                tickFeeID++;
                // down
            } else if (_price < tickFee.lowerTickPrice) {
                tickFeeID--;
            }

            tickFee = infoTickFee[_pair][tickFeeID];
            if (tickFee.upperTickPrice == 0 && tickFee.lowerTickPrice == 0) {
                // not create yet
                return (false, tickFeeID);
            }
        }
        return (true, tickFeeID);
    }

    function _verifyTickFee(
        address _pair,
        uint256 _price,
        uint256 tickFeeID
    ) private view returns (bool) {
        TickFee memory tickFee = infoTickFee[_pair][tickFeeID];
        return (tickFee.upperTickPrice >= _price &&
            tickFee.lowerTickPrice <= _price);
    }

    function getAddressReward(
        address _pair,
        uint8 _isBuy
    ) private view returns (address) {
        return
            _isBuy == 0
                ? IPair(_pair).token0()
                : IPair(_pair).token1();
    }

    function lastTimeRewardApplicable(
        address _pair,
        uint8 _isBuy,
        uint256 tickFeeID
    ) public view returns (uint256) {
        return _min(finishAt[_pair][_isBuy][tickFeeID], block.timestamp);
    }

    function rewardPerToken(
        address _pair,
        uint8 _isBuy,
        uint256 tickFeeID
    ) public view returns (uint256) {
        if (totalSupply[_pair][_isBuy][tickFeeID] == 0) {
            return rewardPerTokenStored[_pair][_isBuy][tickFeeID];
        }

        return
            rewardPerTokenStored[_pair][_isBuy][tickFeeID] +
            (rewardRate[_pair][_isBuy][tickFeeID] *
                (lastTimeRewardApplicable(_pair, _isBuy, tickFeeID) -
                    updatedAt[_pair][_isBuy][tickFeeID]) *
                1e18) /
            totalSupply[_pair][_isBuy][tickFeeID];
    }

    function earned(
        address _account,
        address _pair,
        uint8 _isBuy,
        uint256 tickFeeID
    ) public view returns (uint256) {
        return
            ((balanceOf[_pair][_isBuy][tickFeeID][_account] *
                (rewardPerToken(_pair, _isBuy, tickFeeID) -
                    userRewardPerTokenPaid[_pair][_isBuy][tickFeeID][
                        _account
                    ])) / 1e18) + rewards[_pair][_isBuy][tickFeeID][_account];
    }

    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x <= y ? x : y;
    }

    function setFactoryPair(address _factoryPair) public onlyOwner {
        factoryPair = IFactoryPair(_factoryPair);
    }

    /* ========== EVENTS ========== */

    event CollectFeeReward(uint256 reward, address pair, uint8 isBuy);
    event Staked(
        address indexed user,
        uint256 amount,
        address pair,
        uint8 isBuy
    );
    event Withdrawn(
        address indexed user,
        uint256 amount,
        address pair,
        uint8 isBuy
    );
    event ClaimFee(
        address indexed user,
        uint256 reward,
        address pair,
        uint8 isBuy
    );
}
