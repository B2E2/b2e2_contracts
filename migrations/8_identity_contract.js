const ClaimCommons = artifacts.require("ClaimCommons");
const ClaimVerifier = artifacts.require("ClaimVerifier");

const IdentityContract = artifacts.require("IdentityContract");
const Identity = artifacts.require("Identity");

module.exports = function(deployer) {
  deployer.link(ClaimCommons, IdentityContract);
  deployer.link(ClaimVerifier, IdentityContract);
  deployer.deploy(IdentityContract, "0x0000000000000000000000000000000000000000", [], [], 1, 1, [], [], [], [], []);



};

