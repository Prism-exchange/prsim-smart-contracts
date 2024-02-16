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
import './interface/IERC20.sol';
import './interface/ISettingExchange.sol';
import './interface/IFeeController.sol';
import './interface/IBlast.sol';    // Blast Native Yield

/**
 * @title Pair
 * @author Prism exchange
 * @dev This contract is used to manage limit order system in Prism exchange for their pair ( limit order data structure: linked list )
 */
contract Pair {

    //=======================================
    //========= State Variables =============
    //=======================================

    // Blast Native Yield
    IBlast public constant BLAST = IBlast(0x4300000000000000000000000000000000000002);

    struct Order {
        uint256 id;
        address trader;
        uint8 isBuy;
        uint256 createdDate;
        address token;
        uint256 amount;
        uint256 price;
        uint256 filled;
        uint256 nextNodeID;
        uint256 tickFeeID;
    }

    struct InfoMarketOrder {
        uint256 feeTokenMain;
        uint256 feeTokenSecondary;
        uint256 filledSender;
        uint256 costSender;
        uint256 averagePrice;
        uint256 totalFilled;
        address tokenMain;
        address tokenSecondary;
        uint8 isBuy;
        uint8 decimals;
        uint256 currentNodeID;
        uint256 exchangeFee;
        address feeCollector;
    }

    struct InfoCreateLimitOrder {
        address tokenMain;
        uint8 decimals;
        uint256 tempAmount;
    }

    IMainValueWallet public mainValueWallet;
    ISettingExchange public settingExchange;
    IFeeController public feeController;

    // Mapping from uint8 (Buy = 0) or (Sell = 1)  => nodeID => Order
    mapping(uint8 => mapping(uint256 => Order)) linkedListsNode;

    // Mapping from uint8 (Buy = 0) or (Sell = 1)  => listSizeNode
    mapping(uint8 => uint256) public listSize;

    // Mapping from uint8 (Buy = 0) or (Sell = 1)  => current nodeID
    mapping(uint8 => uint256) nodeID;

    uint256 immutable GUARDHEAD = 0;
    uint256 immutable GUARDTAIL = 2 ** 256 - 1; // max uint256

    uint256 public price;

    address public token0;
    address public token1;

    //=======================================
    //=============== Events ================
    //=======================================

    event CreateLimitOrder(
        address indexed pair,
        address indexed trader,
        uint8 isBuy,
        uint256 amount,
        uint256 price,
        uint256 date
    );
    event SumMarketOrder(
        address indexed pair,
        address indexed trader,
        uint8 isBuy,
        uint256 amount,
        uint256 price,
        uint256 executed,
        uint256 fee,
        uint256 date
    );
    event RemoveOrder(
        address indexed pair,
        address indexed trader,
        uint8 isBuy,
        uint256 amount,
        uint256 price,
        uint256 executed,
        uint256 fee,
        uint256 date
    );
    event RemoveOrderNoUpdateBalances(
        address indexed pair,
        address indexed trader,
        uint8 isBuy,
        uint256 amount,
        uint256 price,
        uint256 executed,
        uint256 fee,
        uint256 date
    );
    event MarketOrder(
        address indexed pair,
        address indexed trader,
        uint8 isBuy,
        uint256 amount,
        uint256 price,
        uint256 fee,
        uint256 date
    );

    /**
     * @dev Constructor function that initializes address token0,token1,mainValueWallet,historyOrder,settingExchange
     * and initializes state variables nodeID,linkedListsNode
     * @param _token0 - The address of the token0
     * @param _token1 - The address of the token1
     * @param _mainValueWallet - The address of the mainValueWallet
     * @param _settingExchange - The address of the settingExchange
     */
    constructor(
        address _token0,
        address _token1,
        address _mainValueWallet,
        address _settingExchange,
        address _feeController
    ) {
        token0 = _token0;
        token1 = _token1;
        mainValueWallet = IMainValueWallet(_mainValueWallet);
        settingExchange = ISettingExchange(_settingExchange);
        feeController = IFeeController(_feeController);

        nodeID[0] = 1;
        nodeID[1] = 1;
        linkedListsNode[0][0].nextNodeID = 2 ** 256 - 1; // max uint256
        linkedListsNode[1][0].nextNodeID = 2 ** 256 - 1; // max uint256

        // Blast Native Yield
        BLAST.configureClaimableGas();
        BLAST.configureGovernor(_feeController);
    }

    //=============================================================
    //=====================  Function (modifier) ==================
    //=============================================================

    function checkInputIsBuy(uint8 _isBuy) private pure {
        require(_isBuy <= 1, 'invalid input isBuy');
    }

    function checkIsPrev(
        uint8 _isBuy,
        uint256 index,
        uint256 prevIndex
    ) private view {
        require(_isPrev(_isBuy, index, prevIndex), 'not prevIndex');
    }

    function checklinkedListsExist(uint8 _isBuy, uint256 index) private view {
        require(
            linkedListsNode[_isBuy][index].nextNodeID != 0,
            'index not exist'
        );
    }

    function checkBalances(address _token, uint256 _amount) private view {
        require(
            mainValueWallet.balancesSpot(msg.sender, _token) >= _amount,
            'insufficient balance'
        );
    }

    function checkVerifyIndexOrder(
        uint256 prevNodeID,
        uint256 _price,
        uint8 _isBuy,
        uint256 nextNodeID
    ) private view {
        require(
            _verifyIndex(prevNodeID, _price, _isBuy, nextNodeID),
            'position in linked list not order'
        );
    }

    function checkUintZero(uint256 number) private pure {
        require(number > 0, 'Zero');
    }

    function checkOwnerOrder(uint8 _isBuy, uint256 index) private view {
        require(
            linkedListsNode[_isBuy][index].trader == msg.sender,
            'not owner this order'
        );
    }

    function checkInputMinAmountToken0(uint256 _amount) private view {
        require(
            _amount >= settingExchange.minAmountToken0(address(this)),
            'min amount token0'
        );
    }

    function checkInputMinAmountToken1(uint256 _amount) private view {
        require(
            _amount >= settingExchange.minAmountToken1(address(this)),
            'min amount token1'
        );
    }


    //=======================================
    //============ Functions ================
    //=======================================

    ////////////////////////////////////// CreateLimitOrder //////////////////////////////////////
    /**
     * @dev Function used to create limit order in Prism exchange
     * @param _isBuy - The number isBuy (  0 = Buy , 1 = Sell )
     * @param _amount - The amount of token order
     * @param _price - The price of order
     * @param prevNodeID - The node id of the previous node
     * @param tickFeeID - The tickFeeID for create position fee
     * @param forceCreate -  The boolean of force create limit order
     */
    function createLimitOrder(
        uint8 _isBuy,
        uint256 _amount,
        uint256 _price,
        uint256 prevNodeID,
        uint256 tickFeeID,
        bool forceCreate
    ) public {
        checkInputIsBuy(_isBuy);
        checkUintZero(_price);
        checkUintZero(_amount);
        if (forceCreate) {
            (, prevNodeID) = _findIndex(_price, _isBuy, 0, listSize[_isBuy]);
        }
        checklinkedListsExist(_isBuy, prevNodeID);
        checkVerifyIndexOrder(
            prevNodeID,
            _price,
            _isBuy,
            linkedListsNode[_isBuy][prevNodeID].nextNodeID
        );

        InfoCreateLimitOrder memory infoCreateLimitOrder = InfoCreateLimitOrder(
            address(0),
            0,
            0
        );

        {
            address _tokenMain = _isBuy == 0 ? token1 : token0;
            uint8 _decimals = IERC20(_tokenMain).decimals();
            infoCreateLimitOrder.tokenMain = _tokenMain;
            infoCreateLimitOrder.decimals = _decimals;
        }

        // checkInputMinAmountToken0(_amount);
        checkInputMinAmountToken1(
            (_amount * _price) / (10 ** infoCreateLimitOrder.decimals)
        );

        // try to market order first
        if (_isBuy == 0) {
            infoCreateLimitOrder.tempAmount =
                (_amount * _price) /
                10 ** infoCreateLimitOrder.decimals;
            checkBalances(
                infoCreateLimitOrder.tokenMain,
                infoCreateLimitOrder.tempAmount
            );
            _amount = createMarketOrder(
                _isBuy,
                infoCreateLimitOrder.tempAmount,
                _price
            );
            _amount = (_amount * 10 ** infoCreateLimitOrder.decimals) / _price;
            infoCreateLimitOrder.tempAmount =
                (_amount * _price) /
                10 ** infoCreateLimitOrder.decimals;
        } else {
            infoCreateLimitOrder.tempAmount = _amount;
            checkBalances(
                infoCreateLimitOrder.tokenMain,
                infoCreateLimitOrder.tempAmount
            );
            _amount = createMarketOrder(
                _isBuy,
                infoCreateLimitOrder.tempAmount,
                _price
            );
            infoCreateLimitOrder.tempAmount = _amount;
        }
        if (_amount <= 0) return; // fulfill after market order

        // After market order there is still fund left then create a limit order

        // transfer balance Spot to Trade wallet
        _decreaseBalancesSpot(
            infoCreateLimitOrder.tempAmount,
            msg.sender,
            infoCreateLimitOrder.tokenMain,
            token0,
            token1
        );
        _increaseBalancesTrade(
            infoCreateLimitOrder.tempAmount,
            msg.sender,
            infoCreateLimitOrder.tokenMain,
            token0,
            token1
        );

        linkedListsNode[_isBuy][nodeID[_isBuy]] = Order(
            nodeID[_isBuy],
            msg.sender,
            _isBuy,
            block.timestamp,
            infoCreateLimitOrder.tokenMain,
            _amount,
            _price,
            0,
            linkedListsNode[_isBuy][prevNodeID].nextNodeID,
            // createPosition fee and return tickFeeID
            feeController.createPosition(
                infoCreateLimitOrder.tempAmount,
                _price,
                msg.sender,
                address(this),
                _isBuy,
                tickFeeID,
                forceCreate
            )
        );

        linkedListsNode[_isBuy][prevNodeID].nextNodeID = nodeID[_isBuy];
        listSize[_isBuy]++;
        nodeID[_isBuy]++;

        emit CreateLimitOrder(
            address(this),
            msg.sender,
            _isBuy,
            _amount,
            _price,
            block.timestamp
        );
    }

    ////////////////////////////////////// Check pre_price > new_price > next_price //////////////////////////////////////
    /**
     * @dev Function used to check the positions in the linked lists to make sure they are in order
     * @param prevNodeID - The node id of the previous node
     * @param _price - The price of order
     * @param _isBuy - The number isBuy (  0 = Buy , 1 = Sell )
     * @param nextNodeID - The node id of the next node
     * @return bool - The boolean of confirm that the node id location that is input according to prevNodeID,price,nextNodeID is make  linked lists in order
     */
    function _verifyIndex(
        uint256 prevNodeID,
        uint256 _price,
        uint8 _isBuy,
        uint256 nextNodeID
    ) private view returns (bool) {
        if (_isBuy == 0) {
            return
                (prevNodeID == GUARDHEAD ||
                    linkedListsNode[0][prevNodeID].price >= _price) &&
                (nextNodeID == GUARDTAIL ||
                    _price > linkedListsNode[0][nextNodeID].price);
        } else {
            return
                (prevNodeID == GUARDHEAD ||
                    linkedListsNode[1][prevNodeID].price <= _price) &&
                (nextNodeID == GUARDTAIL ||
                    _price < linkedListsNode[1][nextNodeID].price);
        }
    }

    ////////////////////////////////////// Find index makes linked list order  //////////////////////////////////////
    /**
     * @dev Function used to find the correct index node id position in linked lists that  makes  linked lists in order by price
     * @param _price - The price of order
     * @param _isBuy - The number isBuy (  0 = Buy , 1 = Sell )
     * @param startIndex - The node id  at start to find
     * @param lengthToFind - The length to find
     * @return bool - The boolean that tells whether the location can be found or not
     * @return uint256 - The currentNodeID is most recent position of the node id at the end of the search
     */
    function _findIndex(
        uint256 _price,
        uint8 _isBuy,
        uint256 startIndex,
        uint256 lengthToFind
    ) public view returns (bool, uint256) {
        checkInputIsBuy(_isBuy);
        checkUintZero(_price);
        uint256 currentNodeID = startIndex == 0 ? GUARDHEAD : startIndex;
        uint256 countFind = 0;
        while (
            linkedListsNode[_isBuy][currentNodeID].id != GUARDTAIL &&
            countFind < lengthToFind
        ) {
            if (
                _verifyIndex(
                    currentNodeID,
                    _price,
                    _isBuy,
                    linkedListsNode[_isBuy][currentNodeID].nextNodeID
                )
            ) return (true, currentNodeID);
            currentNodeID = linkedListsNode[_isBuy][currentNodeID].nextNodeID;
            countFind++;
        }
        return (false, currentNodeID);
    }

    ////////////////////////////////////// Get OrderBook //////////////////////////////////////
    /**
     * @dev Function used to retrieve order information in Prism exchange
     * @param _isBuy - The number isBuy ( 0 = Buy , 1 = Sell )
     * @param startIndex - The node id  at start to find
     * @param lengthToFind - The length to find
     * @return order[] - The list order in Prism exchange
     * @return uint256 - The currentNodeID is most recent position of the node id at the end of the search
     */
    function getOrderBook(
        uint8 _isBuy,
        uint256 startIndex,
        uint256 lengthToFind
    ) external view returns (Order[] memory, uint256) {
        checkInputIsBuy(_isBuy);
        Order[] memory dataList = new Order[](lengthToFind);
        uint256 countFind = 0;
        uint256 currentNodeID = startIndex == 0
            ? linkedListsNode[_isBuy][GUARDHEAD].nextNodeID
            : startIndex;
        while (
            linkedListsNode[_isBuy][currentNodeID].id != GUARDTAIL &&
            countFind < lengthToFind
        ) {
            dataList[countFind] = linkedListsNode[_isBuy][currentNodeID];
            currentNodeID = linkedListsNode[_isBuy][currentNodeID].nextNodeID;
            countFind++;
        }
        return (dataList, currentNodeID);
    }

    ////////////////////////////////////// Remove Limit Order   //////////////////////////////////////
    /**
     * @dev Function used to remove order in Prism exchange
     * @param _isBuy - The number isBuy (  0 = Buy , 1 = Sell )
     * @param index - The node id that want to remove
     * @param prevIndex - The node id of the previous node
     * @param forceCreate -  The boolean of force create limit order
     */
    function removeOrder(
        uint8 _isBuy,
        uint256 index,
        uint256 prevIndex,
        bool forceCreate
    ) public {
        checkInputIsBuy(_isBuy);
        checkOwnerOrder(_isBuy, index);
        checklinkedListsExist(_isBuy, index);
        if (forceCreate) {
            (, prevIndex) = _findPrevOrder(_isBuy, 0, index, listSize[_isBuy]);
        }
        checkIsPrev(_isBuy, index, prevIndex);

        Order memory tempOrder = linkedListsNode[_isBuy][index];

        uint8 decimals = IERC20(tempOrder.token).decimals();
        uint256 tempAmount;
        if (_isBuy == 0) {
            tempAmount =
                ((tempOrder.amount - tempOrder.filled) * tempOrder.price) /
                10 ** decimals;
        } else {
            tempAmount = (tempOrder.amount - tempOrder.filled);
        }
        // transfer balance Trade to Spot wallet
        _increaseBalancesSpot(
            tempAmount,
            msg.sender,
            tempOrder.token,
            token0,
            token1
        );

        _decreaseBalancesTrade(
            tempAmount,
            msg.sender,
            tempOrder.token,
            token0,
            token1
        );

        // withdrawnPosition fee
        feeController.withdrawnPosition(
            tempAmount,
            tempOrder.trader,
            address(this),
            tempOrder.isBuy,
            tempOrder.tickFeeID
        );

        linkedListsNode[_isBuy][prevIndex].nextNodeID = linkedListsNode[_isBuy][
            index
        ].nextNodeID;
        linkedListsNode[_isBuy][index].nextNodeID = 0;
        listSize[_isBuy]--;

        emit RemoveOrder(
            address(this),
            tempOrder.trader,
            tempOrder.isBuy,
            tempOrder.amount,
            tempOrder.price,
            tempOrder.filled,
            settingExchange.userFee(),
            block.timestamp
        );
    }

    /**
     * @dev Function used to remove order in Prism exchange but it will not update any balance variables just remove it (Can Only use from MarketOrder )
     * @param _isBuy - The number isBuy (  0 = Buy , 1 = Sell )
     * @param index - The node id that want to remove
     * @param prevIndex - The node id of the previous node
     */
    function removeOrderNoUpdateBalances(
        uint8 _isBuy,
        uint256 index,
        uint256 prevIndex
    ) private {
        checklinkedListsExist(_isBuy, index);
        checkIsPrev(_isBuy, index, prevIndex);

        Order memory tempOrder = linkedListsNode[_isBuy][index];

        uint8 decimals = IERC20(tempOrder.token).decimals();
        uint256 tempAmount;
        if (_isBuy == 0) {
            tempAmount = (tempOrder.amount * tempOrder.price) / 10 ** decimals;
        } else {
            tempAmount = tempOrder.amount;
        }

        linkedListsNode[_isBuy][prevIndex].nextNodeID = linkedListsNode[_isBuy][
            index
        ].nextNodeID;
        linkedListsNode[_isBuy][index].nextNodeID = 0;
        listSize[_isBuy]--;

        // withdrawnPosition fee
        feeController.withdrawnPosition(
            tempAmount,
            tempOrder.trader,
            address(this),
            tempOrder.isBuy,
            tempOrder.tickFeeID
        );

        emit RemoveOrderNoUpdateBalances(
            address(this),
            tempOrder.trader,
            tempOrder.isBuy,
            tempOrder.amount,
            tempOrder.price,
            tempOrder.filled,
            settingExchange.userFee(),
            tempOrder.createdDate
        );
    }

    ////////////////////////////////////// Check isPrev index //////////////////////////////////////
    /**
     * @dev Function used to check if the currentNodeID is before prevNodeID
     * @param _isBuy - The number isBuy (  0 = Buy , 1 = Sell )
     * @param currentNodeID - The currentNodeID is node id you want to check
     * @param prevNodeID - The node id of the previous node
     * @return bool - The boolean of check if the currentNodeID is before prevNodeID
     */
    function _isPrev(
        uint8 _isBuy,
        uint256 currentNodeID,
        uint256 prevNodeID
    ) private view returns (bool) {
        checklinkedListsExist(_isBuy, prevNodeID);
        return linkedListsNode[_isBuy][prevNodeID].nextNodeID == currentNodeID;
    }

    //////////////////////////////////////         Find PrevOrder index    //////////////////////////////////////
    /**
     * @dev Function used to find the previous index node id by targetIndex
     * @param _isBuy - The number isBuy (  0 = Buy , 1 = Sell )
     * @param startIndex - The node id  at start to find
     * @param targetIndex - The target to find previous index node id
     * @param lengthToFind - The length to find
     * @return bool - The boolean that tells whether the location can be found or not
     * @return uint256 - The currentNodeID is most recent position of the node id at the end of the search
     */
    function _findPrevOrder(
        uint8 _isBuy,
        uint256 startIndex,
        uint256 targetIndex,
        uint256 lengthToFind
    ) public view returns (bool, uint256) {
        checkInputIsBuy(_isBuy);
        uint256 currentNodeID = startIndex == 0 ? GUARDHEAD : startIndex;
        uint256 countFind = 0;
        while (
            linkedListsNode[_isBuy][currentNodeID].id != GUARDTAIL &&
            countFind < lengthToFind
        ) {
            if (_isPrev(_isBuy, targetIndex, currentNodeID))
                return (true, currentNodeID);
            currentNodeID = linkedListsNode[_isBuy][currentNodeID].nextNodeID;
            countFind++;
        }
        return (false, currentNodeID);
    }

    //////////////////////////////////////  Market Order    //////////////////////////////////////
    /**
     * @dev Function used to market order in Prism exchange
     * @param _isBuy - The number isBuy (  0 = Buy , 1 = Sell )
     * @param amount - The amount of market order
     * @param _price - The highest or lowest price that will be accepted for a market order 
     */
    function createMarketOrder(
        uint8 _isBuy,
        uint256 amount,
        uint256 _price
    ) public returns (uint256) {
        checkUintZero(amount);
        checkInputIsBuy(_isBuy);

        InfoMarketOrder memory infoMarketOrder = InfoMarketOrder(
            0,
            0,
            0,
            0,
            0,
            0,
            address(0),
            address(0),
            0,
            0,
            0,
            settingExchange.Fee(),
            settingExchange.FeeCollector()
        );

        {
            // _isBuy = 0 => Want to Buy token 0 => Sell token1 Buy token0
            // _isBuy = 1 => Want to Buy token 1 => Sell token0 Buy token1
            (address tokenMain, address tokenSecondary, uint8 isBuy) = _isBuy ==
                0
                ? (token1, token0, 1)
                : (token0, token1, 0); // toggle isBuy and set tokenMain/Secondary
            checkBalances(tokenMain, amount);

            if (isBuy == 1) {
                checkInputMinAmountToken1(amount);
            } else {
                checkInputMinAmountToken0(amount);
            }

            if (listSize[isBuy] <= 0) return amount; // empty orderbook

            uint8 decimals = IERC20(tokenMain).decimals();
            uint256 currentNodeID = linkedListsNode[isBuy][GUARDHEAD]
                .nextNodeID;

            infoMarketOrder.tokenMain = tokenMain;
            infoMarketOrder.tokenSecondary = tokenSecondary;
            infoMarketOrder.isBuy = isBuy;
            infoMarketOrder.decimals = decimals;
            infoMarketOrder.currentNodeID = currentNodeID;
        }

        uint256 platformFee = settingExchange.platformFee();
        uint256 userFee = settingExchange.userFee();

        for (
            uint256 i = 0;
            i < listSize[infoMarketOrder.isBuy] &&
                infoMarketOrder.totalFilled < amount;
            i++
        ) {
            Order storage _order = linkedListsNode[infoMarketOrder.isBuy][
                infoMarketOrder.currentNodeID
            ];

            // cheack highest or lowest price that will be accepted for a market order (price slippage)
            if (_price > 0) {
                if (infoMarketOrder.isBuy == 1) {
                    if (_price < _order.price) {
                        break;
                    }
                } else {
                    if (_price > _order.price) {
                        break;
                    }
                }
            }
            uint256 leftToFill = amount - infoMarketOrder.totalFilled;
            uint256 availableToFill = _order.amount - _order.filled;
            uint256 filled = 0;
            uint256 cost = 0;
            if (infoMarketOrder.isBuy == 1) {
                if (
                    (availableToFill * _order.price) /
                        10 ** infoMarketOrder.decimals >
                    leftToFill
                ) {
                    filled = leftToFill; //Fulfill
                } else {
                    filled =
                        (availableToFill * _order.price) /
                        10 ** infoMarketOrder.decimals; // Fill as much as can Fill
                }
                _order.filled +=
                    (filled * 10 ** infoMarketOrder.decimals) /
                    _order.price;
                cost = (filled * 10 ** infoMarketOrder.decimals) / _order.price; // amount token0
            } else {
                if (availableToFill > leftToFill) {
                    filled = leftToFill; //Fulfill
                } else {
                    filled = availableToFill; // Fill as much as can Fill
                }
                _order.filled += filled;
                cost = (filled * _order.price) / 10 ** infoMarketOrder.decimals;
            }

            infoMarketOrder.totalFilled = infoMarketOrder.totalFilled + filled;
            infoMarketOrder.averagePrice += cost;

            // msg.sender is the seller

            // sell
            // balancesSpot[msg.sender][tokenMain] -= filled;
            // balancesSpot[_order.trader][tokenMain] += filled;

            infoMarketOrder.filledSender += filled; // user  decreaseBalancesSpot tokenMain
            _increaseBalancesSpot(
                filled - ((filled / 10000) * infoMarketOrder.exchangeFee),
                _order.trader,
                infoMarketOrder.tokenMain,
                token0,
                token1
            );
            infoMarketOrder.feeTokenMain += ((filled / 10000) *
                infoMarketOrder.exchangeFee); // collect fees

            //////////////////////////////////////////////////////////////////////////
            //////////////////////////////////////////////////////////////////////////
            //////////////////////////////////////////////////////////////////////////

            // recive after sell
            // balancesSpot[msg.sender][tokenSecondary] += cost;
            // balancesTrade[_order.trader][tokenSecondary] -= cost;

            infoMarketOrder.costSender +=
                cost -
                ((cost / 10000) * infoMarketOrder.exchangeFee); // user increaseBalancesSpot tokenSecondary
            _decreaseBalancesTrade(
                cost,
                _order.trader,
                infoMarketOrder.tokenSecondary,
                token0,
                token1
            );
            infoMarketOrder.feeTokenSecondary += ((cost / 10000) *
                infoMarketOrder.exchangeFee); // collect fees

            // update latest price
            price = _order.price;
            // update currentNodeID
            infoMarketOrder.currentNodeID = _order.nextNodeID;

            emit MarketOrder(
                address(this),
                msg.sender,
                infoMarketOrder.isBuy,
                filled,
                _order.price,
                userFee,
                block.timestamp
            );
        }

        // fill order
        if (infoMarketOrder.totalFilled > 0) {
            // decreaseBalancesSpot user tokenMain
            _decreaseBalancesSpot(
                infoMarketOrder.filledSender,
                msg.sender,
                infoMarketOrder.tokenMain,
                token0,
                token1
            );

            // increaseBalancesSpot user tokenSecondary
            _increaseBalancesSpot(
                infoMarketOrder.costSender,
                msg.sender,
                infoMarketOrder.tokenSecondary,
                token0,
                token1
            );

            // increaseBalancesSpot feeController tokenMain
            _increaseBalancesSpot(
                (infoMarketOrder.feeTokenMain * userFee) / 100,
                address(feeController),
                infoMarketOrder.tokenMain,
                token0,
                token1
            );
            // increaseBalancesSpot feeCollector tokenMain
            _increaseBalancesSpot(
                (infoMarketOrder.feeTokenMain * platformFee) / 100,
                infoMarketOrder.feeCollector,
                infoMarketOrder.tokenMain,
                token0,
                token1
            );

            // increaseBalancesSpot feeController tokenSecondary
            _increaseBalancesSpot(
                (infoMarketOrder.feeTokenSecondary * userFee) / 100,
                address(feeController),
                infoMarketOrder.tokenSecondary,
                token0,
                token1
            );
            // increaseBalancesSpot feeCollector tokenSecondary
            _increaseBalancesSpot(
                (infoMarketOrder.feeTokenSecondary * platformFee) / 100,
                infoMarketOrder.feeCollector,
                infoMarketOrder.tokenSecondary,
                token0,
                token1
            );

            // paid fee to buy order and  sell order
            feeController.collectFeeReward(
                address(this),
                [
                    (infoMarketOrder.feeTokenSecondary * userFee) / 100,
                    (infoMarketOrder.feeTokenMain * userFee) / 100
                ],
                [_isBuy, infoMarketOrder.isBuy]
            );

            //Remove 100% filled orders from the orderbook
            while (
                listSize[infoMarketOrder.isBuy] > 0 &&
                linkedListsNode[infoMarketOrder.isBuy][
                    linkedListsNode[infoMarketOrder.isBuy][GUARDHEAD].nextNodeID
                ].filled +
                    1000 >=
                linkedListsNode[infoMarketOrder.isBuy][
                    linkedListsNode[infoMarketOrder.isBuy][GUARDHEAD].nextNodeID
                ].amount
            ) {
                //Remove the top element in the orders
                removeOrderNoUpdateBalances(
                    infoMarketOrder.isBuy,
                    linkedListsNode[infoMarketOrder.isBuy][GUARDHEAD]
                        .nextNodeID,
                    GUARDHEAD
                );
            }

            if (infoMarketOrder.isBuy == 1) {
                infoMarketOrder.averagePrice =
                    (infoMarketOrder.totalFilled *
                        10 ** infoMarketOrder.decimals) /
                    infoMarketOrder.averagePrice;
            } else {
                infoMarketOrder.averagePrice =
                    (infoMarketOrder.averagePrice *
                        10 ** infoMarketOrder.decimals) /
                    infoMarketOrder.totalFilled;
            }
            emit SumMarketOrder(
                address(this),
                msg.sender,
                infoMarketOrder.isBuy,
                amount,
                infoMarketOrder.averagePrice,
                infoMarketOrder.totalFilled,
                userFee,
                block.timestamp
            );
        }

        return amount - infoMarketOrder.totalFilled;
    }

    function _decreaseBalancesSpot(
        uint256 _amount,
        address _user,
        address _tokenMain,
        address _token0,
        address _token1
    ) internal {
        mainValueWallet.decreaseBalancesSpot(
            _amount,
            _user,
            _tokenMain,
            _token0,
            _token1
        );
    }

    function _increaseBalancesSpot(
        uint256 _amount,
        address _user,
        address _tokenMain,
        address _token0,
        address _token1
    ) internal {
        mainValueWallet.increaseBalancesSpot(
            _amount,
            _user,
            _tokenMain,
            _token0,
            _token1
        );
    }

    function _decreaseBalancesTrade(
        uint256 _amount,
        address _user,
        address _tokenMain,
        address _token0,
        address _token1
    ) internal {
        mainValueWallet.decreaseBalancesTrade(
            _amount,
            _user,
            _tokenMain,
            _token0,
            _token1
        );
    }

    function _increaseBalancesTrade(
        uint256 _amount,
        address _user,
        address _tokenMain,
        address _token0,
        address _token1
    ) internal {
        mainValueWallet.increaseBalancesTrade(
            _amount,
            _user,
            _tokenMain,
            _token0,
            _token1
        );
    }
}
