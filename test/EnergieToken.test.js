'use strict';

const truffleAssert = require('truffle-assertions');

let accounts;

var IdentityContract = artifacts.require("./IdentityContract.sol");
var IdentityContractLib = artifacts.require("./IdentityContractLib.sol");
var IdentityContractFactory = artifacts.require("./IdentityContractFactory.sol");
var identityContractFactory;
var marketAuthority;
var idcs = [];

var EnergyToken = artifacts.require("./EnergyToken.sol");
var energyToken;

contract('EnergyToken', function(accounts) {

  before(async function() {
	accounts = await web3.eth.getAccounts();

    marketAuthority = await IdentityContract.new("0x0000000000000000000000000000000000000000", {from: accounts[9]});
	console.log(`Successfully deployed IdentityContract for Market Authority with address: ${marketAuthority.address}`);
    identityContractFactory = await IdentityContractFactory.new(marketAuthority.address, {from: accounts[9]});
	console.log(`Successfully deployed IdentityContractFactory with address: ${identityContractFactory.address}`);

	for(let i=0; i < 3; i++) {
	  idcs[i] = await IdentityContract.new(marketAuthority.address, {from: accounts[i+5]});
	  console.log(`Successfully deployed IdentityContract ${i} with address: ${idcs[i].address}`);
	}
	
	energyToken = await EnergyToken.deployed();
	console.log(`Successfully deployed EnergyToken with address: ${energyToken.address}`);
  });

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

})
