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
	await idcs[0].addClaim(7, 11, "0x0000000000000000000000000000000000000013", "0x17192329", "0x31374143", "example.com");
  });

  it("does not accept arbitrary claims inside relevant range.", async function() {
	await truffleAssert.reverts(idcs[0].addClaim(10500, 11, "0x0000000000000000000000000000000000000013", "0x17192329", "0x31374143", "example.com"));
	await truffleAssert.reverts(idcs[0].addClaim(11000, 11, "0x0000000000000000000000000000000000000013", "0x17192329", "0x31374143", "example.com"));
	await truffleAssert.reverts(idcs[0].addClaim(10000, 11, "0x0000000000000000000000000000000000000013", "0x17192329", "0x31374143", "example.com"));
  });
})
