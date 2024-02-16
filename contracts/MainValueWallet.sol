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

import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './interface/IERC20.sol';
import './interface/IFactoryPair.sol';
import './interface/ISettingExchange.sol';
import './interface/IFeeController.sol';
import './interface/IFlashLoanCallee.sol';
import './interface/IERC20Rebasing.sol'; // Blast Native Yield
import './interface/IBlast.sol'; // Blast Native Yield;

/**
 * @title MainValueWallet
 * @author Prism exchange
 * @dev This contract is used to store user funds and data on the  Prism exchange
 */
contract MainValueWallet is ReentrancyGuard, Ownable {
    //=======================================
    //========= State Variables =============
    //=======================================

    // Blast Native Yield
    IERC20Rebasing public constant USDB = IERC20Rebasing(0x4200000000000000000000000000000000000022);
    IERC20Rebasing public constant WETH =  IERC20Rebasing(0x4200000000000000000000000000000000000023);
    IBlast public constant BLAST = IBlast(0x4300000000000000000000000000000000000002);


    IFactoryPair public factoryPair;
    ISettingExchange public settingExchange;
    IFeeController public feeController;

    // Mapping from address user => addressToken => user balancesSpot
    mapping(address => mapping(address => uint256)) internal _balancesSpot; // wallet Spot

    // Mapping from address user => addressToken => user balancesTrade
    mapping(address => mapping(address => uint256)) internal _balancesTrade; // wallet Trade

    //=======================================
    //=============== Events ================
    //=======================================

    event Deposit(
        address indexed user,
        address indexed addressToken,
        uint256 amount
    );
    event Withdraw(
        address indexed user,
        address indexed addressToken,
        uint256 amount
    );
    event TransferBetweenAccounts(
        address indexed from,
        address indexed addressToken,
        uint256 amount,
        address indexed to
    );

    //=======================================
    //============== Modifier ===============
    //=======================================

    /**
     * @dev Function used to check that address token can be used in Prism exchange
     * @param _token - The address of token
     */
    modifier validToken(address _token) {
        require(settingExchange.isSaveAddressToken(_token), 'invalid token');
        _;
    }

    /**
     * @dev Function used to check that caller address must call from contract pair and
     * tokenMain must be one of address token 0 or address token 1
     * @param tokenMain - The address of tokenMain
     * @param token0 - The address of token0
     * @param token1 - The address of token1
     */
    modifier validCallerAndToken(
        address tokenMain,
        address token0,
        address token1
    ) {
        require(
            tokenMain == token0 || tokenMain == token1,
            ' invalid tokenMain'
        );
        require(
            factoryPair.getPair(token0, token1) == msg.sender,
            'invalid caller'
        );
        _;
    }

    modifier validFeeCaller() {
        require(msg.sender == address(feeController), 'invalid fee caller');
        _;
    }

    constructor(address _governor) {
        // Blast Native Yield
        USDB.configure(YieldMode.CLAIMABLE);
        WETH.configure(YieldMode.CLAIMABLE);
        // Blast Native Yield
        BLAST.configureClaimableGas();
        BLAST.configureGovernor(_governor);
    }

    //=======================================
    //============ Functions ================
    //=======================================

    /**
     * @dev Function used to set FactoryPair
     * @param _factoryPair - The address of factoryPair
     */
    function setFactoryPair(address _factoryPair) public onlyOwner {
        factoryPair = IFactoryPair(_factoryPair);
    }

    /**
     * @dev Function used to set FactoryPair
     * @param _feeController - The address of feeController
     */
    function setFeeController(address _feeController) public onlyOwner {
        feeController = IFeeController(_feeController);
    }

    /**
     * @dev Function used to set SettingExchange
     * @param _settingExchange - The address of settingExchange
     */
    function setSettingExchange(address _settingExchange) public onlyOwner {
        settingExchange = ISettingExchange(_settingExchange);
    }

    /**
     * @dev Function used to get balancesSpot by user and addressToken
     * @param user - The address of user
     * @param addressToken - The address of token
     * @return uint256 - The balancesSpot by user and addressToken
     */
    function balancesSpot(
        address user,
        address addressToken
    ) public view returns (uint256) {
        return _balancesSpot[user][addressToken];
    }

    /**
     * @dev Function used to get balancesTrade by user and addressToken
     * @param user - The address of user
     * @param addressToken - The address of token
     * @return uint256 - The balancesTrade by user and addressToken
     */
    function balancesTrade(
        address user,
        address addressToken
    ) public view returns (uint256) {
        return _balancesTrade[user][addressToken];
    }

    /**
     * @dev Function used to deposit funds user in Prism exchange
     * @param amount - The amount of funds to deposit
     * @param token - The address of token to deposit
     */
    function deposit(
        uint256 amount,
        address token
    ) external validToken(token) nonReentrant {
        require(amount > 0, "can't deposit 0");
        require(
            IERC20(token).balanceOf(msg.sender) >= amount,
            'balance not sufficient'
        );

        _balancesSpot[msg.sender][token] += amount;

        IERC20(token).transferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, token, amount);
    }

    /**
     * @dev Function used to withdraw funds user in Prism exchange
     * @param amount - The amount of funds to withdraw
     * @param token - The address of token to withdraw
     */
    function withdraw(
        uint256 amount,
        address token
    ) external validToken(token) nonReentrant {
        require(amount > 0, "can't withdraw 0");
        require(
            _balancesSpot[msg.sender][token] >= amount,
            'balance not sufficient'
        );

        _balancesSpot[msg.sender][token] -= amount;

        // Blast Native Yield
        if (token == address(USDB)) {
            USDB.claim(msg.sender, amount);
        } else if (token == address(WETH)) {
            WETH.claim(msg.sender, amount);
        }

        IERC20(token).transfer(msg.sender, amount);

        emit Withdraw(msg.sender, token, amount);
    }

    /**
     * @dev Function used to transfer funds between accounts in Prism exchange
     * this function not use transfer method of erc20, but only changing state variables in the contract
     * @param amount - The amount of funds to transfer
     * @param token - The address of token to transfer
     * @param to - The address to receive funds
     */
    function transferBetweenAccounts(
        uint256 amount,
        address token,
        address to
    ) external validToken(token) nonReentrant {
        require(amount > 0, "can't transfer 0");
        require(to != msg.sender, "can't transfer to same wallet address");
        require(
            _balancesSpot[msg.sender][token] >= amount,
            'balance not sufficient'
        );

        _balancesSpot[msg.sender][token] -= amount;
        _balancesSpot[to][token] += amount;

        emit TransferBetweenAccounts(msg.sender, token, amount, to);
    }

    /**
     * @dev Function used to increaseBalancesSpot directly in Prism exchange
     * @param amount - The amount of funds to increaseBalancesSpot
     * @param user - The address of user to increaseBalancesSpot
     * @param tokenMain - The address of token to increaseBalancesSpot
     * @param token0 - The address of token0 for find contract pair
     * @param token1 - The address of token1 for find contract pair
     */
    function increaseBalancesSpot(
        uint256 amount,
        address user,
        address tokenMain,
        address token0,
        address token1
    ) external validCallerAndToken(tokenMain, token0, token1) {
        _balancesSpot[user][tokenMain] += amount;
    }

    /**
     * @dev Function used to decreaseBalancesSpot directly in Prism exchange
     * @param amount - The amount of funds to decreaseBalancesSpot
     * @param user - The address of user to decreaseBalancesSpot
     * @param tokenMain - The address of token to decreaseBalancesSpot
     * @param token0 - The address of token0 for find contract pair
     * @param token1 - The address of token1 for find contract pair
     */
    function decreaseBalancesSpot(
        uint256 amount,
        address user,
        address tokenMain,
        address token0,
        address token1
    ) external validCallerAndToken(tokenMain, token0, token1) {
        _balancesSpot[user][tokenMain] -= amount;
    }

    /**
     * @dev Function used to increaseBalancesTrade directly in Prism exchange
     * @param amount - The amount of funds to increaseBalancesTrade
     * @param user - The address of user to increaseBalancesTrade
     * @param tokenMain - The address of token to increaseBalancesTrade
     * @param token0 - The address of token0 for find contract pair
     * @param token1 - The address of token1 for find contract pair
     */
    function increaseBalancesTrade(
        uint256 amount,
        address user,
        address tokenMain,
        address token0,
        address token1
    ) external validCallerAndToken(tokenMain, token0, token1) {
        _balancesTrade[user][tokenMain] += amount;
    }

    /**
     * @dev Function used to decreaseBalancesTrade directly in Prism exchange
     * @param amount - The amount of funds to decreaseBalancesTrade
     * @param user - The address of user to decreaseBalancesTrade
     * @param tokenMain - The address of token to decreaseBalancesTrade
     * @param token0 - The address of token0 for find contract pair
     * @param token1 - The address of token1 for find contract pair
     */
    function decreaseBalancesTrade(
        uint256 amount,
        address user,
        address tokenMain,
        address token0,
        address token1
    ) external validCallerAndToken(tokenMain, token0, token1) {
        _balancesTrade[user][tokenMain] -= amount;
    }

    function increaseBalancesSpotFee(
        uint256 amount,
        address user,
        address tokenMain
    ) external validFeeCaller {
        _balancesSpot[user][tokenMain] += amount;
    }

    function decreaseBalancesSpotFee(
        uint256 amount,
        address user,
        address tokenMain
    ) external validFeeCaller {
        _balancesSpot[user][tokenMain] -= amount;
    }

    /**
     * @dev Function flashLoan any token in Prism exchange
     * @param receiver - The receiver token
     * @param _token - The list address token flashLoan
     * @param _amount - The list amount token flashLoan
     * @param data - The bytes data send to receiver
     */
    function flashLoan(
        address receiver,
        address[] memory _token,
        uint256[] memory _amount,
        bytes calldata data
    ) external nonReentrant {
        require(
            _token.length == _amount.length,
            'length token not equal amount'
        );
        uint256[] memory balanceBefore = new uint256[](_token.length);
        uint256[] memory fee = new uint256[](_token.length);
        for (uint256 i = 0; i < _token.length; i++) {
            balanceBefore[i] = IERC20(_token[i]).balanceOf(address(this));
            fee[i] = (_amount[i] / 1000); // fee 0.1 %
            IERC20(_token[i]).transfer(receiver, _amount[i]);
        }
        IFlashLoanCallee(receiver).IFlashLoanCall(
            receiver,
            _token,
            _amount,
            fee,
            data
        );
        uint256[] memory balanceAfter = new uint256[](_token.length);
        for (uint256 i = 0; i < _token.length; i++) {
            balanceAfter[i] = IERC20(_token[i]).balanceOf(address(this));
            require(
                balanceAfter[i] >= (fee[i] + balanceBefore[i]),
                "Flash loan hasn't been paid back"
            );
            IERC20(_token[i]).transfer(settingExchange.FeeCollector(), fee[i]); // transfer fee to FeeCollector
        }
    }
}
