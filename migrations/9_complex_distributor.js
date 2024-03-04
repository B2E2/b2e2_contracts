const Commons = artifacts.require('Commons');
const ClaimCommons = artifacts.require('ClaimCommons');
const ClaimVerifier = artifacts.require('ClaimVerifier');
const IdentityContractLib = artifacts.require('IdentityContractLib');
const EnergyTokenLib = artifacts.require('EnergyTokenLib');

const marketAuthority = artifacts.require('IdentityContract');
const EnergyToken = artifacts.require('EnergyToken');

const ComplexDistributor = artifacts.require('ComplexDistributor');

module.exports = function(deployer, network, accounts) {
    deployer.link(Commons, ComplexDistributor);
    deployer.link(ClaimCommons, ComplexDistributor);
    deployer.link(ClaimVerifier, ComplexDistributor);
    deployer.link(IdentityContractLib, ComplexDistributor);
    deployer.link(EnergyTokenLib, ComplexDistributor);
    deployer.deploy(ComplexDistributor, EnergyToken.address, true, accounts[0]);
};

