// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

/**
 * @title SideEntranceLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract SideEntranceLenderPool {
    using Address for address payable;

    mapping(address => uint256) private balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value; //  ✨ 可以改變餘額
    }

    function withdraw() external {
        uint256 amountToWithdraw = balances[msg.sender];
        balances[msg.sender] = 0;
        payable(msg.sender).sendValue(amountToWithdraw); //  ✨ 可以轉錢給自己
    }

    function flashLoan(uint256 amount) external {
        uint256 balanceBefore = address(this).balance;
        require(balanceBefore >= amount, "Not enough ETH in balance");
        // ✨ 可以讓外部用借來的錢做任何事
        IFlashLoanEtherReceiver(msg.sender).execute{value: amount}();

        require( //  可以想辦法讓餘額不變，就可以不用還錢 ✨
            address(this).balance >= balanceBefore,
            "Flash loan hasn't been paid back"
        );
    }
}
