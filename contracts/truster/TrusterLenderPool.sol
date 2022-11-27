// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title TrusterLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract TrusterLenderPool is ReentrancyGuard {
    using Address for address;

    IERC20 public immutable damnValuableToken;

    constructor(address tokenAddress) {
        damnValuableToken = IERC20(tokenAddress);
    }

    function flashLoan(
        uint256 borrowAmount, // ❌ 1. 要借的金額
        address borrower, // ❌ 2. 觸發借錢的人
        address target, // ✅ 3. 奇怪的 target，也不是收錢方，沒有限定任何合約
        bytes calldata data // ✅ 4. 任意 data
    ) external nonReentrant {
        uint256 balanceBefore = damnValuableToken.balanceOf(address(this));
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");

        damnValuableToken.transfer(borrower, borrowAmount);

        // 😈？ functionCall 不就是 OpenZepplin Library 提供的方法嗎？ 所以基本上我們可以 call 任何合約做任何事
        target.functionCall(data);

        uint256 balanceAfter = damnValuableToken.balanceOf(address(this));

        // 😈？ 可以讓人先更改餘額讓我們過嗎？ 看起來是不可能
        require(
            balanceAfter >= balanceBefore,
            "Flash loan hasn't been paid back"
        );
    }
}
