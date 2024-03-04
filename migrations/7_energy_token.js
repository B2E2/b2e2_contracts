const Commons = artifacts.require('Commons');
const ClaimCommons = artifacts.require('ClaimCommons');
const ClaimVerifier = artifacts.require('ClaimVerifier');
const EnergyTokenLib = artifacts.require('EnergyTokenLib');

const marketAuthority = artifacts.require('IdentityContract');

const EnergyToken = artifacts.require('EnergyToken');

module.exports = function(deployer) {
    deployer.link(Commons, EnergyToken);
    deployer.link(ClaimCommons, EnergyToken);
    deployer.link(ClaimVerifier, EnergyToken);
    deployer.link(EnergyTokenLib, EnergyToken);
    deployer.deploy(EnergyToken, marketAuthority.address);
};

