const Commons = artifacts.require("Commons");
const ClaimCommons = artifacts.require("ClaimCommons");
const ClaimVerifier = artifacts.require("ClaimVerifier");
const IdentityContractLib = artifacts.require("IdentityContractLib");

const marketAuthority = artifacts.require("IdentityContract");
const IdentityContractFactory = artifacts.require("IdentityContractFactory");
const EnergyToken = artifacts.require("EnergyToken");

const Distributor = artifacts.require("Distributor");

module.exports = function(deployer) {
  deployer.link(ClaimVerifier, Distributor);
  deployer.link(IdentityContractLib, Distributor);
  deployer.deploy(Distributor, IdentityContractFactory.address, marketAuthority.address, EnergyToken.address);
};

