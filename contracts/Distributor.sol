pragma solidity ^0.5.0;
import "./IdentityContract.sol";
import "./IdentityContractFactory.sol";
import "./EnergyToken.sol";

contract Distributor {
    using SafeMath for uint256;
    
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
        require(ClaimVerifier.getClaimOfType(_consumptionPlantAddress, ClaimCommons.ClaimType.BalanceClaim, true) != 0);
        require(ClaimVerifier.getClaimOfType(_consumptionPlantAddress, ClaimCommons.ClaimType.ExistenceClaim, true) != 0);
        require(ClaimVerifier.getClaimOfType(_consumptionPlantAddress, ClaimCommons.ClaimType.MeteringClaim, true) != 0);
        
        // Distribution
        if(tokenKind == EnergyToken.TokenKind.AbsoluteForward) {
            uint256 totalForwards = energyToken.totalSupply(_tokenId);
            uint256 absoluteForwardsOfConsumer = energyToken.balanceOf(_consumptionPlantAddress, _tokenId);
            uint256 generatedEnergy = energyToken.balanceOf(address(this), certificateTokenId);

            energyToken.safeTransferFrom(address(this), _consumptionPlantAddress, certificateTokenId, min(absoluteForwardsOfConsumer, (absoluteForwardsOfConsumer.div(totalForwards)).mul(generatedEnergy)), additionalData);
            return;
        }
        
        if(tokenKind == EnergyToken.TokenKind.GenerationBasedForward) {
            uint256 generationBasedForwardsOfConsumer = energyToken.balanceOf(_consumptionPlantAddress, _tokenId);
            uint256 generatedEnergy = energyToken.balanceOf(address(this), certificateTokenId);

            energyToken.safeTransferFrom(address(this), _consumptionPlantAddress, certificateTokenId, (generationBasedForwardsOfConsumer.mul(generatedEnergy)).div(100E18), additionalData);
            return;
        }
        
        if(tokenKind == EnergyToken.TokenKind.ConsumptionBasedForward) {
            uint256 consumptionBasedForwards = energyToken.balanceOf(_consumptionPlantAddress, _tokenId);
            uint256 generatedEnergy = energyToken.balanceOf(identityContractAddress, _tokenId);
            uint256 consumedEnergy = energyToken.balanceOf(_consumptionPlantAddress, _tokenId);
            uint256 totalConsumedEnergy = energyToken.getConsumedEnergyOfBalancePeriod(balancePeriod);
            
            uint256 option1 = (consumptionBasedForwards.mul(consumedEnergy)).div(100E18);
            uint256 option2 = (((consumptionBasedForwards.mul(consumedEnergy)).div(100E18)).mul(generatedEnergy)).div(totalConsumedEnergy);
            
            energyToken.safeTransferFrom(address(this), _consumptionPlantAddress, certificateTokenId, min(option1, option2), additionalData);
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
