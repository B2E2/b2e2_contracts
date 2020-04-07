const IdentityContractLib = artifacts.require("IdentityContractLib");

const marketAuthority = artifacts.require("IdentityContract");

module.exports = function(deployer) {
  deployer.link(IdentityContractLib, marketAuthority);
  deployer.deploy(marketAuthority, "0x0000000000000000000000000000000000000000", 900);
};

