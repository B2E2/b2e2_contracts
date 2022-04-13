'use strict';

var IdentityContract = artifacts.require('./IdentityContract.sol');
var IdentityContractFactory = artifacts.require('./IdentityContractFactory.sol');
var identityContractFactory;
var marketAuthority;

contract('IdentityContractFactory', function(accounts) {

    before(async function() {
        accounts = await web3.eth.getAccounts();

        marketAuthority = await IdentityContract.new('0x0000000000000000000000000000000000000000',
            [900, 1, 3*30*24*3600], accounts[9], {from: accounts[9]});
        console.log(`Successfully deployed IdentityContract for Market Authority with address: ${marketAuthority.address}`);
        identityContractFactory = await IdentityContractFactory.new(marketAuthority.address, {from: accounts[9]});
        console.log(`Successfully deployed IdentityContractFactory with address: ${identityContractFactory.address}`);
    });

    it('can create Identity Contracts.', async function() {
        let idcDeployment1 = await identityContractFactory.createIdentityContract({from: accounts[1]});
        let idcDeployment1Twin = await identityContractFactory.createIdentityContract({from: accounts[1]});
        let idcDeployment2 = await identityContractFactory.createIdentityContract({from: accounts[2]});

        // Make sure that the idc creation event has been emitted.
        assert.equal(idcDeployment1.logs[0].event, 'IdentityContractCreation');
        assert.equal(idcDeployment1Twin.logs[0].event, 'IdentityContractCreation');
        assert.equal(idcDeployment2.logs[0].event, 'IdentityContractCreation');

        // Make sure that the creation events have been emitted and that there are no duplicate addresses.
        let idcAddress1 = idcDeployment1.logs[0].args.idcAddress;
        let idcAddress1Twin = idcDeployment1Twin.logs[0].args.idcAddress;
        let idcAddress2 = idcDeployment2.logs[0].args.idcAddress;
        assert.notEqual(idcAddress1, idcAddress1Twin);
        assert.notEqual(idcAddress1, idcAddress2);
        assert.notEqual(idcAddress1Twin, idcAddress2);

        // Make sure that the owners are correct.
        let owner1 = idcDeployment1.logs[0].args.owner;
        let owner1Twin = idcDeployment1Twin.logs[0].args.owner;
        let owner2 = idcDeployment2.logs[0].args.owner;
        assert.equal(owner1, accounts[1]);
        assert.equal(owner1Twin, accounts[1]);
        assert.equal(owner2, accounts[2]);

        // Make sure that the contracts can be interacted with.
        let idc1 = new web3.eth.Contract(IdentityContract.abi, idcAddress1);
        let idc2 = new web3.eth.Contract(IdentityContract.abi, idcAddress2);
        assert.equal(await idc1.methods.owner().call(), accounts[1]);
        assert.equal(await idc2.methods.owner().call(), accounts[2]);
    });

    it('knows its registered contracts.', async function() {
        let idcThroughFactory = await identityContractFactory.createIdentityContract({from: accounts[1]});
        let idcThroughFactoryAdress = idcThroughFactory.logs[0].args.idcAddress;

        let independentIdc = await IdentityContract.new(marketAuthority.address, [0, 0, 0], accounts[2],
            {from: accounts[2]});

        assert.equal(await identityContractFactory.isRegisteredIdentityContract(idcThroughFactoryAdress), true);
        assert.equal(await identityContractFactory.isRegisteredIdentityContract(independentIdc.address), false);

        // The market authority needs to be registered too.
        assert.equal(await identityContractFactory.isRegisteredIdentityContract(marketAuthority.address), true);
    });
});
