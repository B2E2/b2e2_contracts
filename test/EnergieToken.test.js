'use strict';

const truffleAssert = require('truffle-assertions');
const eutil = require('ethereumjs-util');

const account5Sk = "0x533a905ac396ca2857e36fcb29a6361e86a3d131fd126b179a230a457c1abdd1";
const account6Sk = "0x294dcf7158a75155458ab3cc50d044d498f07d0a0e5ae6d140addb5e5f4e9360";
const account7Sk = "0x547fa26372d75d470a292c0a3e77f576bfb17a7bebd0fb686bea5700c476c5f8";
const account8Sk = "0x56f01dc407e7462c8a47d048c35cd61794f2893696ec4aaafcc46cd33a22cd58";
const account9Sk = "0x5b1b39d1cf63bdef178e6ad182b1ae852ac6b26a802121ab2c4df936665731d8";

let accounts;

var IdentityContract = artifacts.require("./IdentityContract.sol");
var IdentityContractLib = artifacts.require("./IdentityContractLib.sol");
var IdentityContractFactory = artifacts.require("./IdentityContractFactory.sol");
var identityContractFactory;
var marketAuthority;
var balanceAuthority;
var meteringAuthority;
var physicalAssetAuthority;
var idcs = [];

var EnergyToken = artifacts.require("./EnergyToken.sol");
var energyToken;
var energyTokenWeb3;

var Distributor = artifacts.require("./Distributor.sol");
var distributor;
var distributorWeb3;

contract('EnergyToken', function(accounts) {

  before(async function() {
	accounts = await web3.eth.getAccounts();

    marketAuthority = await IdentityContract.new("0x0000000000000000000000000000000000000000", 900, accounts[9], {from: accounts[9]});
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

	let json = '{ "q": "ab", "expiryDate": "1895220001", "startDate": "1" }';
	let data = web3.utils.toHex(json);
	await addClaim(balanceAuthority, 10010, marketAuthority.address, data, "", account9Sk);
	await addClaim(meteringAuthority, 10020, marketAuthority.address, data, "", account9Sk);
	await addClaim(physicalAssetAuthority, 10030, marketAuthority.address, data, "", account9Sk);
	
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
	
	distributor = await Distributor.new(energyToken.address, true, accounts[0]);
	distributorWeb3 = new web3.eth.Contract(Distributor.abi, distributor.address);
	console.log(`Successfully deployed Distributor with address: ${distributor.address}`);
  });

  async function addClaim(subject, topic, issuerAddress, data, uri, signingKey) {
	// Handle difference between Truffle contract object and web3 contract object.
	let isWeb3Contract = false;
	let subjectAddress = subject.address;
	if(subjectAddress === undefined) {
	  isWeb3Contract = true;
	  subjectAddress = subject.options.address;
	}
	
	let hash = web3.utils.soliditySha3(subjectAddress, topic, data);
	let signatureSplit = await eutil.ecsign(new Buffer(hash.slice(2), "hex"), new Buffer(signingKey.slice(2), "hex"));
	let signatureMerged = '0x' + signatureSplit.r.toString('hex') + signatureSplit.s.toString('hex') + signatureSplit.v.toString(16);

	if(!isWeb3Contract) {
	  await subject.addClaim(topic, 1, issuerAddress, signatureMerged, data, uri);
	} else {
	  await subject.methods.addClaim(topic, 1, issuerAddress, signatureMerged, data, uri).send({from: accounts[0], gas: 7000000});
	}
  }

  it("determines token IDs correctly.", async function() {
	// Get token ID.
	let receivedTokenId = await energyToken.getTokenId(2, 1579860001, "0x7f10C80B27f9D4E8524748f2b31cAc86069f6C49");

	// Pad token ID to full length.
	let receivedTokenIdPadded = receivedTokenId.toString('hex');
	while(receivedTokenIdPadded.length < 64) {
	  receivedTokenIdPadded = "0" + receivedTokenIdPadded;
	}
	
	// Determine expected token ID.
	let zeros = "000000";
	let tokenKind = "03"; // A consumption-based forward is stated as a 2 when calling functions (position in the enum listing) but it is rerpesented as "03" (last 2 bits set (relative, consumption-based)).
	let balancePeriod = "000000005e2ac021";
	let addressOfIdc = "7f10C80B27f9D4E8524748f2b31cAc86069f6C49".toLowerCase();
    let expectedTokenId = zeros + tokenKind + balancePeriod + addressOfIdc;
	assert.equal(receivedTokenIdPadded, expectedTokenId);
  });

  it("converts between uints an enums.", async function() {
	let tokenIds = [0, 2, 3, 4];
	for (let i = 0; i < 4; i++) {
	  assert.equal(await energyToken.tokenKind2Number(i), tokenIds[i]);
	  assert.equal(await energyToken.number2TokenKind(tokenIds[i]), i);
	}
  });

  it("can mint tokens.", async function() {
	// IDC 0 is the generation plant.
	// IDC 2 is the token recipient.

	// Claim necessary for receiving.
	let jsonAcceptedDistributor = '{ "t": "t", "expiryDate": "1895220001", "startDate": "1", "address": "' + idcs[2].options.address.slice(2).toLowerCase() + '" }';
	let dataAcceptedDistributor = web3.utils.toHex(jsonAcceptedDistributor);
	await addClaim(distributor, 10120, balanceAuthority.options.address, dataAcceptedDistributor, "", account8Sk);

	// Give claims to IDC 0.
	const json = '{ "q": "ab", "expiryDate": "1895220001", "startDate": "1", "realWorldPlantId": "bestPlantId" }';
	const data = web3.utils.toHex(json);
    const jsonExistenceGeneration = '{ "type": "generation", "expiryDate": "1895220001", "startDate": "1", "realWorldPlantId": "bestPlantId" }';
	const dataExistenceGeneration = web3.utils.toHex(jsonExistenceGeneration);
    const jsonMaxGen = '{ "maxGen": "300000000", "expiryDate": "1895220001", "startDate": "1", "realWorldPlantId": "bestPlantId" }';
    const dataMaxGen = web3.utils.toHex(jsonMaxGen);
    const jsonMaxCon = '{ "maxCon": "150000000", "expiryDate": "1895220001", "startDate": "1", "realWorldPlantId": "bestPlantId" }';
    const dataMaxCon = web3.utils.toHex(jsonMaxCon);

    await addClaim(idcs[0], 10130, idcs[0].options.address, data, "", account5Sk);
	await addClaim(idcs[0], 10050, balanceAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[0], 10060, physicalAssetAuthority.options.address, dataExistenceGeneration, "", account8Sk);
	await addClaim(idcs[0], 10070, physicalAssetAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[0], 10080, physicalAssetAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[0], 10040, meteringAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[0], 10065, physicalAssetAuthority.options.address, dataMaxGen, "", account8Sk);

	// Give claims to IDC 2.
    await addClaim(idcs[2], 10130, idcs[2].options.address, data, "", account7Sk);
	await addClaim(idcs[2], 10040, meteringAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[2], 10050, balanceAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[2], 10060, physicalAssetAuthority.options.address, dataExistenceGeneration, "", account8Sk);
	await addClaim(idcs[2], 10065, physicalAssetAuthority.options.address, dataMaxGen, "", account8Sk);
	await addClaim(idcs[2], 10140, physicalAssetAuthority.options.address, dataMaxCon, "", account8Sk);

	// Get token ID.
	let receivedTokenId = await energyToken.getTokenId(2, 1737540001, idcs[0].options.address);

	// Pad token ID to full length.
	let receivedTokenIdPadded = receivedTokenId.toString('hex');
	while(receivedTokenIdPadded.length < 64) {
	  receivedTokenIdPadded = "0" + receivedTokenIdPadded;
	}
	let id = "0x" + receivedTokenIdPadded;

	// Grant reception approval.
	idcs[2].methods.approveSender(energyToken.address, idcs[0].options.address, "1895220001", "17000000000000000000", id).send({from: accounts[7], gas: 7000000});

	// Create forwards.
	let abiCreateForwardsCall = energyTokenWeb3.methods.createForwards(1737540001, 2, distributor.address).encodeABI();
	await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateForwardsCall).send({from: accounts[5], gas: 7000000});

	// Perform actual mint operation via execute() of IDC 0.
	let abiMintCall = energyTokenWeb3.methods.mint(id, [idcs[2].options.address], ["17000000000000000000"]).encodeABI();
	await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiMintCall).send({from: accounts[5], gas: 7000000});

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

  it("can create generation-based forwards.", async function() {
	let balancePeriod = "1895220001";
	let abiCreateTokensCall = energyTokenWeb3.methods.createForwards(balancePeriod, 1, idcs[1].options.address).encodeABI();
	let callResult = await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateTokensCall).send({from: accounts[5], gas: 7000000});

	// Make sure that repeated calls revert as each generation-based forward cannot be created more than once.
	await truffleAssert.reverts(idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateTokensCall).send({from: accounts[5], gas: 7000000}));

	// I can't get the return value because this is run via execute. It also wouldn't work anyway because web3 is stupid. Furthermore, I wasn't able to figure out how to get the event from web3. It doesn't work the way events can be retrieved using truffle contract objects and everything I've tried yielded null, undefined, an empty array, or other thing that just didn't make any sense. So I need to either compute the token ID here or get it via another function call.
	let id = await energyToken.getTokenId(1, balancePeriod, idcs[0].options.address);

	assert.equal(await energyToken.balanceOf(idcs[0].options.address, id), 100E18);
	assert.equal(await energyToken.balanceOf(idcs[1].options.address, id), 0);
  });

  it("can transfer tokens.", async function() {
	// IDC 2 has 17 tokens (17E18 elementary units) from the mint operation.

	// Get token ID.
	let receivedTokenId = await energyToken.getTokenId(2, 1737540001, idcs[0].options.address);

	// Pad token ID to full length.
	let receivedTokenIdPadded = receivedTokenId.toString('hex');
	while(receivedTokenIdPadded.length < 64) {
	  receivedTokenIdPadded = "0" + receivedTokenIdPadded;
	}
	let id = "0x" + receivedTokenIdPadded;

	// Grant reception approval for sending 12 tokens from IDC 2 to IDC 1.
	let abiApproveSenderCall = idcs[1].methods.approveSender(energyToken.address, idcs[2].options.address, "1895220001", "5000000000000000000", id).encodeABI();
	await idcs[1].methods.execute(0, idcs[1].options.address, 0, abiApproveSenderCall).send({from: accounts[6], gas: 7000000});

	// Before the transfer can happen, some claims need to be issued and published.
	// Claims necessary for sending.
	let json = '{ "q": "ab", "expiryDate": "1895220001", "startDate": "1", "realWorldPlantId": "bestPlantId" }';
	let data = web3.utils.toHex(json);
    const jsonMaxCon = '{ "maxCon": "150000000", "expiryDate": "1895220001", "startDate": "1", "realWorldPlantId": "bestPlantId" }';
    const dataMaxCon = web3.utils.toHex(jsonMaxCon);	
    await addClaim(idcs[1], 10130, idcs[1].options.address, data, "", account6Sk);
	await addClaim(idcs[1], 10050, balanceAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[1], 10060, physicalAssetAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[1], 10070, physicalAssetAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[1], 10080, physicalAssetAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[1], 10040, meteringAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[1], 10140, physicalAssetAuthority.options.address, dataMaxCon, "", account8Sk);

	// Claims necessary for receiving.
	await addClaim(idcs[1], 10050, balanceAuthority.options.address, data, "", account8Sk);

	// Claim necessary for receiving.
	let jsonAcceptedDistributor = '{ "t": "t", "expiryDate": "1895220001", "startDate": "1", "address": "' + idcs[1].options.address.slice(2).toLowerCase() + '" }';
	let dataAcceptedDistributor = web3.utils.toHex(jsonAcceptedDistributor);
	await addClaim(idcs[1], 10120, balanceAuthority.options.address, dataAcceptedDistributor, "", account8Sk);

	// Send 5 tokens.
	let abiTransfer = energyTokenWeb3.methods.safeTransferFrom(idcs[2].options.address, idcs[1].options.address, id, "5000000000000000000", "0x00").encodeABI();
	await idcs[2].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransfer).send({from: accounts[7], gas: 7000000});

	// Repeated transfers are prohibited. So the the same transfer again has to fail.
	await truffleAssert.reverts(idcs[2].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransfer).send({from: accounts[7], gas: 7000000}));

	// Make sure that the balances are correct.
	let balance1 = await energyToken.balanceOf(idcs[1].options.address, id);
	let balance2 = await energyToken.balanceOf(idcs[2].options.address, id);
	assert.equal(balance1, 5E18);
	assert.equal(balance2, 12E18);

	// Upper edge case.
	let abiTransferUpper = energyTokenWeb3.methods.safeTransferFrom(idcs[2].options.address, idcs[1].options.address, id, "2000000000000000001", "0x00").encodeABI();
	await truffleAssert.reverts(idcs[2].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransferUpper).send({from: accounts[7], gas: 7000000}));

	// Lower edge case.
	let abiTransferLower = energyTokenWeb3.methods.safeTransferFrom(idcs[2].options.address, idcs[1].options.address, id, "1999999999999999999", "0x00").encodeABI();
	await truffleAssert.reverts(idcs[2].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransferLower).send({from: accounts[7], gas: 7000000}));

	// Verify that the balanced remained the same.
	balance1 = await energyToken.balanceOf(idcs[1].options.address, id);
	balance2 = await energyToken.balanceOf(idcs[2].options.address, id);
	assert.equal(balance1, 5E18);
	assert.equal(balance2, 12E18);

	// Self-transfers are not allowed without reception approval.
	let abiTransferSelf1 = energyTokenWeb3.methods.safeTransferFrom(idcs[2].options.address, idcs[2].options.address, id, "5000000000000000000", "0x00").encodeABI();
	await truffleAssert.reverts(idcs[2].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransferSelf1).send({from: accounts[7], gas: 7000000}));

	// Transferring tokens to a receiver without the necessary claims needs to fail.
	let abiApproveSenderCallDistributor = distributorWeb3.methods.approveSender(energyToken.address, idcs[2].options.address, "1895220001", "1000000000000000000", id).encodeABI();
	await distributorWeb3.methods.execute(0, distributorWeb3.options.address, 0, abiApproveSenderCallDistributor).send({from: accounts[0], gas: 7000000});
	let abiTransferToDistributor = energyTokenWeb3.methods.safeTransferFrom(idcs[2].options.address, distributorWeb3.options.address, id, "1000000000000000000", "0x00").encodeABI();
	await truffleAssert.reverts(idcs[2].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransferToDistributor).send({from: accounts[7], gas: 7000000}));
  });

  it("can perform batch transfers.", async function() {
	// Get token ID of forward. Using a different balance period to get balances back to zero.
	let receivedTokenId1 = await energyToken.getTokenId(2, 1737540901, idcs[0].options.address);

	// Pad token ID to full length.
	let receivedTokenId1Padded = receivedTokenId1.toString('hex');
	while(receivedTokenId1Padded.length < 64) {
	  receivedTokenId1Padded = "0" + receivedTokenId1Padded;
	}
	let id1 = "0x" + receivedTokenId1Padded;

	// Get token ID of another forward.
	let receivedTokenId2 = await energyToken.getTokenId(2, 1737549901, idcs[0].options.address);

	// Pad token ID to full length.
	let receivedTokenId2Padded = receivedTokenId2.toString('hex');
	while(receivedTokenId2Padded.length < 64) {
	  receivedTokenId2Padded = "0" + receivedTokenId2Padded;
	}
	let id2 = "0x" + receivedTokenId2Padded;

	// Reception approval for receiving minted forwards.
	let abiApproveSenderCall11 = idcs[1].methods.approveSender(energyToken.address, idcs[0].options.address, "1895220001", "17000000000000000000", id1).encodeABI();
	await idcs[1].methods.execute(0, idcs[1].options.address, 0, abiApproveSenderCall11).send({from: accounts[6], gas: 7000000});
	let abiApproveSenderCall12 = idcs[1].methods.approveSender(energyToken.address, idcs[0].options.address, "1895220001", "17000000000000000000", id2).encodeABI();
	await idcs[1].methods.execute(0, idcs[1].options.address, 0, abiApproveSenderCall12).send({from: accounts[6], gas: 7000000});

	// Forwards creation.
	let abiCreateForwardsCall1 = energyTokenWeb3.methods.createForwards(1737540901, 2, distributor.address).encodeABI();
	await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateForwardsCall1).send({from: accounts[5], gas: 7000000});
	let abiCreateForwardsCall2 = energyTokenWeb3.methods.createForwards(1737549901, 2, distributor.address).encodeABI();
	await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateForwardsCall2).send({from: accounts[5], gas: 7000000});

	// Minting.
	let abiMintCall1 = energyTokenWeb3.methods.mint(id1, [idcs[1].options.address], ["17000000000000000000"]).encodeABI();
	await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiMintCall1).send({from: accounts[5], gas: 7000000});
	let abiMintCall2 = energyTokenWeb3.methods.mint(id2, [idcs[1].options.address], ["17000000000000000000"]).encodeABI();
	await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiMintCall2).send({from: accounts[5], gas: 7000000});

	// Reception approval is required for forwards.
	let abiApproveSenderCall21 = idcs[2].methods.approveSender(energyToken.address, idcs[1].options.address, "1895220001", "1000000000000000000", id1).encodeABI();
	await idcs[2].methods.execute(0, idcs[2].options.address, 0, abiApproveSenderCall21).send({from: accounts[7], gas: 7000000});
	let abiApproveSenderCall22 = idcs[2].methods.approveSender(energyToken.address, idcs[1].options.address, "1895220001", "3000000000000000000", id2).encodeABI();
	await idcs[2].methods.execute(0, idcs[2].options.address, 0, abiApproveSenderCall22).send({from: accounts[7], gas: 7000000});

	// Transfer.
	let abiBatchTransfer = energyTokenWeb3.methods.safeBatchTransferFrom(idcs[1].options.address, idcs[2].options.address, [id1, id2], ["1000000000000000000", "3000000000000000000"], "0x00").encodeABI();
	await idcs[1].methods.execute(0, energyTokenWeb3.options.address, 0, abiBatchTransfer).send({from: accounts[6], gas: 9000000});

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

  it("rejects too big energy documentations", async function() {
    let balancePeriod = 1737524701;

    // Forwards must be created first so distributor is set.
    let abiCreateForwards = energyTokenWeb3.methods.createForwards(balancePeriod, 0, distributorWeb3.options.address).encodeABI();
	await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateForwards).send({from: accounts[5], gas: 7000000});

    // Zero must work.
    let abiUpdateEnergyDoc = energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[0].options.address, 0, balancePeriod).encodeABI();
	await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiUpdateEnergyDoc).send({from: accounts[8], gas: 7000000});

    // Must work right up to the maximum.
    abiUpdateEnergyDoc = energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[0].options.address, "75000000000000000000000", balancePeriod).encodeABI();
	await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiUpdateEnergyDoc).send({from: accounts[8], gas: 7000000});

    // Must not work for 1 above the maximum.
    abiUpdateEnergyDoc = energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[0].options.address, "75000000000000000000001", balancePeriod).encodeABI();
	await truffleAssert.reverts(meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiUpdateEnergyDoc).send({from: accounts[8], gas: 7000000}));
  });

  it("distributes tokens correctly.", async function() {
	// Make the distributor an accepted distributor.
	let jsonAcceptedDistributor = '{ "t": "t", "expiryDate": "1895220001", "startDate": "1", "address": "' + distributorWeb3.options.address.slice(2).toLowerCase() + '" }';
	let dataAcceptedDistributor = web3.utils.toHex(jsonAcceptedDistributor);
	await addClaim(distributorWeb3, 10120, balanceAuthority.options.address, dataAcceptedDistributor, "", account8Sk);

	// Set balance period different from any other balance period in the tests.
	let balancePeriod = 1737549001;
	let certificateIds = [];
	
	for(let forwardKind = 0; forwardKind <= 2; forwardKind++) {
	  // Get certificate ID.
	  let receivedCertificateId = await energyToken.getTokenId(3, balancePeriod + 9000*forwardKind, idcs[0].options.address);

	  // Pad token ID to full length.
	  let receivedCertificateIdPadded = receivedCertificateId.toString('hex');
	  while(receivedCertificateIdPadded.length < 64) {
		receivedCertificateIdPadded = "0" + receivedCertificateIdPadded;
	  }
	  certificateIds[forwardKind] = "0x" + receivedCertificateIdPadded;
	}

	// Determine forward IDs.
	let forwardIds = [];
	for(let forwardKind = 0; forwardKind <= 2; forwardKind++) {
	  // Get forward ID.
	  let receivedForwardId = await energyToken.getTokenId(forwardKind, balancePeriod + 9000*forwardKind, idcs[0].options.address);

	  // Pad token ID to full length.
	  let receivedForwardIdPadded = receivedForwardId.toString('hex');
	  while(receivedForwardIdPadded.length < 64) {
		receivedForwardIdPadded = "0" + receivedForwardIdPadded;
	  }
	  forwardIds[forwardKind] = "0x" + receivedForwardIdPadded;
	}

	// Mint forwards.
	for(let forwardKind = 0; forwardKind <= 2; forwardKind++) {
	  let abiCreateForwards = energyTokenWeb3.methods.createForwards(balancePeriod + 9000*forwardKind, forwardKind, distributorWeb3.options.address).encodeABI();
	  await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateForwards).send({from: accounts[5], gas: 7000000});
	  
	  if(forwardKind == 1)
		continue; // Generation-based forwards cannot be minted.

	  // Grant reception approval.
	  idcs[1].methods.approveSender(energyToken.address, idcs[0].options.address, "1895220001", "17000000000000000000", forwardIds[forwardKind]).send({from: accounts[6], gas: 7000000});

	  // Perform actual mint operation via execute() of IDC 0.
	  let abiMintCall = energyTokenWeb3.methods.mint(forwardIds[forwardKind], [idcs[1].options.address], ["17000000000000000000"]).encodeABI();
	  await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiMintCall).send({from: accounts[5], gas: 7000000});
	}

	// Transfer generation-based forwards.
	idcs[1].methods.approveSender(energyToken.address, idcs[0].options.address, "1895220001", "17000000000000000000", forwardIds[1]).send({from: accounts[6], gas: 7000000});
	let abiTransferGenerationBasedForwards = energyTokenWeb3.methods.safeTransferFrom(idcs[0].options.address, idcs[1].options.address, forwardIds[1], "17000000000000000000", "0x00").encodeABI();
	await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransferGenerationBasedForwards).send({from: accounts[5], gas: 7000000});

	let distributeCall = async function(forwardKind) {
	  await distributorWeb3.methods.distribute(idcs[1].options.address, forwardIds[forwardKind]).send({from: accounts[0], gas: 7000000});
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
	  let abiAddGenerationCall1 = energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[0].options.address, "30000000000000000000", balancePeriod + 9000*forwardKind).encodeABI();
	  await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddGenerationCall1).send({from: accounts[8], gas: 7000000});

	  // Add energy consumption.
	  let abiAddConsumptionCall1 = energyTokenWeb3.methods.addMeasuredEnergyConsumption(idcs[1].options.address, "8000000000000000000", balancePeriod + 9000*forwardKind).encodeABI();
	  await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddConsumptionCall1).send({from: accounts[8], gas: 7000000});
	}

	// Run absolute distributor.
	await distributeCall(0);
	assert.equal(await energyToken.balanceOf(idcs[1].options.address, certificateIds[0]), "17000000000000000000");

	// Send certificates back for another test.
	let abiTransferCertsBack = energyTokenWeb3.methods.safeTransferFrom(idcs[1].options.address, distributorWeb3.options.address, certificateIds[0], "17000000000000000000", "0x00").encodeABI();
	await idcs[1].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransferCertsBack).send({from: accounts[6], gas: 7000000});

	// Mint more absolute forwards.
	// Grant reception approval.
	idcs[2].methods.approveSender(energyToken.address, idcs[0].options.address, "1895220001", "83000000000000000000", forwardIds[0]).send({from: accounts[7], gas: 7000000});

	// Perform actual mint operation via execute() of IDC 0.
	let abiMintCall = energyTokenWeb3.methods.mint(forwardIds[0], [idcs[2].options.address], ["83000000000000000000"]).encodeABI();
	await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiMintCall).send({from: accounts[5], gas: 7000000});

	// Run absolute distributor again.
	await distributeCall(0);
	assert.equal(await energyToken.balanceOf(idcs[1].options.address, certificateIds[0]), "5100000000000000000");

	// Send certificates back for another test.
	abiTransferCertsBack = energyTokenWeb3.methods.safeTransferFrom(idcs[1].options.address, distributorWeb3.options.address, certificateIds[0], "5100000000000000000", "0x00").encodeABI();
	await idcs[1].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransferCertsBack).send({from: accounts[6], gas: 7000000});

	// Test generation-based distributor.
	// Run generation-based distributor.
	await distributeCall(1);

	assert.equal(await energyToken.balanceOf(idcs[1].options.address, certificateIds[1]), "5100000000000000000");

	// Send certificates back for another test.
	abiTransferCertsBack = energyTokenWeb3.methods.safeTransferFrom(idcs[1].options.address, distributorWeb3.options.address, certificateIds[1], "5100000000000000000", "0x00").encodeABI();
	await idcs[1].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransferCertsBack).send({from: accounts[6], gas: 7000000});

	// Test consumption-based distributor.
	await distributeCall(2);
	assert.equal(await energyToken.balanceOf(idcs[1].options.address, certificateIds[2]), "1360000000000000000");

	// Send certificates back for another test.
	abiTransferCertsBack = energyTokenWeb3.methods.safeTransferFrom(idcs[1].options.address, distributorWeb3.options.address, certificateIds[2], "1360000000000000000", "0x00").encodeABI();
	await idcs[1].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransferCertsBack).send({from: accounts[6], gas: 7000000});

	// Increase consumed energy beyond generated energy.
    // Does not currently work because updatey values don't affect distribution anymore.
    /*
	let abiAddConsumptionCall2 = energyTokenWeb3.methods.addMeasuredEnergyConsumption(idcs[1].options.address, "50000000000000000000", balancePeriod + 9000*2).encodeABI();
	await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddConsumptionCall2).send({from: accounts[8], gas: 7000000});

	await distributeCall(2);
	assert.equal(await energyToken.balanceOf(idcs[1].options.address, certificateIds[2]), "5100000000000000000");

	// Send certificates back for good measure.
	abiTransferCertsBack = energyTokenWeb3.methods.safeTransferFrom(idcs[1].options.address, distributorWeb3.options.address, certificateIds[2], "5100000000000000000", "0x00").encodeABI();
	await idcs[1].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransferCertsBack).send({from: accounts[6], gas: 7000000});
    */
  });

  it("distributes surplus certificates correctly.", async function() {
    let balancePeriod = 1737560701;
    let certificateIds = [];
	
	for(let forwardKind = 0; forwardKind <= 2; forwardKind++) {
	  // Get certificate ID.
	  let receivedCertificateId = await energyToken.getTokenId(3, balancePeriod + 9000*forwardKind, idcs[0].options.address);

	  // Pad token ID to full length.
	  let receivedCertificateIdPadded = receivedCertificateId.toString('hex');
	  while(receivedCertificateIdPadded.length < 64) {
		receivedCertificateIdPadded = "0" + receivedCertificateIdPadded;
	  }
	  certificateIds[forwardKind] = "0x" + receivedCertificateIdPadded;
	}

	// Determine forward IDs.
	let forwardIds = [];
	for(let forwardKind = 0; forwardKind <= 2; forwardKind++) {
	  // Get forward ID.
	  let receivedForwardId = await energyToken.getTokenId(forwardKind, balancePeriod + 9000*forwardKind, idcs[0].options.address);

	  // Pad token ID to full length.
	  let receivedForwardIdPadded = receivedForwardId.toString('hex');
	  while(receivedForwardIdPadded.length < 64) {
		receivedForwardIdPadded = "0" + receivedForwardIdPadded;
	  }
	  forwardIds[forwardKind] = "0x" + receivedForwardIdPadded;
	}

    // Mint forwards.
	for(let forwardKind = 0; forwardKind <= 2; forwardKind++) {
	  let abiCreateForwards = energyTokenWeb3.methods.createForwards(balancePeriod + 9000*forwardKind, forwardKind, distributorWeb3.options.address).encodeABI();
	  await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateForwards).send({from: accounts[5], gas: 7000000});
	  
	  if(forwardKind == 1)
		continue; // Generation-based forwards cannot be minted.

	  // Grant reception approval.
	  idcs[1].methods.approveSender(energyToken.address, idcs[0].options.address, "1895220001", "17000000000000000000", forwardIds[forwardKind]).send({from: accounts[6], gas: 7000000});

	  // Perform actual mint operation via execute() of IDC 0.
	  let abiMintCall = energyTokenWeb3.methods.mint(forwardIds[forwardKind], [idcs[1].options.address], ["17000000000000000000"]).encodeABI();
	  await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiMintCall).send({from: accounts[5], gas: 7000000});
	}

	let distributeCall = async function(forwardKind) {
	  await distributorWeb3.methods.distribute(idcs[1].options.address, forwardIds[forwardKind]).send({from: accounts[0], gas: 7000000});
	};

    let documentationCall = async function(forwardKind) {
      let abiUpdateEnergyDoc = energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[0].options.address, "20000000000000000000", balancePeriod + 9000*forwardKind).encodeABI();
	  await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiUpdateEnergyDoc).send({from: accounts[8], gas: 7000000});

      abiUpdateEnergyDoc = energyTokenWeb3.methods.addMeasuredEnergyConsumption(idcs[1].options.address, "10000000000000000000", balancePeriod + 9000*forwardKind).encodeABI();
	  await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiUpdateEnergyDoc).send({from: accounts[8], gas: 7000000});
    };

    let surplusWithdrawalCall = async function (forwardKind) {
      await distributorWeb3.methods.withdrawSurplusCertificates(forwardIds[forwardKind]).send({from: accounts[0], gas: 7000000});
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

  it("keeps track of energy data.", async function() {
	let json = '{ "q": "ab", "expiryDate": "1895220001", "startDate": "1", "realWorldPlantId": "bestPlantId" }';
	let data = web3.utils.toHex(json);
    const jsonExistenceGeneration = '{ "type": "generation", "expiryDate": "1895220001", "startDate": "1", "realWorldPlantId": "bestPlantId" }';
	const dataExistenceGeneration = web3.utils.toHex(jsonExistenceGeneration);
	await addClaim(idcs[2], 10050, balanceAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[2], 10060, physicalAssetAuthority.options.address, dataExistenceGeneration, "", account8Sk);
	await addClaim(idcs[2], 10070, physicalAssetAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[2], 10080, physicalAssetAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[2], 10040, meteringAuthority.options.address, data, "", account8Sk);

	let balancePeriod = "1895220001";

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
	let abiCreateForwardsCall = energyTokenWeb3.methods.createForwards(balancePeriod, 2, distributor.address).encodeABI();
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
})
