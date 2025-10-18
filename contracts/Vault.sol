//SPDX-License-Identifier:MIT
pragma solidity 0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import "./libraries/Errors.sol";

contract Vault is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    address public immutable timelockController;
    address public immutable pauseController;
    address public immutable assetsController; //The address which can allocate flexible funds

    address public immutable LYFToken;

    bytes32 public constant ROLE_TIME_CONTROLLER =
        keccak256("ROLE_TIME_CONTROLLER");
    bytes32 public constant ROLE_PAUSE_CONTROLLER =
        keccak256("ROLE_PAUSE_CONTROLLER");
    bytes32 public constant ROLE_ASSETS_CONTROLLER =
        keccak256("ROLE_ASSETS_CONTROLLER");

    mapping(address => bool) public whiteList;
    uint256 public constant MAX_FLEXIBLE_FUND = 1_000_000 * 1e18; //maximum limit
    uint256 public flexibleFundLimit; //Allowwance limit of flexible funds for now
    uint256 public flexibleFundUsed = 0;

    //event
    event SendFlexibleFund(address indexed to,  uint256 amount);
    event SetFlexibleFundLimit(uint256 limit);
    event AuthorizedFund(address indexed spender, uint256 amount);
    event WhiteListUpdated(address indexed spender, bool allow);
    constructor(
        address timelockController_,
        address pauseController_,
        address LYFToken_,
        address assetsController_,
        uint256 flexibleFundLimit_
    ) {
        if (
            timelockController_ == address(0) ||
            pauseController_ == address(0) ||
            assetsController_ == address(0)||
            LYFToken_ == address(0)
        ) {
            revert Errors.ZeroAddress();
        }
        timelockController = timelockController_;
        pauseController = pauseController_;
        assetsController = assetsController_;
        LYFToken = LYFToken_;

        _grantRole(DEFAULT_ADMIN_ROLE, timelockController);
        _grantRole(ROLE_TIME_CONTROLLER, timelockController);
        _grantRole(ROLE_PAUSE_CONTROLLER, pauseController);
        _grantRole(ROLE_ASSETS_CONTROLLER, assetsController);
        flexibleFundLimit = flexibleFundLimit_;
    }

    function authorizeFund(address spender, uint256 amount) external whenNotPaused onlyRole(ROLE_TIME_CONTROLLER){
        if(!whiteList[spender]){
            revert Errors.UnAuthorized();
        }
        if(!_isContract(spender)){
            revert Errors.EOANotAllow();
        }
        IERC20(LYFToken).safeApprove(spender, 0);
        IERC20(LYFToken).safeApprove(spender, amount);
        emit AuthorizedFund(spender, amount);
    }

       function sentFlexibleFunds(
        address to,
        uint256 amount
    ) external onlyRole(ROLE_ASSETS_CONTROLLER) nonReentrant whenNotPaused {
        if (amount + flexibleFundUsed > flexibleFundLimit) {
            revert Errors.ExceedAllowanceLimit();
        }
        if (IERC20(LYFToken).balanceOf(address(this)) < amount) {
            revert Errors.InsufficientBalance();
        }
        if (to == address(0)) {
            revert Errors.ZeroAddress();
        }
        flexibleFundUsed += amount;
        IERC20(LYFToken).safeTransfer(to,amount);
        emit SendFlexibleFund(to, amount);
    }

     function setWhiteList(address spender, bool allow) external onlyRole(ROLE_TIME_CONTROLLER){
        if(spender == address(0)){
            revert Errors.ZeroAddress();
        }
        if(!_isContract(spender)){
            revert Errors.EOANotAllow();
        }
        whiteList[spender] = allow;
        emit WhiteListUpdated(spender,allow);
    }

    function setFlexibleFundLimit(
        uint256 newLimit
    ) external onlyRole(ROLE_TIME_CONTROLLER) {
        if(newLimit > MAX_FLEXIBLE_FUND){
            revert Errors.ExceedAllowanceLimit();
        }
        flexibleFundLimit = newLimit;
        emit SetFlexibleFundLimit(flexibleFundLimit);
    }

    function _isContract(address spender) internal view returns(bool){
        return spender.code.length > 0;
    }

    //Pause
    function pause() external onlyRole(ROLE_PAUSE_CONTROLLER) {
        _pause();
    }

    function unpause() external onlyRole(ROLE_PAUSE_CONTROLLER) {
        _unpause();
    }

    receive() external payable {
        revert("No ETH");
    }

    fallback() external payable {
        revert("No ETH");
    }
}
