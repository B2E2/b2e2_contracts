const Commons = artifacts.require("Commons");
const ClaimCommons = artifacts.require("ClaimCommons");
const ClaimVerifier = artifacts.require("ClaimVerifier");

module.exports = function(deployer) {
  deployer.deploy(Commons).then(function() {
	return deployer.deploy(ClaimCommons).then(function() {
	  deployer.link(Commons, ClaimVerifier);
	  deployer.link(ClaimCommons, ClaimVerifier);
	  return deployer.deploy(ClaimVerifier);
	});
  });
};
