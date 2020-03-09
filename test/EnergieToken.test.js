'use strict';

const truffleAssert = require('truffle-assertions');
const eutil = require('ethereumjs-util');

const account8Sk = "0x0e3e3eaf624b8aa8a7855b7e1195a5d7cf9b86a146f47e4868ee5d7bc9fb71f2";
const account9Sk = "0x86890046d59c769b4d9a65504122df9572b385848600c09ab1993f8c1a83e85f";

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

contract('EnergyToken', function(accounts) {

  before(async function() {
	accounts = await web3.eth.getAccounts();

    marketAuthority = await IdentityContract.new("0x0000000000000000000000000000000000000000", {from: accounts[9]});
	console.log(`Successfully deployed IdentityContract for Market Authority with address: ${marketAuthority.address}`);
    identityContractFactory = await IdentityContractFactory.new(marketAuthority.address, {from: accounts[9]});
	console.log(`Successfully deployed IdentityContractFactory with address: ${identityContractFactory.address}`);

	let abi = IdentityContract.abi;

	let balanceAuthorityDeployment =  await identityContractFactory.createIdentityContract({from: accounts[8]});
	assert.equal(balanceAuthorityDeployment.logs[1].event, 'IdentityContractCreation');
	let balanceAuthorityAddress = balanceAuthorityDeployment.logs[1].args.idcAddress;
	balanceAuthority = new web3.eth.Contract(abi, balanceAuthorityAddress);
	console.log(`Successfully deployed Balance Authority IDC with address: ${balanceAuthority.options.address}`);

	let meteringAuthorityDeployment =  await identityContractFactory.createIdentityContract({from: accounts[8]});
	assert.equal(meteringAuthorityDeployment.logs[1].event, 'IdentityContractCreation');
	let meteringAuthorityAddress = meteringAuthorityDeployment.logs[1].args.idcAddress;
	meteringAuthority = new web3.eth.Contract(abi, meteringAuthorityAddress);
	console.log(`Successfully deployed Metering Authority IDC with address: ${meteringAuthority.options.address}`);

	let physicalAssetAuthorityDeployment =  await identityContractFactory.createIdentityContract({from: accounts[8]});
	assert.equal(physicalAssetAuthorityDeployment.logs[1].event, 'IdentityContractCreation');
	let physicalAssetAuthorityAddress = physicalAssetAuthorityDeployment.logs[1].args.idcAddress;
	physicalAssetAuthority = new web3.eth.Contract(abi, physicalAssetAuthorityAddress);
	console.log(`Successfully deployed Physical Asset Authority IDC with address: ${physicalAssetAuthority.options.address}`);

	let json = '{ "q": "ab", "expiryDate": "1895220001" }';
	let data = web3.utils.toHex(json);
	await addClaim(balanceAuthority, 10010, marketAuthority.address, data, "", account9Sk);
	await addClaim(meteringAuthority, 10020, marketAuthority.address, data, "", account9Sk);
	await addClaim(physicalAssetAuthority, 10030, marketAuthority.address, data, "", account9Sk);
	
	for(let i=0; i < 3; i++) {
	  let idcDeployment =  await identityContractFactory.createIdentityContract({from: accounts[i+5]});
	  assert.equal(balanceAuthorityDeployment.logs[1].event, 'IdentityContractCreation');
	  let idcAddress = idcDeployment.logs[1].args.idcAddress;
	  idcs[i] = new web3.eth.Contract(abi, idcAddress);
	  console.log(`Successfully deployed IdentityContract ${i} with address: ${idcs[i].options.address}`);
	}
	
	energyToken = await EnergyToken.new(marketAuthority.address, identityContractFactory.address);
	energyTokenWeb3 = new web3.eth.Contract(EnergyToken.abi, energyToken.address);
	console.log(`Successfully deployed EnergyToken with address: ${energyToken.address}`);
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

	// Claims necessary for receiving but held by balance authority.
	let jsonAcceptedDistributor = '{ "t": "t", "expiryDate": "1895220001", "address": "' + idcs[2].options.address.slice(2).toLowerCase() + '" }';
	let dataAcceptedDistributor = web3.utils.toHex(jsonAcceptedDistributor);
	await addClaim(balanceAuthority, 10120, balanceAuthority.options.address, dataAcceptedDistributor, "", account8Sk);

	// Give claims to IDC 0.
	let json = '{ "q": "ab", "expiryDate": "1895220001" }';
	let data = web3.utils.toHex(json);
	await addClaim(idcs[0], 10050, balanceAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[0], 10060, physicalAssetAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[0], 10070, physicalAssetAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[0], 10080, physicalAssetAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[0], 10040, meteringAuthority.options.address, data, "", account8Sk);

	// Give claims to IDC 2.
	await addClaim(idcs[2], 10040, meteringAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[2], 10050, balanceAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[2], 10060, physicalAssetAuthority.options.address, data, "", account8Sk);

	// Get token ID.
	let receivedTokenId = await energyToken.getTokenId(2, 1737540001, idcs[0].options.address);

	// Pad token ID to full length.
	let receivedTokenIdPadded = receivedTokenId.toString('hex');
	while(receivedTokenIdPadded.length < 64) {
	  receivedTokenIdPadded = "0" + receivedTokenIdPadded;
	}
	let id = "0x" + receivedTokenIdPadded;

	// Grant reception approval.
	let abiApproveSenderCall = energyTokenWeb3.methods.approveSender(idcs[0].options.address, "1895220001", "17000000000000000000", id).encodeABI();
	await idcs[2].methods.execute(0, energyTokenWeb3.options.address, 0, abiApproveSenderCall).send({from: accounts[7], gas: 7000000});

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
	let abiCreateTokensCall = energyTokenWeb3.methods.createGenerationBasedForwards(balancePeriod, idcs[1].options.address).encodeABI();
	let callResult = await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateTokensCall).send({from: accounts[5], gas: 7000000});

	// Make sure that repeated calls revert as each generation-based forward cannot be created more than once.
	await truffleAssert.reverts(idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiCreateTokensCall).send({from: accounts[5], gas: 7000000}));

	// I can't get the return value because this is run via execute. It also wouldn't work anyway because web3 is stupid. Furthermore, I wasn't able to figure out how to get the event from web3. It doesn't work the way events can be retrieved using truffle contract objects and everything I've tried yielded null, undefined, an empty array, or other thing that just didn't make any sense. So I need to either compute the token ID here or get it via another function call.
	let id = await energyToken.getTokenId(1, balancePeriod, idcs[0].options.address);

	assert.equal(await energyToken.balanceOf(idcs[0].options.address, id), 0);
	assert.equal(await energyToken.balanceOf(idcs[1].options.address, id), 100E18);
  });

  it("keeps track of energy data.", async function() {
	let balancePeriod = "1895220001";
	
	// The call must revert if it comes from something that's not a metering authority's IDC (even if it's by the metering authority directly).
	let abiAddConsumptionCall1 = energyTokenWeb3.methods.addMeasuredEnergyConsumption(idcs[1].options.address, 500, balancePeriod, false).encodeABI();
	await truffleAssert.reverts(idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiAddConsumptionCall1).send({from: accounts[5], gas: 7000000}));
	await truffleAssert.reverts(energyTokenWeb3.methods.addMeasuredEnergyConsumption(idcs[1].options.address, 500, balancePeriod, false).send({from: accounts[8], gas: 7000000}));
	
	await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddConsumptionCall1).send({from: accounts[8], gas: 7000000});

	// It needs to be possible to update the value.
	let abiAddConsumptionCall2 = energyTokenWeb3.methods.addMeasuredEnergyConsumption(idcs[1].options.address, 335, balancePeriod, false).encodeABI();
	await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddConsumptionCall2).send({from: accounts[8], gas: 7000000});

	// It needs to be possible to change the value to a corrected value.
	let abiAddConsumptionCall3 = energyTokenWeb3.methods.addMeasuredEnergyConsumption(idcs[1].options.address, 1335, balancePeriod, true).encodeABI();
	await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddConsumptionCall3).send({from: accounts[8], gas: 7000000});

	// It must be possible to update corrected values too.
	let abiAddConsumptionCall4 = energyTokenWeb3.methods.addMeasuredEnergyConsumption(idcs[1].options.address, 2335, balancePeriod, true).encodeABI();
	await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddConsumptionCall4).send({from: accounts[8], gas: 7000000});

	// It must not be possible to replace a corrected value by a non-corrected one.
	let abiAddConsumptionCall5 = energyTokenWeb3.methods.addMeasuredEnergyConsumption(idcs[1].options.address, 3335, balancePeriod, false).encodeABI();
	await truffleAssert.reverts(meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddConsumptionCall5).send({from: accounts[8], gas: 7000000}));

	// All the same goes for energy generation.
	// The call must revert if it comes from something that's not a metering authority's IDC (even if it's by the metering authority directly).
	let abiAddGenerationCall1 = energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[2].options.address, 500, balancePeriod, false).encodeABI();
	await truffleAssert.reverts(idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiAddGenerationCall1).send({from: accounts[5], gas: 7000000}));
	await truffleAssert.reverts(energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[2].options.address, 500, balancePeriod, false).send({from: accounts[8], gas: 7000000}));

	await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddGenerationCall1).send({from: accounts[8], gas: 7000000});

	// It needs to be possible to update the value.
	let abiAddGenerationCall2 = energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[2].options.address, 335, balancePeriod, false).encodeABI();
	await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddGenerationCall2).send({from: accounts[8], gas: 7000000});

	// It needs to be possible to change the value to a corrected value.
	let abiAddGenerationCall3 = energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[2].options.address, 1335, balancePeriod, true).encodeABI();
	await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddGenerationCall3).send({from: accounts[8], gas: 7000000});

	// It must be possible to update corrected values too.
	let abiAddGenerationCall4 = energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[2].options.address, 2335, balancePeriod, true).encodeABI();
	await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddGenerationCall4).send({from: accounts[8], gas: 7000000});

	// It must not be possible to replace a corrected value by a non-corrected one.
	let abiAddGenerationCall5 = energyTokenWeb3.methods.addMeasuredEnergyGeneration(idcs[2].options.address, 3335, balancePeriod, false).encodeABI();
	await truffleAssert.reverts(meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddGenerationCall5).send({from: accounts[8], gas: 7000000}));

	// Total consumed energy needs to check out despite of correctitions.
	assert.equal(await energyToken.getConsumedEnergyOfBalancePeriod(balancePeriod), 2335);

	// Non-corrected values count too.
	let abiAddConsumptionCall6 = energyTokenWeb3.methods.addMeasuredEnergyConsumption(idcs[0].options.address, 10000, balancePeriod, false).encodeABI();
	await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiAddConsumptionCall6).send({from: accounts[8], gas: 7000000});
	assert.equal(await energyToken.getConsumedEnergyOfBalancePeriod(balancePeriod), 12335);
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
	let abiApproveSenderCall = energyTokenWeb3.methods.approveSender(idcs[2].options.address, "1895220001", "12000000000000000000", id).encodeABI();
	await idcs[1].methods.execute(0, energyTokenWeb3.options.address, 0, abiApproveSenderCall).send({from: accounts[6], gas: 7000000});

	// Before the transfer can happen, some claims need to be issued and published.
	// Claims necessary for sending.
	let json = '{ "q": "ab", "expiryDate": "1895220001" }';
	let data = web3.utils.toHex(json);
	await addClaim(idcs[1], 10050, balanceAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[1], 10060, physicalAssetAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[1], 10070, physicalAssetAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[1], 10080, physicalAssetAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[1], 10040, meteringAuthority.options.address, data, "", account8Sk);

	// Claims necessary for receiving.
	await addClaim(idcs[1], 10050, balanceAuthority.options.address, data, "", account8Sk);

	// Claims necessary for receiving but held by balance authority.
	let jsonAcceptedDistributor = '{ "t": "t", "expiryDate": "1895220001", "address": "' + idcs[1].options.address.slice(2).toLowerCase() + '" }';
	let dataAcceptedDistributor = web3.utils.toHex(jsonAcceptedDistributor);
	await addClaim(balanceAuthority, 10120, balanceAuthority.options.address, dataAcceptedDistributor, "", account8Sk);

	// Send 5 tokens.
	let abiTransfer = energyTokenWeb3.methods.safeTransferFrom(idcs[2].options.address, idcs[1].options.address, id, "5000000000000000000", "0x00").encodeABI();
	await idcs[2].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransfer).send({from: accounts[7], gas: 7000000});

	// Partial transfers are permitted. So the the same transfer again has to work too.
	await idcs[2].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransfer).send({from: accounts[7], gas: 7000000});

	// 3*5 > 12. So the third transfer needs to fail.
	await truffleAssert.reverts(idcs[2].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransfer).send({from: accounts[7], gas: 7000000}));

	// Make sure that the balances are correct.
	let balance1 = await energyToken.balanceOf(idcs[1].options.address, id);
	let balance2 = await energyToken.balanceOf(idcs[2].options.address, id);
	assert.equal(balance1, 10E18);
	assert.equal(balance2, 7E18);

	// Upper edge case.
	let abiTransferUpper = energyTokenWeb3.methods.safeTransferFrom(idcs[2].options.address, idcs[1].options.address, id, "2000000000000000001", "0x00").encodeABI();
	await truffleAssert.reverts(idcs[2].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransferUpper).send({from: accounts[7], gas: 7000000}));

	// Lower edge case.
	let abiTransferLower = energyTokenWeb3.methods.safeTransferFrom(idcs[2].options.address, idcs[1].options.address, id, "2000000000000000000", "0x00").encodeABI();
	await idcs[2].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransferLower).send({from: accounts[7], gas: 7000000});

	// Check updated balances.
	balance1 = await energyToken.balanceOf(idcs[1].options.address, id);
	balance2 = await energyToken.balanceOf(idcs[2].options.address, id);
	assert.equal(balance1, 12E18);
	assert.equal(balance2, 5E18);

	// Self-transfers are not allowed without reception approval.
	let abiTransferSelf1 = energyTokenWeb3.methods.safeTransferFrom(idcs[2].options.address, idcs[2].options.address, id, "5000000000000000000", "0x00").encodeABI();
	await truffleAssert.reverts(idcs[2].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransferSelf1).send({from: accounts[7], gas: 7000000}));

	// Transferring tokens to a receiver without the necessary claims needs to fail.
	let abiApproveSenderCallIdc0 = energyTokenWeb3.methods.approveSender(idcs[2].options.address, "1895220001", "1000000000000000000", id).encodeABI();
	await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiApproveSenderCallIdc0).send({from: accounts[5], gas: 7000000});
	let abiTransferToIdc0 = energyTokenWeb3.methods.safeTransferFrom(idcs[2].options.address, idcs[0].options.address, id, "1000000000000000000", "0x00").encodeABI();
	await truffleAssert.reverts(idcs[2].methods.execute(0, energyTokenWeb3.options.address, 0, abiTransferToIdc0).send({from: accounts[7], gas: 7000000}));
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

	// Get token ID of certificate.
	let receivedTokenId2 = await energyToken.getTokenId(3, 1737540901, idcs[0].options.address);

	// Pad token ID to full length.
	let receivedTokenId2Padded = receivedTokenId2.toString('hex');
	while(receivedTokenId2Padded.length < 64) {
	  receivedTokenId2Padded = "0" + receivedTokenId2Padded;
	}
	let id2 = "0x" + receivedTokenId2Padded;

	// Reception approval for receiving minted forwards.
	let abiApproveSenderCallMinting = energyTokenWeb3.methods.approveSender(idcs[0].options.address, "1895220001", "17000000000000000000", id1).encodeABI();
	await idcs[2].methods.execute(0, energyTokenWeb3.options.address, 0, abiApproveSenderCallMinting).send({from: accounts[7], gas: 7000000});

	// Claims necessary for receiving but held by balance authority.
	let jsonAcceptedDistributor = '{ "t": "t", "expiryDate": "1895220001", "address": "' + idcs[2].options.address.slice(2).toLowerCase() + '" }';
	let dataAcceptedDistributor = web3.utils.toHex(jsonAcceptedDistributor);
	await addClaim(balanceAuthority, 10120, balanceAuthority.options.address, dataAcceptedDistributor, "", account8Sk);

	// Minting.
	let abiMintCall1 = energyTokenWeb3.methods.mint(id1, [idcs[2].options.address], ["17000000000000000000"]).encodeABI();
	await idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiMintCall1).send({from: accounts[5], gas: 7000000});
	
	let abiMintCall2 = energyTokenWeb3.methods.mint(id2, [idcs[2].options.address], ["17000000000000000000"]).encodeABI();
	// This mint call needs to revert because only metering authorities are allowed to mint certificates.
	await truffleAssert.reverts(idcs[0].methods.execute(0, energyTokenWeb3.options.address, 0, abiMintCall2).send({from: accounts[5], gas: 7000000}));
	await meteringAuthority.methods.execute(0, energyTokenWeb3.options.address, 0, abiMintCall2).send({from: accounts[8], gas: 7000000});

	// Claims necessary for receiving but held by balance authority.
	jsonAcceptedDistributor = '{ "t": "t", "expiryDate": "1895220001", "address": "' + idcs[1].options.address.slice(2).toLowerCase() + '" }';
	dataAcceptedDistributor = web3.utils.toHex(jsonAcceptedDistributor);
	await addClaim(balanceAuthority, 10120, balanceAuthority.options.address, dataAcceptedDistributor, "", account8Sk);

	// Reception approval is required for forwards.
	let abiApproveSenderCall = energyTokenWeb3.methods.approveSender(idcs[2].options.address, "1895220001", "1000000000000000000", id1).encodeABI();
	await idcs[1].methods.execute(0, energyTokenWeb3.options.address, 0, abiApproveSenderCall).send({from: accounts[6], gas: 7000000});

	// Reception approval is not required for certificates.

	// Transfer.
	let abiBatchTransfer = energyTokenWeb3.methods.safeBatchTransferFrom(idcs[2].options.address, idcs[1].options.address, [id1, id2], ["1000000000000000000", "3000000000000000000"], "0x00").encodeABI();
	idcs[2].methods.execute(0, energyTokenWeb3.options.address, 0, abiBatchTransfer).send({from: accounts[7], gas: 7000000});

	// Check updated balances.
	let balance11 = await energyToken.balanceOf(idcs[1].options.address, id1);
	let balance12 = await energyToken.balanceOf(idcs[1].options.address, id2);
	let balance21 = await energyToken.balanceOf(idcs[2].options.address, id1);
	let balance22 = await energyToken.balanceOf(idcs[2].options.address, id2);
	assert.equal(balance11, 1E18);
	assert.equal(balance12, 3E18);
	assert.equal(balance21, 16E18);
	assert.equal(balance22, 14E18);
  });
})
