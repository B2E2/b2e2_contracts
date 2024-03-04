const IdentityContractLib = artifacts.require('IdentityContractLib');
const ClaimCommons = artifacts.require('ClaimCommons');
const ClaimVerifier = artifacts.require('ClaimVerifier');
const marketAuthority = artifacts.require('IdentityContract');

const IdentityContractFactory = artifacts.require('IdentityContractFactory');

module.exports = function(deployer) {
    deployer.link(IdentityContractLib, IdentityContractFactory);
    deployer.link(ClaimCommons, IdentityContractFactory);
    deployer.link(ClaimVerifier, IdentityContractFactory);
    deployer.deploy(IdentityContractFactory, marketAuthority.address);
};

