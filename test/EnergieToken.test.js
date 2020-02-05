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

	await addClaim(balanceAuthority, 10010, marketAuthority.address, "0x00", "", account9Sk);
	await addClaim(meteringAuthority, 10020, marketAuthority.address, "0x00", "", account9Sk);
	await addClaim(physicalAssetAuthority, 10030, marketAuthority.address, "0x00", "", account9Sk);
	
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

	// Give claims to IDC 0.
	let json = '{ "q": "ab", "expiryDate": "1895220001" }';
	let data = web3.utils.toHex(json);
	await addClaim(idcs[0], 10050, balanceAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[0], 10060, physicalAssetAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[0], 10070, physicalAssetAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[0], 10080, physicalAssetAuthority.options.address, data, "", account8Sk);
	await addClaim(idcs[0], 10040, meteringAuthority.options.address, data, "", account8Sk);

	// Get token ID.
	let receivedTokenId = await energyToken.getTokenId(2, 1579860001, idcs[0].options.address);

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

})
