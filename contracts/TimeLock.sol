//SPDX-License-Identifier:MIT
pragma solidity  0.8.22;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract VaultTimelock is TimelockController{
    //proposers and executors should be gnosis safe wallets
    constructor(uint256 minDelay, address[]memory proposers, address[] memory executor) 
    TimelockController(minDelay, proposers, executor, address(this)) {}
}