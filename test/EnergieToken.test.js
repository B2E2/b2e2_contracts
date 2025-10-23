'use strict';

const truffleAssert = require('truffle-assertions');
const eutil = require('ethereumjs-util');

const account5Sk = '0x6df57b1393f3ddd3a0347ce8b7cdab7eee05d7d6ca95b4f6c0ed34b195e05c49';
const account6Sk = '0x32304e16365a29cf15efcdb87e57011e62d6565a7d412e072ad71193f736a39e';
const account7Sk = '0xa19ef78cf010a48dc62830878ec57e1e0cb50e42721b095251f9b477d9b67aec';
const account8Sk = '0xca4d0784a515ad9ad7aef35f49004de0cbba14649cc7ed36cef0134838954cb6';
const account9Sk = '0x0b1e3843d7172d055d410af0c27f22db56a0a7518238ac4dd3aa55f09fce0b3b';

var IdentityContract = artifacts.require('./IdentityContract.sol');
var IdentityContractFactory = artifacts.require('./IdentityContractFactory.sol');
var identityContractFactory;
var marketAuthority;
var balanceAuthority;
var meteringAuthority;
var physicalAssetAuthority;
var idcs = [];

var EnergyToken = artifacts.require('./EnergyToken.sol');
var energyToken;
var energyTokenWeb3;

var SimpleDistributor = artifacts.require('./SimpleDistributor.sol');
var simpleDistributor;
var simpleDistributorWeb3;

var ComplexDistributor = artifacts.require('./ComplexDistributor.sol');
var complexDistributor;
var complexDistributorWeb3;

let complexDistributorCertificateId;

contract('EnergyToken', function(accounts) {
    before(async function() {
        accounts = await web3.eth.getAccounts();

        marketAuthority = await IdentityContract.new('0x0000000000000000000000000000000000000000',
            [900, 1, 3*30*24*3600], accounts[9], {from: accounts[9]});
        console.log(`Successfully deployed IdentityContract for Market Authority with address: ${marketAuthority.address}`);
        identityContractFactory = await IdentityContractFactory.new(marketAuthority.address, {from: accounts[9]});
        console.log(`Successfully deployed IdentityContractFactory with address: ${identityContractFactory.address}`);

        let abi = IdentityContract.abi;

        let balanceAuthorityDeployment =  await identityContractFactory.createIdentityContract({from: accounts[8]});
        assert.equal(balanceAuthorityDeployment.logs[0].event, 'IdentityContractCreation');
        let balanceAuthorityAddress = balanceAuthorityDeployment.logs[0].args.idcAddress;
        balanceAuthority = new web3.eth.Contract(abi, balanceAuthorityAddress);
        console.log(`Successfully deployed Balance Authority IDC with address: ${balanceAuthority.options.address}`);

        let meteringAuthorityDeployment =  await identityContractFactory.createIdentityContract({from: accounts[8]});
        assert.equal(meteringAuthorityDeployment.logs[0].event, 'IdentityContractCreation');
        let meteringAuthorityAddress = meteringAuthorityDeployment.logs[0].args.idcAddress;
        meteringAuthority = new web3.eth.Contract(abi, meteringAuthorityAddress);
        console.log(`Successfully deployed Metering Authority IDC with address: ${meteringAuthority.options.address}`);

        let physicalAssetAuthorityDeployment =  await identityContractFactory.createIdentityContract({from: accounts[8]});
        assert.equal(physicalAssetAuthorityDeployment.logs[0].event, 'IdentityContractCreation');
        let physicalAssetAuthorityAddress = physicalAssetAuthorityDeployment.logs[0].args.idcAddress;
        physicalAssetAuthority = new web3.eth.Contract(abi, physicalAssetAuthorityAddress);
        console.log(`Successfully deployed Physical Asset Authority IDC with address: ${physicalAssetAuthority.options.address}`);

        let json = '{ "q": "ab", "expiryDate": "1958292001", "startDate": "1" }';
        let data = web3.utils.toHex(json);
        await addClaim(balanceAuthority, 10010, marketAuthority.address, data, '', account9Sk);
        await addClaim(meteringAuthority, 10020, marketAuthority.address, data, '', account9Sk);
        await addClaim(physicalAssetAuthority, 10030, marketAuthority.address, data, '', account9Sk);
    
        for(let i=0; i < 3; i++) {
            let idcDeployment =  await identityContractFactory.createIdentityContract({from: accounts[i+5]});
            assert.equal(balanceAuthorityDeployment.logs[0].event, 'IdentityContractCreation');
            let idcAddress = idcDeployment.logs[0].args.idcAddress;
            idcs[i] = new web3.eth.Contract(abi, idcAddress);
            console.log(`Successfully deployed IdentityContract ${i} with address: ${idcs[i].options.address}`);
        }
    
        energyToken = await EnergyToken.new(marketAuthority.address);
        energyTokenWeb3 = new web3.eth.Contract(EnergyToken.abi, energyToken.address);
        console.log(`Successfully deployed EnergyToken with address: ${energyToken.address}`);
    
        simpleDistributor = await SimpleDistributor.new(energyToken.address, true, accounts[0]);
        simpleDistributorWeb3 = new web3.eth.Contract(SimpleDistributor.abi, simpleDistributor.address);
        console.log(`Successfully deployed SimpleDistributor with address: ${simpleDistributor.address}`);

        complexDistributor = await ComplexDistributor.new(energyToken.address, true, accounts[0]);
        complexDistributorWeb3 = new web3.eth.Contract(ComplexDistributor.abi, complexDistributor.address);
        console.log(`Successfully deployed ComplexDistributor with address: ${complexDistributor.address}`);
    });

    /**
     * Differentiates between Truffle contract object and web3 contract object.
     */
    function isWeb3Contract(subject) {
        return subject.address === undefined;
    }

    async function computeClaimSignature(subject, topic, data, uri, signingKey) {
        const subjectAddress = isWeb3Contract(subject) ? subject.options.address : subject.address;
        const hash = web3.utils.soliditySha3(subjectAddress, topic, data);
        const signatureSplit = await eutil.ecsign(new Buffer(hash.slice(2), 'hex'), new Buffer(signingKey.slice(2), 'hex'));
        const signatureMerged = '0x' + signatureSplit.r.toString('hex') + signatureSplit.s.toString('hex') + signatureSplit.v.toString(16);

        return signatureMerged;
    }

    /**
    * Not suitable for overriding claims if sendViaIdc is false because that would require the sender
    * to be the subject or the issues from the perspective of function addClaim() of the subject.
    * Use addClaimViaIdc() instead.
    */
    async function addClaim(subject, topic, issuerAddress, data, uri, signingKey) {
        const signatureMerged = await computeClaimSignature(subject, topic, data, uri, signingKey);

        if(!isWeb3Contract(subject)) {
            await subject.addClaim(topic, 1, issuerAddress, signatureMerged, data, uri);
        } else {
            await subject.methods.addClaim(topic, 1, issuerAddress, signatureMerged, data, uri).send({from: accounts[0], gas: 7000000});
        }
    }

    /**
    * Adds a claim to an IDC via an IDC. Suitable for overriding claims.
    */
    async function addClaimViaIdc(subject, topic, issuerAddress, data, uri, signingKey, txSenderAccount) {
        const signatureMerged = await computeClaimSignature(subject, topic, data, uri, signingKey);

        if(!isWeb3Contract(subject)) {
            throw new Error('only web3 contracts are supported as subject of addClaimViaIdc');
        }

        const abiAddClaim = subject.methods.addClaim(topic, 1, issuerAddress, signatureMerged, data, uri).encodeABI();
        await subject.methods.execute(0, subject.options.address, 0, abiAddClaim).send({from: txSenderAccount, gas: 7000000});
    }

    it('determines token IDs correctly.', async function() {
        // Get token ID.
        const receivedTokenId = await energyToken.getTokenId(2, 1642932001, '0x7f10C80B27f9D4E8524748f2b31cAc86069f6C49', 0);

        // Pad token ID to full length.
        let receivedTokenIdPadded = receivedTokenId.toString('hex');
        while(receivedTokenIdPadded.length < 64) {
            receivedTokenIdPadded = '0' + receivedTokenIdPadded;
        }
    
        // Determine expected token ID.
        const tokenKind = '03'; // A consumption-based forward is stated as a 2 when calling functions (position in the enum listing) but it is rerpesented as "03" (last 2 bits set (relative, consumption-based)).
        const balancePeriod = 1642932001;
        const addressOfIdc = '0x7f10C80B27f9D4E8524748f2b31cAc86069f6C49';
        const expectedTokenId = tokenKind + web3.utils.soliditySha3({type: 'uint64', value: balancePeriod},
            {type: 'address', value: addressOfIdc},
            {type: 'uint248', value: 0}).slice(4);
                                                    
        assert.equal(receivedTokenIdPadded, expectedTokenId);
    });

    it('converts between uints an enums.', async function() {
        let tokenIds = [0, 2, 3, 4];
        for (let i = 0; i < 4; i++) {
            assert.equal(await energyToken.tokenKind2Number(i), tokenIds[i]);
            assert.equal(await energyToken.number2TokenKind(tokenIds[i]), i);
        }
    });

    it('can mint tokens.', async function() {
        // IDC 0 is the generation plant.
        // IDC 2 is the token recipient.

        // Claim necessary for receiving.
        let jsonAcceptedDistributor = '{ "t": "t", "expiryDate": "1958292001", "startDate": "1", "address": "' + idcs[2].options.address.slice(2).toLowerCase() + '" }';
        let dataAcceptedDistributor = web3.utils.toHex(jsonAcceptedDistributor);
        await addClaim(simpleDistributor, 10120, balanceAuthority.options.address, dataAcceptedDistributor, '', account8Sk);
        await addClaim(complexDistributor, 10120, balanceAuthority.options.address, dataAcceptedDistributor, '', account8Sk);

        // Give claims to IDC 0.
        const json = '{ "q": "ab", "expiryDate": "1958292001", "startDate": "1", "realWorldPlantId": "bestPlantId" }';
        const data = web3.utils.toHex(json);
        const jsonExistenceGeneration = '{ "type": "generation", "expiryDate": "1958292001", "startDate": "1", "realWorldPlantId": "bestPlantId" }';
        const dataExistenceGeneration = web3.utils.toHex(jsonExistenceGeneration);
        const jsonMaxGen = '{ "maxGen": "300000000", "expiryDate": "1958292001", "startDate": "1", "realWorldPlantId": "bestPlantId" }';
        const dataMaxGen = web3.utils.toHex(jsonMaxGen);
        const jsonMaxCon = '{ "maxCon": "150000000", "expiryDate": "1958292001", "startDate": "1", "realWorldPlantId": "bestPlantId" }';
        const dataMaxCon = web3.utils.toHex(jsonMaxCon);
        const jsonInstallationDate = '{ "installationDate": "1672531200", "expiryDate": "1958292001", "startDate": "1", "realWorldPlantId": "bestPlantId" }';
        const dataInstallationDate = web3.utils.toHex(jsonInstallationDate);

        await addClaim(idcs[0], 10130, idcs[0].options.address, data, '', account5Sk);
        await addClaim(idcs[0], 10050, balanceAuthority.options.address, data, '', account8Sk);
        await addClaim(idcs[0], 10060, physicalAssetAuthority.options.address, dataExistenceGeneration, '', account8Sk);
        await addClaim(idcs[0], 10070, physicalAssetAuthority.options.address, data, '', account8Sk);
        await addClaim(idcs[0], 10080, physicalAssetAuthority.options.address, data, '', account8Sk);
        await addClaim(idcs[0], 10040, meteringAuthority.options.address, data, '', account8Sk);
        await addClaim(idcs[0], 10065, physicalAssetAuthority.options.address, dataMaxGen, '', account8Sk);
        await addClaim(idcs[0], 10062, physicalAssetAuthority.options.address, dataInstallationDate, '', account8Sk);

        // Give claims to IDC 2.
        await addClaim(idcs[2], 10130, idcs[2].options.address, data, '', account7Sk);
        await addClaim(idcs[2], 10040, meteringAuthority.options.address, data, '', account8Sk);
        await addClaim(idcs[2], 10050, balanceAuthority.options.address, data, '', account8Sk);
        await addClaim(idcs[2], 10060, physicalAssetAuthority.options.address, dataExistenceGeneration, '', account8Sk);
        await addClaim(idcs[2], 10065, physicalAssetAuthority.options.address, dataMaxGen, '', account8Sk);
        await addClaim(idcs[2], 10140, physicalAssetAuthority.options.address, dataMaxCon, '', account8Sk);
        await addClaim(idcs[2], 10062, physicalAssetAuthority.options.address, dataInstallationDate, '', account8Sk);

        // Get token ID.
        //await energyToken.createTokenFamily(1800612001, idcs[0].options.address, 0)
        let receivedTokenId = await energyToken.getTokenId(2, 1800612001, idcs[0].options.address, 0);

        // Pad token ID to full length.
        let receivedTokenIdPadded = receivedTokenId.toString('hex');
        while(receivedTokenIdPadded.length < 64) {
            receivedTokenIdPadded = '0' + receivedTokenIdPadded;
        }
        let id = '0x' + receivedTokenIdPadded;

        // Grant reception approval.
        await idcs[2].methods.approveSender(energyToken.address, idcs[0].options.address, '1958292001', '17000000000000000000', id).send({from: accounts[7], gas: 7000000});

        // Create forwards.
        let abiCreateForwardsCall = energyTokenWeb3.methods.createForwards(1800612001, 2, simpleDistributor.address).encodeABI();

        await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateForwardsCall).send({from: accounts[5], gas: 7000000});

        // Perform actual mint operation via execute() of IDC 0.
        let abiMintCall = energyTokenWeb3.methods.mint(id, [idcs[2].options.address], ['17000000000000000000']).encodeABI();

        await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiMintCall).send({from: accounts[5], gas: 8000000});

        // Check success of mint operation.
        let balanceAcc1 = await energyToken.balanceOf(accounts[1], id);
        let balanceIdc2 = await energyToken.balanceOf(idcs[2].options.address, id);
        assert.equal(balanceAcc1, 0);
        assert.equal(balanceIdc2, 17E18);

        let balances = await energyToken.balanceOfBatch([accounts[1], idcs[2].options.address], [id, id]);
        assert.equal(balances.length, 2);
        assert.equal(balances[0], 0);
        assert.equal(balances[1], 17E18);
    });

    it('can create generation-based forwards.', async function() {
        let balancePeriod = '1958292001';
        let abiCreateTokensCall = energyTokenWeb3.methods.createForwards(balancePeriod, 1, simpleDistributor.address).encodeABI();
        await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateTokensCall).send({from: accounts[5], gas: 7000000});

        // Make sure that repeated calls revert as each generation-based forward cannot be created more than once.
        await truffleAssert.reverts(idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateTokensCall).send({from: accounts[5], gas: 7000000}));

        // I can't get the return value because this is run via execute. It also wouldn't work anyway because web3 is stupid. Furthermore, I wasn't able to figure out how to get the event from web3. It doesn't work the way events can be retrieved using truffle contract objects and everything I've tried yielded null, undefined, an empty array, or other thing that just didn't make any sense. So I need to either compute the token ID here or get it via another function call.
        let id = await energyToken.getTokenId(1, balancePeriod, idcs[0].options.address, 0);

        assert.equal(await energyToken.balanceOf(idcs[0].options.address, id), 100E18);
        assert.equal(await energyToken.balanceOf(idcs[1].options.address, id), 0);
    });

    it('can transfer tokens.', async function() {
        // IDC 2 has 17 tokens (17E18 elementary units) from the mint operation.

        // Get token ID.
        let receivedTokenId = await energyToken.getTokenId(2, 1800612001, idcs[0].options.address, 0);

        // Pad token ID to full length.
        let receivedTokenIdPadded = receivedTokenId.toString('hex');
        while(receivedTokenIdPadded.length < 64) {
            receivedTokenIdPadded = '0' + receivedTokenIdPadded;
        }
        let id = '0x' + receivedTokenIdPadded;

        // Grant reception approval for sending 12 tokens from IDC 2 to IDC 1.
        let abiApproveSenderCall = idcs[1].methods.approveSender(energyToken.address, idcs[2].options.address, '1958292001', '5000000000000000000', id).encodeABI();
        await idcs[1].methods.execute(0, idcs[1].options.address, 0, abiApproveSenderCall).send({from: accounts[6], gas: 7000000});

        // Before the transfer can happen, some claims need to be issued and published.
        // Claims necessary for sending.
        let json = '{ "q": "ab", "expiryDate": "1958292001", "startDate": "1", "realWorldPlantId": "bestPlantId" }';
        let data = web3.utils.toHex(json);
        const jsonMaxCon = '{ "maxCon": "150000000", "expiryDate": "1958292001", "startDate": "1", "realWorldPlantId": "bestPlantId" }';
        const dataMaxCon = web3.utils.toHex(jsonMaxCon);    
        await addClaim(idcs[1], 10130, idcs[1].options.address, data, '', account6Sk);
        await addClaim(idcs[1], 10050, balanceAuthority.options.address, data, '', account8Sk);
        await addClaim(idcs[1], 10060, physicalAssetAuthority.options.address, data, '', account8Sk);
        await addClaim(idcs[1], 10070, physicalAssetAuthority.options.address, data, '', account8Sk);
        await addClaim(idcs[1], 10080, physicalAssetAuthority.options.address, data, '', account8Sk);
        await addClaim(idcs[1], 10040, meteringAuthority.options.address, data, '', account8Sk);
        await addClaim(idcs[1], 10140, physicalAssetAuthority.options.address, dataMaxCon, '', account8Sk);

        // Claim necessary for receiving.
        let jsonAcceptedDistributor = '{ "t": "t", "expiryDate": "1958292001", "startDate": "1", "address": "' + idcs[1].options.address.slice(2).toLowerCase() + '" }';
        let dataAcceptedDistributor = web3.utils.toHex(jsonAcceptedDistributor);
        await addClaim(idcs[1], 10120, balanceAuthority.options.address, dataAcceptedDistributor, '', account8Sk);

        // Send 5 tokens.
        let abiTransfer = energyTokenWeb3.methods.safeTransferFrom(idcs[2].options.address, idcs[1].options.address, id, '5000000000000000000', '0x').encodeABI();
        await idcs[2].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransfer).send({from: accounts[7], gas: 7000000});

        // Repeated transfers are prohibited. So the the same transfer again has to fail.
        await truffleAssert.reverts(idcs[2].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransfer).send({from: accounts[7], gas: 7000000}));

        // Make sure that the balances are correct.
        let balance1 = await energyToken.balanceOf(idcs[1].options.address, id);
        let balance2 = await energyToken.balanceOf(idcs[2].options.address, id);
        assert.equal(balance1, 5E18);
        assert.equal(balance2, 12E18);

        // Upper edge case.
        let abiTransferUpper = energyTokenWeb3.methods.safeTransferFrom(idcs[2].options.address, idcs[1].options.address, id, '2000000000000000001', '0x').encodeABI();
        await truffleAssert.reverts(idcs[2].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransferUpper).send({from: accounts[7], gas: 7000000}));

        // Lower edge case.
        let abiTransferLower = energyTokenWeb3.methods.safeTransferFrom(idcs[2].options.address, idcs[1].options.address, id, '1999999999999999999', '0x').encodeABI();
        await truffleAssert.reverts(idcs[2].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransferLower).send({from: accounts[7], gas: 7000000}));

        // Verify that the balanced remained the same.
        balance1 = await energyToken.balanceOf(idcs[1].options.address, id);
        balance2 = await energyToken.balanceOf(idcs[2].options.address, id);
        assert.equal(balance1, 5E18);
        assert.equal(balance2, 12E18);

        // Self-transfers are not allowed without reception approval.
        let abiTransferSelf1 = energyTokenWeb3.methods.safeTransferFrom(idcs[2].options.address, idcs[2].options.address, id, '5000000000000000000', '0x').encodeABI();
        await truffleAssert.reverts(idcs[2].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransferSelf1).send({from: accounts[7], gas: 7000000}));

        // Transferring tokens to a receiver without the necessary claims needs to fail.
        let abiApproveSenderCallSimpleDistributor = simpleDistributorWeb3.methods.approveSender(energyToken.address, idcs[2].options.address, '1958292001', '1000000000000000000', id).encodeABI();
        await simpleDistributorWeb3.methods.execute(0, simpleDistributorWeb3.options.address, 0, abiApproveSenderCallSimpleDistributor).send({from: accounts[0], gas: 7000000});
        let abiTransferToSimpleDistributor = energyTokenWeb3.methods.safeTransferFrom(idcs[2].options.address, simpleDistributorWeb3.options.address, id, '1000000000000000000', '0x').encodeABI();
        await truffleAssert.reverts(idcs[2].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransferToSimpleDistributor).send({from: accounts[7], gas: 7000000}));
    });

    it.skip('can perform batch transfers.', async function() {
        // Get token ID of forward. Using a different balance period to get balances back to zero.
        let receivedTokenId1 = await energyToken.getTokenId(2, 1800612901, idcs[0].options.address, 0);

        // Pad token ID to full length.
        let receivedTokenId1Padded = receivedTokenId1.toString('hex');
        while(receivedTokenId1Padded.length < 64) {
            receivedTokenId1Padded = '0' + receivedTokenId1Padded;
        }
        let id1 = '0x' + receivedTokenId1Padded;

        // Get token ID of another forward.
        let receivedTokenId2 = await energyToken.getTokenId(2, 1800621901, idcs[0].options.address, 0);

        // Pad token ID to full length.
        let receivedTokenId2Padded = receivedTokenId2.toString('hex');
        while(receivedTokenId2Padded.length < 64) {
            receivedTokenId2Padded = '0' + receivedTokenId2Padded;
        }
        let id2 = '0x' + receivedTokenId2Padded;

        // Reception approval for receiving minted forwards.
        let abiApproveSenderCall11 = idcs[1].methods.approveSender(energyToken.address, idcs[0].options.address, '1958292001', '17000000000000000000', id1).encodeABI();
        await idcs[1].methods.execute(0, idcs[1].options.address, 0, abiApproveSenderCall11).send({from: accounts[6], gas: 7000000});
        let abiApproveSenderCall12 = idcs[1].methods.approveSender(energyToken.address, idcs[0].options.address, '1958292001', '17000000000000000000', id2).encodeABI();
        await idcs[1].methods.execute(0, idcs[1].options.address, 0, abiApproveSenderCall12).send({from: accounts[6], gas: 7000000});

        // Forwards creation.
        let abiCreateForwardsCall1 = energyTokenWeb3.methods.createForwards(1800612901, 2, simpleDistributor.address).encodeABI();
        await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateForwardsCall1).send({from: accounts[5], gas: 7000000});
        let abiCreateForwardsCall2 = energyTokenWeb3.methods.createForwards(1800621901, 2, simpleDistributor.address).encodeABI();
        await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateForwardsCall2).send({from: accounts[5], gas: 7000000});

        // Minting.
        let abiMintCall1 = energyTokenWeb3.methods.mint(id1, [idcs[1].options.address], ['17000000000000000000']).encodeABI();
        await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiMintCall1).send({from: accounts[5], gas: 8000000});
        let abiMintCall2 = energyTokenWeb3.methods.mint(id2, [idcs[1].options.address], ['17000000000000000000']).encodeABI();
        await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiMintCall2).send({from: accounts[5], gas: 8000000});

        // Reception approval is required for forwards.
        let abiApproveSenderCall21 = idcs[2].methods.approveSender(energyToken.address, idcs[1].options.address, '1958292001', '1000000000000000000', id1).encodeABI();
        await idcs[2].methods.execute(0, idcs[2].options.address, 0, abiApproveSenderCall21).send({from: accounts[7], gas: 7000000});
        let abiApproveSenderCall22 = idcs[2].methods.approveSender(energyToken.address, idcs[1].options.address, '1958292001', '3000000000000000000', id2).encodeABI();
        await idcs[2].methods.execute(0, idcs[2].options.address, 0, abiApproveSenderCall22).send({from: accounts[7], gas: 7000000});

        // Transfer.
        let abiBatchTransfer = energyTokenWeb3.methods.safeBatchTransferFrom(idcs[1].options.address, idcs[2].options.address, [id1, id2], ['1000000000000000000', '3000000000000000000'], '0x00').encodeABI();
        await idcs[1].methods.execute(0, energyTokenWeb3.options.address, 0, abiBatchTransfer).send({from: accounts[6], gas: 12000000});

        // Check updated balances.
        let balance11 = await energyToken.balanceOf(idcs[1].options.address, id1);
        let balance12 = await energyToken.balanceOf(idcs[1].options.address, id2);
        let balance21 = await energyToken.balanceOf(idcs[2].options.address, id1);
        let balance22 = await energyToken.balanceOf(idcs[2].options.address, id2);
        assert.equal(balance11, 16E18);
        assert.equal(balance12, 14E18);
        assert.equal(balance21, 1E18);
        assert.equal(balance22, 3E18);
    });

    it('rejects too big generation energy documentations', async function() {
        let balancePeriod = 1800596701;

        // Forwards must be created first so distributor is set.
        let abiCreateForwards = energyTokenWeb3.methods.createForwards(balancePeriod, 0, simpleDistributorWeb3.options.address).encodeABI();
        await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateForwards).send({from: accounts[5], gas: 7000000});

        // Zero must work.
        let abiUpdateEnergyDoc = energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[0].options.address, 0, balancePeriod).encodeABI();
        await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiUpdateEnergyDoc).send({from: accounts[8], gas: 7000000});

        // Must work right up to the maximum.
        abiUpdateEnergyDoc = energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[0].options.address, '75000000000000000000000', balancePeriod).encodeABI();
        await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiUpdateEnergyDoc).send({from: accounts[8], gas: 7000000});

        // Must not work for 1 above the maximum.
        abiUpdateEnergyDoc = energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[0].options.address, '75000000000000000000001', balancePeriod).encodeABI();
        await truffleAssert.reverts(meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiUpdateEnergyDoc).send({from: accounts[8], gas: 7000000}));
    });

    it('rejects too big consumption energy documentations', async function() {
        let balancePeriod = 1800596701;

        // Zero must work.
        let abiUpdateEnergyDoc = energyTokenWeb3.methods.addMeasuredEnergyConsumption(idcs[2].options.address, 0, balancePeriod).encodeABI();
        await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiUpdateEnergyDoc).send({from: accounts[8], gas: 7000000});

        // Must work right up to the maximum.
        abiUpdateEnergyDoc = energyTokenWeb3.methods.addMeasuredEnergyConsumption(idcs[2].options.address, '37500000000000000000000', balancePeriod).encodeABI();
        await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiUpdateEnergyDoc).send({from: accounts[8], gas: 7000000});

        // Must not work for 1 above the maximum.
        abiUpdateEnergyDoc = energyTokenWeb3.methods.addMeasuredEnergyConsumption(idcs[2].options.address, '37500000000000000000001', balancePeriod).encodeABI();
        await truffleAssert.reverts(meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiUpdateEnergyDoc).send({from: accounts[8], gas: 7000000}));
    });

    it('distributes tokens correctly (simple distributor).', async function() {
        // Set balance period different from any other balance period in the tests.
        let balancePeriod = 1800621001;
        let certificateIds = [];
    
        for(let forwardKind = 0; forwardKind <= 2; forwardKind++) {
            // Get certificate ID.
            let receivedCertificateId = await energyToken.getTokenId(3, balancePeriod + 9000*forwardKind, idcs[0].options.address, 0);

            // Pad token ID to full length.
            let receivedCertificateIdPadded = receivedCertificateId.toString('hex');
            while(receivedCertificateIdPadded.length < 64) {
                receivedCertificateIdPadded = '0' + receivedCertificateIdPadded;
            }
            certificateIds[forwardKind] = '0x' + receivedCertificateIdPadded;

            // Grant reception approval.
            await idcs[1].methods.approveSender(energyToken.address, simpleDistributorWeb3.options.address, '1958292001', '1700000000000000000000', certificateIds[forwardKind]).send({from: accounts[6], gas: 7000000});
        }

        // Determine forward IDs.
        let forwardIds = [];
        for(let forwardKind = 0; forwardKind <= 2; forwardKind++) {
            // Get forward ID.
            let receivedForwardId = await energyToken.getTokenId(forwardKind, balancePeriod + 9000*forwardKind, idcs[0].options.address, 0);

            // Pad token ID to full length.
            let receivedForwardIdPadded = receivedForwardId.toString('hex');
            while(receivedForwardIdPadded.length < 64) {
                receivedForwardIdPadded = '0' + receivedForwardIdPadded;
            }
            forwardIds[forwardKind] = '0x' + receivedForwardIdPadded;
        }

        // Mint forwards.
        for(let forwardKind = 0; forwardKind <= 2; forwardKind++) {
            let abiCreateForwards = energyTokenWeb3.methods.createForwards(balancePeriod + 9000*forwardKind, forwardKind, simpleDistributorWeb3.options.address).encodeABI();
            await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateForwards).send({from: accounts[5], gas: 7000000});
      
            if(forwardKind == 1)
                continue; // Generation-based forwards cannot be minted.

            // Grant reception approval.
            await idcs[1].methods.approveSender(energyToken.address, idcs[0].options.address, '1958292001', '17000000000000000000', forwardIds[forwardKind]).send({from: accounts[6], gas: 7000000});

            // Perform actual mint operation via execute() of IDC 0.
            let abiMintCall = energyTokenWeb3.methods.mint(forwardIds[forwardKind], [idcs[1].options.address], ['17000000000000000000']).encodeABI();
            await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiMintCall).send({from: accounts[5], gas: 8000000});
        }

        // Transfer generation-based forwards.
        await idcs[1].methods.approveSender(energyToken.address, idcs[0].options.address, '1958292001', '17000000000000000000', forwardIds[1]).send({from: accounts[6], gas: 7000000});
        let abiTransferGenerationBasedForwards = energyTokenWeb3.methods.safeTransferFrom(idcs[0].options.address, idcs[1].options.address, forwardIds[1], '17000000000000000000', '0x').encodeABI();
        await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransferGenerationBasedForwards).send({from: accounts[5], gas: 7000000});

        let distributeCall = async function(forwardKind) {
            await simpleDistributorWeb3.methods.distribute(idcs[1].options.address, forwardIds[forwardKind]).send({from: accounts[0], gas: 7000000});
        };

        // The certificate balance of IDC 1 must stay zero if all energy measurements are zero.
        // Deactivated because it would break the other (more important) tests as currently no tokens are minted when updating a measurement.
        /*
    for(let forwardKind = 0; forwardKind <= 2; forwardKind++) {
      let abiUpdateEnergyDoc = energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[0].options.address, 0, balancePeriod + 9000*forwardKind).encodeABI();
      await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiUpdateEnergyDoc).send({from: accounts[8], gas: 7000000});

      // Call distribute() function.
      if(forwardKind != 2) {
        await distributeCall(forwardKind);
      } else {
        await truffleAssert.reverts(distributeCall(forwardKind));
      }

      assert.equal(await energyToken.balanceOf(idcs[1].options.address, certificateIds[forwardKind]), 0);
    }
    */

        for(let forwardKind = 0; forwardKind <= 2; forwardKind++) {
            // Add energy generation.
            let abiAddGenerationCall1 = energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[0].options.address, '30000000000000000000', balancePeriod + 9000*forwardKind).encodeABI();
            await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddGenerationCall1).send({from: accounts[8], gas: 7000000});

            // Add energy consumption.
            let abiAddConsumptionCall1 = energyTokenWeb3.methods.addMeasuredEnergyConsumption(idcs[1].options.address, '8000000000000000000', balancePeriod + 9000*forwardKind).encodeABI();
            await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddConsumptionCall1).send({from: accounts[8], gas: 7000000});
        }

        // Run absolute distributor.
        await distributeCall(0);
        assert.equal(await energyToken.balanceOf(idcs[1].options.address, certificateIds[0]), '17000000000000000000');

        // Mint more absolute forwards.
        // Grant reception approval.
        await idcs[2].methods.approveSender(energyToken.address, idcs[0].options.address, '1958292001', '83000000000000000000', forwardIds[0]).send({from: accounts[7], gas: 7000000});

        // Perform actual mint operation via execute() of IDC 0.
        let abiMintCall = energyTokenWeb3.methods.mint(forwardIds[0], [idcs[2].options.address], ['83000000000000000000']).encodeABI();
        await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiMintCall).send({from: accounts[5], gas: 7000000});

        // Run absolute distributor again.
        await distributeCall(0);
        // 17000000000000000000+5100000000000000000 = 22100000000000000000
        assert.equal(await energyToken.balanceOf(idcs[1].options.address, certificateIds[0]), '22100000000000000000');

        // Test generation-based distributor.
        await distributeCall(1);
        assert.equal(await energyToken.balanceOf(idcs[1].options.address, certificateIds[1]), '5100000000000000000');

        // Test consumption-based distributor.
        await distributeCall(2);
        assert.equal(await energyToken.balanceOf(idcs[1].options.address, certificateIds[2]), '1360000000000000000');

        // Store the certificate ID because these certificates are needed for the test of the complex distributor.
        complexDistributorCertificateId = certificateIds[2];
        await idcs[0].methods.approveSender(energyToken.address, idcs[1].options.address, '1958292001', '1360000000000000000', complexDistributorCertificateId).send({from: accounts[5], gas: 7000000});
        const abiTransfer = energyTokenWeb3.methods.safeTransferFrom(idcs[1].options.address, idcs[0].options.address, complexDistributorCertificateId, '1360000000000000000', '0x').encodeABI();
        await idcs[1].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransfer).send({from: accounts[6], gas: 7000000});
    });

    it('Does not allow for transfer of certificates to the 0 address.', async function() {
        // Choose the same balance period as was used in the previous tests so the certificates can be re-used.
        let balancePeriod = 1800621001;
        let certificateIds = [];
    
        for(let forwardKind = 0; forwardKind <= 2; forwardKind++) {
            // Get certificate ID.
            let receivedCertificateId = await energyToken.getTokenId(3, balancePeriod + 9000*forwardKind, idcs[0].options.address, 0);

            // Pad token ID to full length.
            let receivedCertificateIdPadded = receivedCertificateId.toString('hex');
            while(receivedCertificateIdPadded.length < 64) {
                receivedCertificateIdPadded = '0' + receivedCertificateIdPadded;
            }
            certificateIds[forwardKind] = '0x' + receivedCertificateIdPadded;
        }

        // Make sure that certificates cannot be sent to the 0 address.
        let abiTransferCertsTo0Address = energyTokenWeb3.methods.safeTransferFrom(idcs[1].options.address, '0x0000000000000000000000000000000000000000', certificateIds[2], 333, '0x').encodeABI();
        await truffleAssert.reverts(idcs[1].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransferCertsTo0Address).send({from: accounts[6], gas: 7000000}));
    });

    it('distributes surplus certificates correctly.', async function() {
        let balancePeriod = 1800632701;
        let certificateIds = [];
    
        for(let forwardKind = 0; forwardKind <= 2; forwardKind++) {
            // Get certificate ID.
            let receivedCertificateId = await energyToken.getTokenId(3, balancePeriod + 9000*forwardKind, idcs[0].options.address, 0);

            // Pad token ID to full length.
            let receivedCertificateIdPadded = receivedCertificateId.toString('hex');
            while(receivedCertificateIdPadded.length < 64) {
                receivedCertificateIdPadded = '0' + receivedCertificateIdPadded;
            }
            certificateIds[forwardKind] = '0x' + receivedCertificateIdPadded;

            // Grant reception approval.
            await idcs[0].methods.approveSender(energyToken.address, simpleDistributorWeb3.options.address, '1958292001', '1700000000000000000000', certificateIds[forwardKind]).send({from: accounts[5], gas: 7000000});
            await idcs[1].methods.approveSender(energyToken.address, simpleDistributorWeb3.options.address, '1958292001', '1700000000000000000000', certificateIds[forwardKind]).send({from: accounts[6], gas: 7000000});
        }

        // Determine forward IDs.
        let forwardIds = [];
        for(let forwardKind = 0; forwardKind <= 2; forwardKind++) {
            // Get forward ID.
            let receivedForwardId = await energyToken.getTokenId(forwardKind, balancePeriod + 9000*forwardKind, idcs[0].options.address, 0);

            // Pad token ID to full length.
            let receivedForwardIdPadded = receivedForwardId.toString('hex');
            while(receivedForwardIdPadded.length < 64) {
                receivedForwardIdPadded = '0' + receivedForwardIdPadded;
            }
            forwardIds[forwardKind] = '0x' + receivedForwardIdPadded;
        }

        // Mint forwards.
        for(let forwardKind = 0; forwardKind <= 2; forwardKind++) {
            let abiCreateForwards = energyTokenWeb3.methods.createForwards(balancePeriod + 9000*forwardKind, forwardKind, simpleDistributorWeb3.options.address).encodeABI();
            await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateForwards).send({from: accounts[5], gas: 7000000});
      
            if(forwardKind == 1)
                continue; // Generation-based forwards cannot be minted.

            // Grant reception approval.
            await idcs[1].methods.approveSender(energyToken.address, idcs[0].options.address, '1958292001', '17000000000000000000', forwardIds[forwardKind]).send({from: accounts[6], gas: 7000000});

            // Perform actual mint operation via execute() of IDC 0.
            let abiMintCall = energyTokenWeb3.methods.mint(forwardIds[forwardKind], [idcs[1].options.address], ['17000000000000000000']).encodeABI();
            await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiMintCall).send({from: accounts[5], gas: 8000000});
        }

        let distributeCall = async function(forwardKind) {
            await simpleDistributorWeb3.methods.distribute(idcs[1].options.address, forwardIds[forwardKind]).send({from: accounts[0], gas: 7000000});
        };

        let documentationCall = async function(forwardKind) {
            let abiUpdateEnergyDoc = energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[0].options.address, '20000000000000000000', balancePeriod + 9000*forwardKind).encodeABI();
            await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiUpdateEnergyDoc).send({from: accounts[8], gas: 7000000});

            abiUpdateEnergyDoc = energyTokenWeb3.methods.addMeasuredEnergyConsumption(idcs[1].options.address, '10000000000000000000', balancePeriod + 9000*forwardKind).encodeABI();
            await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiUpdateEnergyDoc).send({from: accounts[8], gas: 7000000});
        };

        let surplusWithdrawalCall = async function (forwardKind) {
            await simpleDistributorWeb3.methods.withdrawSurplusCertificates(forwardIds[forwardKind]).send({from: accounts[0], gas: 7000000});
        };
    
        // For absolute forwards, surplus withdrawal must work immediately after documentation.
        await documentationCall(0);
        await surplusWithdrawalCall(0);
        // Distribution still needs to work after surplus distribution.
        await distributeCall(0);

        // For generation-based forwards, surplus withdrawal must revert.
        await documentationCall(1);
        await truffleAssert.reverts(surplusWithdrawalCall(1));
        // But distribution needs to work nonetheless.
        await distributeCall(1);

        // For consumption-based forwards, surplus withdrawal must not work before all distributions have occurred.
        await documentationCall(2);
        await truffleAssert.reverts(surplusWithdrawalCall(2));
        await distributeCall(2);
        await surplusWithdrawalCall(2);
    });

    it('accepts documentations without forwards having been created.', async function() {
        const balancePeriod = 1800815401;
    
        const abiUpdateEnergyDoc = energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[0].options.address, '20000000000000000000', balancePeriod).encodeABI();
        await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiUpdateEnergyDoc).send({from: accounts[8], gas: 7000000});

        // Determine certificate IDs.
        let certificateId = await energyToken.getTokenId(3, balancePeriod, idcs[0].options.address, 0);

        // Pad token ID to full length.
        certificateId = certificateId.toString('hex');
        while(certificateId.length < 64) {
            certificateId = '0' + certificateId;
        }
        certificateId = '0x' + certificateId;

        // Check balance.
        const balance = await energyToken.balanceOf(idcs[0].options.address, certificateId);
        assert.equal(balance, '20000000000000000000');
    });

    it('keeps track of energy data.', async function() {
        let json = '{ "q": "ab", "expiryDate": "1958292001", "startDate": "1", "realWorldPlantId": "bestPlantId" }';
        let data = web3.utils.toHex(json);
        await addClaim(idcs[2], 10070, physicalAssetAuthority.options.address, data, '', account8Sk);
        await addClaim(idcs[2], 10080, physicalAssetAuthority.options.address, data, '', account8Sk);

        let balancePeriod = 1958292001;

        // The call must revert if it comes from something that's not a metering authority's IDC (even if it's by the metering authority directly).
        let abiAddConsumptionCall1 = energyTokenWeb3.methods.addMeasuredEnergyConsumption(idcs[1].options.address, 500, balancePeriod).encodeABI();

        await truffleAssert.reverts(idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiAddConsumptionCall1).send({from: accounts[5], gas: 7000000}));

        await truffleAssert.reverts(energyTokenWeb3.methods.addMeasuredEnergyConsumption(idcs[1].options.address, 500, balancePeriod).send({from: accounts[8], gas: 7000000}));
    
        await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddConsumptionCall1).send({from: accounts[8], gas: 7000000});

        // It needs to be possible to update the value.
        let abiAddConsumptionCall2 = energyTokenWeb3.methods.addMeasuredEnergyConsumption(idcs[1].options.address, 335, balancePeriod).encodeABI();
        await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddConsumptionCall2).send({from: accounts[8], gas: 7000000});

        // It needs to be possible to update the value again.
        let abiAddConsumptionCall3 = energyTokenWeb3.methods.addMeasuredEnergyConsumption(idcs[1].options.address, 1335, balancePeriod).encodeABI();
        await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddConsumptionCall3).send({from: accounts[8], gas: 7000000});

        // And again.
        let abiAddConsumptionCall4 = energyTokenWeb3.methods.addMeasuredEnergyConsumption(idcs[1].options.address, 2335, balancePeriod).encodeABI();
        await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddConsumptionCall4).send({from: accounts[8], gas: 7000000});

        let energyConsumptionDocumentation = await energyTokenWeb3.methods.energyDocumentations(idcs[1].options.address, balancePeriod).call();
        assert.equal(energyConsumptionDocumentation.documentingMeteringAuthority, meteringAuthority.options.address);

        // All the same goes for energy generation except forwards need to be created prior to energy documentation.
        let abiCreateForwardsCall = energyTokenWeb3.methods.createForwards(balancePeriod, 2, simpleDistributor.address).encodeABI();
        await idcs[2].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateForwardsCall).send({from: accounts[7], gas: 7000000});

        // The call must revert if it comes from something that's not a metering authority's IDC (even if it's by the metering authority directly).
        let abiAddGenerationCall1 = energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[2].options.address, 500, balancePeriod).encodeABI();
        await truffleAssert.reverts(idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiAddGenerationCall1).send({from: accounts[5], gas: 7000000}));
        await truffleAssert.reverts(energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[2].options.address, 500, balancePeriod).send({from: accounts[8], gas: 7000000}));

        await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddGenerationCall1).send({from: accounts[8], gas: 7000000});

        // It needs to be possible to update the value.
        let abiAddGenerationCall2 = energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[2].options.address, 335, balancePeriod).encodeABI();
        await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddGenerationCall2).send({from: accounts[8], gas: 7000000});

        // It needs to be possible to update the value again.
        let abiAddGenerationCall3 = energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[2].options.address, 1335, balancePeriod).encodeABI();
        await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddGenerationCall3).send({from: accounts[8], gas: 7000000});

        // And again.
        let abiAddGenerationCall4 = energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[2].options.address, 2335, balancePeriod).encodeABI();
        await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddGenerationCall4).send({from: accounts[8], gas: 7000000});

        // Total consumed energy needs to check out despite of correctitions.
        assert.equal((await energyToken.energyDocumentations(idcs[2].options.address, balancePeriod)).value, 2335);

        // Non-corrected values count too.
        let abiAddConsumptionCall6 = energyTokenWeb3.methods.addMeasuredEnergyConsumption(idcs[0].options.address, 10000, balancePeriod).encodeABI();
        await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddConsumptionCall6).send({from: accounts[8], gas: 7000000});

        assert.equal((await energyToken.energyDocumentations(idcs[0].options.address, balancePeriod)).value, 10000);

        let energyConsumptionDocumentation2 = await energyTokenWeb3.methods.energyDocumentations(idcs[0].options.address, balancePeriod).call();
        assert.equal(energyConsumptionDocumentation2.documentingMeteringAuthority, meteringAuthority.options.address);

        let energyGenerationDocumentation = await energyTokenWeb3.methods.energyDocumentations(idcs[2].options.address, balancePeriod).call();
        assert.equal(energyGenerationDocumentation.documentingMeteringAuthority, meteringAuthority.options.address);
    });

    it('can create property forwards.', async function() {
        const balancePeriodCertificates = 1800621001;
        const balancePeriodPropertyForwards = balancePeriodCertificates + 2*9000 + 15*60;

        // Before property forwards can be created, IDC 0 (previously a generation plant) needs to become a storage plant.
        const jsonExistenceStorage = '{ "type": "storage", "expiryDate": "1958292001", "startDate": "1", "realWorldPlantId": "bestPlantId" }';
        const dataExistenceStorage = web3.utils.toHex(jsonExistenceStorage);
        const jsonMaxCon = '{ "maxCon": "150000000", "expiryDate": "1958292001", "startDate": "1", "realWorldPlantId": "bestPlantId" }';
        const dataMaxCon = web3.utils.toHex(jsonMaxCon);

        await addClaimViaIdc(idcs[0], 10060, physicalAssetAuthority.options.address, dataExistenceStorage, '', account8Sk, accounts[5]);
        await addClaimViaIdc(idcs[0], 10140, physicalAssetAuthority.options.address, dataMaxCon, '', account8Sk, accounts[5]);

        const abiCreateForwardsCall1 = energyTokenWeb3.methods.createPropertyForwards(balancePeriodPropertyForwards, complexDistributor.address, [[10065, 'maxGen', 0, '0x' + Buffer.from('300000000', 'utf8').toString('hex')]]).encodeABI();
        await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateForwardsCall1).send({from: accounts[5], gas: 7000000});

        // Make sure that repeated calls revert as forwards cannot be created more than once.
        await truffleAssert.reverts(idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateForwardsCall1).send({from: accounts[5], gas: 7000000}));

        // It needs to be possible to create more than one forward per storage plant and balance period.
        const abiCreateForwardsCall2 = energyTokenWeb3.methods.createPropertyForwards(balancePeriodPropertyForwards, complexDistributor.address, [[10065, 'maxGen', 1, '0x' + Buffer.from('300000000', 'utf8').toString('hex')]]).encodeABI();
        await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateForwardsCall2).send({from: accounts[5], gas: 7000000});

        const abiCreateForwardsCall3 = energyTokenWeb3.methods.createPropertyForwards(balancePeriodPropertyForwards, complexDistributor.address, [[10065, 'maxGen', 2, '0x' + Buffer.from('300000000', 'utf8').toString('hex')]]).encodeABI();
        await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateForwardsCall3).send({from: accounts[5], gas: 7000000});

        const abiCreateForwardsCall4 = energyTokenWeb3.methods.createPropertyForwards(balancePeriodPropertyForwards, complexDistributor.address, [[10065, 'maxGen', 0, '0x' + Buffer.from('300000001', 'utf8').toString('hex')]]).encodeABI();
        await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateForwardsCall4).send({from: accounts[5], gas: 7000000});

        const abiCreateForwardsCall5 = energyTokenWeb3.methods.createPropertyForwards(balancePeriodPropertyForwards, complexDistributor.address, [[10065, 'maxGen', 1, '0x' + Buffer.from('300000001', 'utf8').toString('hex')]]).encodeABI();
        await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateForwardsCall5).send({from: accounts[5], gas: 7000000});

        const abiCreateForwardsCall6 = energyTokenWeb3.methods.createPropertyForwards(balancePeriodPropertyForwards, complexDistributor.address, [[10065, 'maxGen', 2, '0x' + Buffer.from('300000001', 'utf8').toString('hex')]]).encodeABI();
        await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateForwardsCall6).send({from: accounts[5], gas: 7000000});

        const abiCreateForwardsCall7 = energyTokenWeb3.methods.createPropertyForwards(balancePeriodPropertyForwards, complexDistributor.address, [[10065, 'maxGen', 0, '0x' + Buffer.from('299999999', 'utf8').toString('hex')]]).encodeABI();
        await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateForwardsCall7).send({from: accounts[5], gas: 7000000});

        const abiCreateForwardsCall8 = energyTokenWeb3.methods.createPropertyForwards(balancePeriodPropertyForwards, complexDistributor.address, [[10065, 'maxGen', 1, '0x' + Buffer.from('299999999', 'utf8').toString('hex')]]).encodeABI();
        await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateForwardsCall8).send({from: accounts[5], gas: 7000000});

        const abiCreateForwardsCall9 = energyTokenWeb3.methods.createPropertyForwards(balancePeriodPropertyForwards, complexDistributor.address, [[10065, 'maxGen', 2, '0x' + Buffer.from('299999999', 'utf8').toString('hex')]]).encodeABI();
        await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateForwardsCall9).send({from: accounts[5], gas: 7000000});
    });

    it('distributes tokens correcty (complex distributor)', async function() {
        // IDC 0: storage plant
        // IDC 1: consumption plant

        const balancePeriodCertificates = 1800621001;
        const balancePeriodPropertyForwards = balancePeriodCertificates + 2*9000 + 15*60;

        // Document that the storage plant has generated the energy.
        let abiAddGenerationCall1 = energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[0].options.address, '30000000000000000000', balancePeriodPropertyForwards).encodeABI();
        await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddGenerationCall1).send({from: accounts[8], gas: 7000000});

        // Define criteria testsets (1 test run for each element of the test set).
        const criteriaTestset = [
            [[10065, 'maxGen', 0, '0x' + Buffer.from('300000000', 'utf8').toString('hex')]],
            [[10065, 'maxGen', 1, '0x' + Buffer.from('300000000', 'utf8').toString('hex')]],
            [[10065, 'maxGen', 2, '0x' + Buffer.from('300000000', 'utf8').toString('hex')]],
            [[10065, 'maxGen', 1, '0x' + Buffer.from('300000001', 'utf8').toString('hex')]],
            [[10065, 'maxGen', 2, '0x' + Buffer.from('299999999', 'utf8').toString('hex')]],
        ];

        const criteriaNotApplicableTestset = [
            [[10065, 'maxGen', 0, '0x' + Buffer.from('300000001', 'utf8').toString('hex')]],
            [[10065, 'maxGen', 2, '0x' + Buffer.from('300000001', 'utf8').toString('hex')]],
            [[10065, 'maxGen', 1, '0x' + Buffer.from('299999999', 'utf8').toString('hex')]],
        ];

        const distributeCall = async function(fId, value) {
            await complexDistributorWeb3.methods.distribute(idcs[1].options.address, '0x' + fId, complexDistributorCertificateId, value).send({from: accounts[0], gas: 7000000});
        };


        for(const criteriaNotApplicable of criteriaNotApplicableTestset) {
            const criteriaHashNotApplicable = await energyToken.getCriteriaHash(criteriaNotApplicable);
            let forwardIdNotApplicable = (await energyToken.getPropertyTokenId(balancePeriodPropertyForwards, idcs[0].options.address, 0, criteriaHashNotApplicable)).toString('hex');
            // Pad forward ID to 32 Byte.
            while(forwardIdNotApplicable.length < 64) {
                forwardIdNotApplicable = '0' + forwardIdNotApplicable;
            }

            // The transfer needs to fail for a non-applicable forward ID.
            const abiTransferCallNotApplicable = energyTokenWeb3.methods.safeTransferFrom(idcs[0].options.address, complexDistributor.address, complexDistributorCertificateId, 500, '0x' + forwardIdNotApplicable).encodeABI();
            await truffleAssert.reverts(idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransferCallNotApplicable).send({from: accounts[5], gas: 7000000}));

            // Grant reception approval.
            await idcs[1].methods.approveSender(energyToken.address, idcs[0].options.address, '1958292001', '150', '0x' + forwardIdNotApplicable).send({from: accounts[6], gas: 7000000});

            // Mint.
            let abiMintCallNotApplicable = energyTokenWeb3.methods.mint('0x' + forwardIdNotApplicable, [idcs[1].options.address], ['150']).encodeABI();
            await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiMintCallNotApplicable).send({from: accounts[5], gas: 8000000});

            // Distribution needs to fail when using the non-applicable token ID.
            await truffleAssert.reverts(distributeCall(forwardIdNotApplicable, 100));
        }

        for(const criteria of criteriaTestset) {
            // Using a smart contract function for this because
            // web3.utils.soliditySha3({type: 'tuple(uint256,string,uint8,bytes)[]', value: [ [...] ]})
            // does not work.
            const criteriaHash = await energyToken.getCriteriaHash(criteria);
            let forwardId = (await energyToken.getPropertyTokenId(balancePeriodPropertyForwards, idcs[0].options.address, 0, criteriaHash)).toString('hex');

            // Pad forward ID to 32 Byte.
            while(forwardId.length < 64) {
                forwardId = '0' + forwardId;
            }

            // Transfer certificates to the distributor.
            const abiTransferCall = energyTokenWeb3.methods.safeTransferFrom(idcs[0].options.address, complexDistributor.address, complexDistributorCertificateId, 500, '0x' + forwardId).encodeABI();
            await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransferCall).send({from: accounts[5], gas: 7000000});

            // Grant reception approval.
            await idcs[1].methods.approveSender(energyToken.address, idcs[0].options.address, '1958292001', '150', '0x' + forwardId).send({from: accounts[6], gas: 7000000});

            // Perform mint operation via execute() of IDC 0.
            let abiMintCall = energyTokenWeb3.methods.mint('0x' + forwardId, [idcs[1].options.address], ['150']).encodeABI();
            await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiMintCall).send({from: accounts[5], gas: 8000000});
      
            // Partial distribution needs to work.
            await distributeCall(forwardId, 100);

            // Distribution beyond the number of forwards owned needs to fail.
            await truffleAssert.reverts(distributeCall(forwardId, 100));

            // Remaining distribution needs to work.
            await distributeCall(forwardId, 50);
        }
    });
});
