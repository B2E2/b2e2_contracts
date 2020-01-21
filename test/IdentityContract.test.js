'use strict';

const truffleAssert = require('truffle-assertions');

let accounts;

var IdentityContract = artifacts.require("./IdentityContract.sol");
var marketAuthority;
var idcs = [];

contract('Tests', function(accounts) {

  before(async function() {
	accounts = await web3.eth.getAccounts();

    marketAuthority = await IdentityContract.new("0x0000000000000000000000000000000000000000", {from: accounts[9]});
	console.log(`Successfully deployed IdentityContract for Market Authority with address: ${marketAuthority.address}`);

	for(let i=0; i < 3; i++) {
	  idcs[i] = await IdentityContract.new(marketAuthority.address, {from: accounts[i+5]});
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
})
