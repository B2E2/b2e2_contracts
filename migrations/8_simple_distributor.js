const Commons = artifacts.require('Commons');
const ClaimCommons = artifacts.require('ClaimCommons');
const ClaimVerifier = artifacts.require('ClaimVerifier');
const IdentityContractLib = artifacts.require('IdentityContractLib');
const EnergyTokenLib = artifacts.require('EnergyTokenLib');

const marketAuthority = artifacts.require('IdentityContract');
const EnergyToken = artifacts.require('EnergyToken');

const SimpleDistributor = artifacts.require('SimpleDistributor');

module.exports = function(deployer, network, accounts) {
    deployer.link(Commons, SimpleDistributor);
    deployer.link(ClaimVerifier, SimpleDistributor);
    deployer.link(IdentityContractLib, SimpleDistributor);
    deployer.link(EnergyTokenLib, SimpleDistributor);
    deployer.deploy(SimpleDistributor, EnergyToken.address, true, accounts[0]);
};

