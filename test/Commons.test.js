'use strict';

const truffleAssert = require('truffle-assertions');
var Commons = artifacts.require("./Commons.sol");

contract('Commons', function(accounts) {
  it("determines balance periods correctly.", async function() {
	return Commons.deployed().then(async function(instance) {
	  let timestamp_11_00_00 = 1579860000; // Friday, January 24, 2020 11:00:00 AM GMT+01:00
	  let timestamp_11_05_00 = 1579860300; // Friday, January 24, 2020 11:05:00 AM GMT+01:00
	  let timestamp_11_15_00 = 1579860900; // Friday, January 24, 2020 11:15:00 AM GMT+01:00
	  let timestamp_11_15_01 = 1579860901; // Friday, January 24, 2020 11:15:01 AM GMT+01:00

	  let period_11_00_00 = (await instance.getBalancePeriod(timestamp_11_00_00)).toNumber();
	  let period_11_05_00 = (await instance.getBalancePeriod(timestamp_11_05_00)).toNumber();
	  let period_11_15_00 = (await instance.getBalancePeriod(timestamp_11_15_00)).toNumber();
	  let period_11_15_01 = (await instance.getBalancePeriod(timestamp_11_15_01)).toNumber();

	  assert.equal(period_11_00_00, 1579859101);
	  assert.equal(period_11_05_00, 1579860001);
	  assert.equal(period_11_15_00, 1579860001);
	  assert.equal(period_11_15_01, 1579860901);
	});
  });
})
