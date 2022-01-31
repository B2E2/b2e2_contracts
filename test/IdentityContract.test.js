'use strict';

const truffleAssert = require('truffle-assertions');
const eutil = require('ethereumjs-util');
const fs = require('fs');
const IdentityContractFromJson = JSON.parse(fs.readFileSync('./build/contracts/IdentityContract.json', 'utf8'));
let web3Idc = new web3.eth.Contract(IdentityContractFromJson.abi);

const account9Sk = "0x3b9722b917db24a24b3783595f2d30441ca044a1fa6d8dba5c8be7743387a6f3";

let accounts;

var IdentityContract = artifacts.require("./IdentityContract.sol");
var IdentityContractLib = artifacts.require("./IdentityContractLib.sol");
var marketAuthority;
var idcs = [];
var ClaimVerifier = artifacts.require("./ClaimVerifier.sol");
var claimVerifier;

contract('IdentityContract', function(accounts) {

  before(async function() {
	await ClaimVerifier.deployed().then(async function(instance) {
	  claimVerifier = instance;
	});
	
	accounts = await web3.eth.getAccounts();

    marketAuthority = await IdentityContract.new("0x0000000000000000000000000000000000000000", 900, accounts[9], {from: accounts[9]});
	console.log(`Successfully deployed IdentityContract for Market Authority with address: ${marketAuthority.address}`);

	for(let i=0; i < 3; i++) {
	  idcs[i] = await IdentityContract.new(marketAuthority.address, 0, accounts[i+5], {from: accounts[i+5]});
	  console.log(`Successfully deployed IdentityContract ${i} with address: ${idcs[i].address}`);
	}
  });

  it("knows the market authority.", async function() {
    assert.equal(await marketAuthority.marketAuthority(), marketAuthority.address);

	for(let i=0; i < 3; i++) {
	  assert.equal(await idcs[i].marketAuthority(), marketAuthority.address);
	}
  });

  it("knows its owner.", async function() {
	assert.equal(await marketAuthority.owner(), accounts[9]);

	for(let i=0; i < 3; i++) {
	  assert.equal(await idcs[i].owner(), accounts[i+5]);
	}
  });

  it("changes its owner.", async function() {
	await idcs[0].changeOwner(accounts[1], {from: accounts[5]});
	assert.equal(await idcs[0].owner(), accounts[1]);
  });

  it("can be owned by a different IdentityContract.", async function() {
	await idcs[0].changeOwner(idcs[1].address, {from: accounts[1]});
	assert.equal(await idcs[0].owner(), idcs[1].address);
  });

  it("accepts any claims outside of relevant range.", async function() {
	await idcs[2].addClaim(1, 11, "0x0000000000000000000000000000000000000013", "0x17192329", "0x31374143", "example.com");
	await idcs[2].addClaim(2, 11, accounts[2], "0x17192328", "0x31374142", "example.com");
  });

  it("does not accept arbitrary claims inside relevant range.", async function() {
	await truffleAssert.reverts(idcs[0].addClaim(10500, 11, "0x0000000000000000000000000000000000000013", "0x17192329", "0x31374143", "example.com"));
	await truffleAssert.reverts(idcs[0].addClaim(11000, 11, "0x0000000000000000000000000000000000000013", "0x17192329", "0x31374143", "example.com"));
	await truffleAssert.reverts(idcs[0].addClaim(10000, 11, "0x0000000000000000000000000000000000000013", "0x17192329", "0x31374143", "example.com"));
  });

  it("accepts removal of claims only by owner and issuer.", async function() {
	let claimId1 = await idcs[2].getClaimIdsByTopic(1);
	let claimId2 = await idcs[2].getClaimIdsByTopic(2);

	await truffleAssert.reverts(idcs[2].removeClaim(claimId1[0]));
	await truffleAssert.reverts(idcs[2].removeClaim(claimId2[0]));

	// By owner.
	await idcs[2].removeClaim(claimId1[0], {from: accounts[7]});

	// By issuer.
	await idcs[2].removeClaim(claimId2[0], {from: accounts[2]});

	// Check whether claims have actually been removed.
	// First check the helper entries.
	let newClaimId1 = await idcs[2].getClaimIdsByTopic(1);
	let newClaimId2 = await idcs[2].getClaimIdsByTopic(1);
	assert.equal(newClaimId1.length, 0);
	assert.equal(newClaimId2.length, 0);

	// Then check the actual claim entries.
	let claim1 = await idcs[2].getClaim(claimId1[0]);
	assert.equal(claim1.__topic, 0);
	assert.equal(claim1.__scheme, 0);
	assert.equal(claim1.__issuer, 0);
	assert.equal(claim1.__signature, null);
	assert.equal(claim1.__data, null);
	assert.equal(claim1.__uri, '');
	let claim2 = await idcs[2].getClaim(claimId2[0]);
	assert.equal(claim2.__topic, 0);
	assert.equal(claim2.__scheme, 0);
	assert.equal(claim2.__issuer, 0);
	assert.equal(claim2.__signature, null);
	assert.equal(claim2.__data, null);
	assert.equal(claim2.__uri, '');
  });

  async function signatureVerificationTest(message) {
	const subject = idcs[2].address;
	
	const topic = 42;
	const scheme = 1;
	const issuer = accounts[9];
	const data = web3.utils.toHex(message);
	const hash = web3.utils.soliditySha3(subject, topic, data);

	const signature3 = await eutil.ecsign(new Buffer(hash.slice(2), "hex"), new Buffer(account9Sk.slice(2), "hex"));
	const signature4 = '0x' + signature3.r.toString('hex') + signature3.s.toString('hex') + signature3.v.toString(16);

	const resultCorrectSignatureGiven = claimVerifier.verifySignature(idcs[2].address, topic, scheme, issuer, signature4, data);
	const resultWrongIssuerGiven = claimVerifier.verifySignature(idcs[2].address, topic, scheme, accounts[8], signature4, data);
	const resultWrongSignatureGiven = claimVerifier.verifySignature(idcs[2].address, topic, scheme, issuer, '0xb893fdc3bed932a0e51c974c868a80fa8220e6b1176f2e0ee5e2ffd6e21b59124dcfe1afa1bb8e68ecee4f3c3b3ad750cffe91d53b8049cb6416181bbd2c80de1d', data);
	const resultWrongTopicGiven = claimVerifier.verifySignature(idcs[2].address, 43, scheme, issuer, signature4, data);
	const resultWrongSchemeGiven = claimVerifier.verifySignature(idcs[2].address, topic, 500, issuer, signature4, data);

	assert.isTrue(await resultCorrectSignatureGiven);
	assert.isFalse(await resultWrongIssuerGiven);
	await truffleAssert.reverts(resultWrongSignatureGiven);
	assert.isFalse(await resultWrongTopicGiven);
	assert.isFalse(await resultWrongSchemeGiven);
  }

  it("verifies signatures of short messages correctly.", async function() {
	await signatureVerificationTest("{ q: 'ab', answer: '42' }");
  });

  it("verifies signatures of long messages (> 32 B) correctly.", async function() {
	await signatureVerificationTest("{ question: 'What\'s the answer to the Ultimate Question of Life, the Universe, and Everything', answer: '42' }");
  });

  it("can execute functions.", async function() {
	// IDC 0 is currently owned by IDC 1.
	// IDC 1 is owned by account 6.
	// Account 6 wants to change the owner of IDC 0 to account 2.
	// For this, account 6 needs to tell IDC 1 to tell IDC 0 to change its owner.
	
	// Prepare function call.
    const idc = new web3.eth.Contract(IdentityContractFromJson.abi, idcs[1].address);
	let data = idc.methods.changeOwner(accounts[2]).encodeABI();
	
	assert.equal(await idcs[0].owner(), idcs[1].address);
    await idc.methods.execute(0, idcs[0].address, 0, data).send({from: accounts[6]});
	assert.equal(await idcs[0].owner(), accounts[2]);
  });

  it("can create contracts via the execute function.", async function() {
	let abi = JSON.parse(fs.readFileSync('./test/SimpleContractAbi.json', 'utf8'));
	let bytecode = "0x608060405234801561001057600080fd5b50600560008190555060c4806100276000396000f3fe6080604052348015600f57600080fd5b506004361060325760003560e01c80634f28bf0e146037578063827d09bb146053575b600080fd5b603d607e565b6040518082815260200191505060405180910390f35b607c60048036036020811015606757600080fd5b81019080803590602001909291905050506084565b005b60005481565b806000819055505056fea2646970667358221220cc660561f0fb2fdb793736073e36c8454fd528fce41b78fb47115d3c50b33e1364736f6c63430007000033";
    // Confer: https://github.com/trufflesuite/truffle/releases/tag/v5.0.0#user-content-what-s-new-in-truffle-v5-interacting-with-your-contracts-overloaded-solidity-functions
	let deploymentResult = await idcs[1].methods['execute(uint256,address,uint256,bytes)'](1, idcs[0].address, 0, bytecode, {from: accounts[6]});

	// Make sure that the contract creation event has been emitted.
	assert.equal(deploymentResult.logs[0].event, 'ContractCreated');

	// Make sure that the contract instance actually exists on the blockchain and can be used.
	let addressOfDeployedContract = deploymentResult.logs[0].args.contractAddress;
	let deployedContract = new web3.eth.Contract(abi, addressOfDeployedContract);
	assert.equal(await deployedContract.methods.field().call(), 5);
	await deployedContract.methods.setField(27).send({from: accounts[0]});
	assert.equal(await deployedContract.methods.field().call(), 27);
  });
})
