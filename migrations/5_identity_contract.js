const ClaimCommons = artifacts.require("ClaimCommons");
const ClaimVerifier = artifacts.require("ClaimVerifier");

const marketAuthority = artifacts.require("IdentityContract");

module.exports = function(deployer) {
  deployer.link(ClaimCommons, marketAuthority);
  deployer.link(ClaimVerifier, marketAuthority);
  deployer.deploy(marketAuthority, "0x0000000000000000000000000000000000000000", [], [], 1, 1, [], [], [], [], []);
};

