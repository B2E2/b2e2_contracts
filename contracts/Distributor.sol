pragma solidity ^0.5.0;
import "./IdentityContract.sol";
import "./IdentityContractFactory.sol";
import "./EnergyToken.sol";

contract Distributor {
    IdentityContractFactory public identityContractFactory;
    IdentityContract public marketAuthority;
    EnergyToken public energyToken;

    constructor(IdentityContractFactory _identityContractFactory, IdentityContract _marketAuthority, EnergyToken _energyToken) public {
        identityContractFactory = _identityContractFactory;
        marketAuthority = _marketAuthority;
        energyToken = _energyToken;
    }
    
    function distribute(address payable _consumptionPlantAddress, uint256 _tokenId) public {
        (EnergyToken.TokenKind tokenKind, uint64 balancePeriod, address identityContractAddress) = energyToken.getTokenIdConstituents(_tokenId);
        uint256 certificateTokenId = energyToken.getTokenId(EnergyToken.TokenKind.Certificate, balancePeriod, identityContractAddress);
        bytes memory additionalData;

        // Claim check
        require(identityContractFactory.isRegisteredIdentityContract(_consumptionPlantAddress));
        require(ClaimVerifier.checkHasClaimOfType(_consumptionPlantAddress, ClaimCommons.ClaimType.BalanceClaim, true));
        require(ClaimVerifier.checkHasClaimOfType(_consumptionPlantAddress, ClaimCommons.ClaimType.ExistenceClaim, true));
        require(ClaimVerifier.checkHasClaimOfType(_consumptionPlantAddress, ClaimCommons.ClaimType.MeteringClaim, true));
        
        // Distribution
        if(tokenKind == EnergyToken.TokenKind.AbsoluteForward) {
            uint256 totalForwards = 100E18; // TODO: Funktion totalSupply() schreiben und verwenden?
            uint256 absoluteForwardsOfConsumer = energyToken.balanceOf(_consumptionPlantAddress, _tokenId);
            uint256 generatedEnergy = energyToken.balanceOf(address(this), certificateTokenId);

            energyToken.safeTransferFrom(address(this), _consumptionPlantAddress, certificateTokenId, min(absoluteForwardsOfConsumer, (absoluteForwardsOfConsumer/totalForwards)*generatedEnergy), additionalData);
            return;
        }
        
        if(tokenKind == EnergyToken.TokenKind.GenerationBasedForward) {
            uint256 generationBasedForwardsOfProducer = energyToken.balanceOf(identityContractAddress, _tokenId); // Todo: Wozu braucht man das?
            uint256 generationBasedForwardsOfConsumer = energyToken.balanceOf(_consumptionPlantAddress, _tokenId);
            uint256 generatedEnergy = energyToken.balanceOf(address(this), certificateTokenId);

            energyToken.safeTransferFrom(address(this), _consumptionPlantAddress, certificateTokenId, generationBasedForwardsOfConsumer*generatedEnergy, additionalData);
            return;
        }
        
        if(tokenKind == EnergyToken.TokenKind.ConsumptionBasedForward) {
            uint256 consumptionBasedForwards = energyToken.balanceOf(_consumptionPlantAddress, _tokenId);
            uint256 generatedEnergy = energyToken.balanceOf(identityContractAddress, _tokenId);
            uint256 consumedEnergy = energyToken.balanceOf(_consumptionPlantAddress, _tokenId);
            uint256 totalConsumedEnergy = energyToken.getConsumedEnergyOfBalancePeriod(balancePeriod);
            
            energyToken.safeTransferFrom(address(this), _consumptionPlantAddress, certificateTokenId, min(consumptionBasedForwards*consumedEnergy, ((consumptionBasedForwards*consumedEnergy) / totalConsumedEnergy) * generatedEnergy), additionalData);
            return;
        }
        
        require(false);
    }
    
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if(a <= b)
            return a;
        else
            return b;
    }
}
