pragma solidity ^0.5.0;
import "./IdentityContract.sol";
import "./EnergyToken.sol";

contract Distributor is IdentityContract {
    using SafeMath for uint256;
    
    EnergyToken public energyToken;
    
    // token ID => consumption plant address => bool
    mapping(uint256 => mapping(address => bool)) completedDistributions;
    // token ID => generation plant address => bool
    mapping(uint256 => mapping(address => bool)) completedSurplusDistributions;
    mapping(uint64 => mapping(address => uint256)) numberOfCompletedConsumptionBasedDistributions;
    
    bool testing;

    constructor(EnergyToken _energyToken, bool _testing, address _owner) IdentityContract(_energyToken.marketAuthority(), 0, _owner) public {
        energyToken = _energyToken;
        testing = _testing;
    }
    
    function distribute(address payable _consumptionPlantAddress, uint256 _tokenId) public {
        // Distributor applicability check
        require(energyToken.id2Distributor(_tokenId) == this, "Distributor contract does not belong to this _tokenId");
        
        // Single execution check
        require(testing || !completedDistributions[_tokenId][_consumptionPlantAddress], "_consumptionPlantAddress can only call distribute() once.");
        completedDistributions[_tokenId][_consumptionPlantAddress] = true;
        
        (EnergyToken.TokenKind tokenKind, uint64 balancePeriod, address generationPlantAddress) = energyToken.getTokenIdConstituents(_tokenId);
        
        // Time period check
        require(testing || balancePeriod < Commons.getBalancePeriod(balancePeriodLength, now), "balancePeriod has not yet ended.");
        
        uint256 certificateTokenId = energyToken.getTokenId(EnergyToken.TokenKind.Certificate, balancePeriod, generationPlantAddress);
        bytes memory additionalData;

        // Claim check
        require(ClaimVerifier.getClaimOfType(marketAuthority, _consumptionPlantAddress, ClaimCommons.ClaimType.BalanceClaim) != 0, "Claim check for BalanceClaim failed.");
        require(ClaimVerifier.getClaimOfType(marketAuthority, _consumptionPlantAddress, ClaimCommons.ClaimType.ExistenceClaim) != 0, "Claim check for ExistenceClaim failed.");
        require(ClaimVerifier.getClaimOfType(marketAuthority, _consumptionPlantAddress, ClaimCommons.ClaimType.MeteringClaim) != 0, "Claim check for MeteringClaim failed.");
        
        // Distribution
        if(tokenKind == EnergyToken.TokenKind.AbsoluteForward) {
            uint256 totalForwards = energyToken.totalSupply(_tokenId);
            uint256 absoluteForwardsOfConsumer = energyToken.balanceOf(_consumptionPlantAddress, _tokenId);
            (, uint256 generatedEnergy, , bool generated, ) = energyToken.energyDocumentations(generationPlantAddress, balancePeriod);
            require(generated, "Generation plant has not produced any energy.");

            energyToken.safeTransferFrom(address(this), _consumptionPlantAddress, certificateTokenId, Commons.min(absoluteForwardsOfConsumer, absoluteForwardsOfConsumer.mul(generatedEnergy).div(totalForwards)), additionalData);
            return;
        }
        
        if(tokenKind == EnergyToken.TokenKind.GenerationBasedForward) {
            uint256 generationBasedForwardsOfConsumer = energyToken.balanceOf(_consumptionPlantAddress, _tokenId);
            (, uint256 generatedEnergy, , bool generated, ) = energyToken.energyDocumentations(generationPlantAddress, balancePeriod);
            require(generated, "Generation plant has not produced any energy.");

            energyToken.safeTransferFrom(address(this), _consumptionPlantAddress, certificateTokenId, generationBasedForwardsOfConsumer.mul(generatedEnergy).div(100E18), additionalData);
            return;
        }
        
        if(tokenKind == EnergyToken.TokenKind.ConsumptionBasedForward) {
            uint256 consumptionBasedForwards = energyToken.balanceOf(_consumptionPlantAddress, _tokenId);
            (uint256 generatedEnergy, uint256 consumedEnergy) = distribute_getGeneratedAndConsumedEnergy(generationPlantAddress, _consumptionPlantAddress, balancePeriod);
            uint256 totalConsumedEnergy = energyToken.energyConsumedRelevantForGenerationPlant(balancePeriod, generationPlantAddress);

            uint256 option1 = (consumptionBasedForwards.mul(consumedEnergy)).div(100E18);
            uint256 option2;
            if(totalConsumedEnergy > 0) {
                option2 = ((consumptionBasedForwards.mul(consumedEnergy)).mul(generatedEnergy)).div(100E18).div(totalConsumedEnergy);
            } else {
                option2 = option1;
            }
            
            require(energyToken.numberOfRelevantConsumptionPlantsUnmeasuredForGenerationPlant(balancePeriod, generationPlantAddress) == 0, "Missing energy energy documentations for at least one consumption plant.");
            
            numberOfCompletedConsumptionBasedDistributions[balancePeriod][generationPlantAddress]++;
            energyToken.safeTransferFrom(address(this), _consumptionPlantAddress, certificateTokenId, Commons.min(option1, option2), additionalData);
            return;
        }
        
        require(false, "Inapplicable token kind.");
    }
    
    function distribute_getGeneratedAndConsumedEnergy(address _generationPlantAddress, address _consumptionPlantAddress, uint64 _balancePeriod) internal view returns (uint256 __generatedEnergy, uint256 __consumedEnergy) {
        (, uint256 generatedEnergy, , bool gGen, ) = energyToken.energyDocumentations(_generationPlantAddress, _balancePeriod);
        (, uint256 consumedEnergy, , bool gCon, ) = energyToken.energyDocumentations(_consumptionPlantAddress, _balancePeriod);
        require(gGen && !gCon, "Either the generation plant has not generated or the consumption plant has not consumed any energy.");
        return (generatedEnergy, consumedEnergy);
    }
    
    /**
     * Must only be called by generation plants. Sends surplus certificates to the calling generation plant.
     * 
     * Surplus certificates due to rounding errors are neglected. For surplus due to unsold forwards, the reglur distribute() functions has to be called.
     */
    function withdrawSurplusCertificates(uint256 _tokenId) public {
        (EnergyToken.TokenKind tokenKind, uint64 balancePeriod, address generationPlantAddress) = energyToken.getTokenIdConstituents(_tokenId);
        
        // Distributor applicability check
        require(energyToken.id2Distributor(_tokenId) == this, "Distributor contract does not belong to this _tokenId");
        
        // Single execution check
        require(testing || !completedSurplusDistributions[_tokenId][generationPlantAddress], "_generationPlantAddress can only call withdrawSurplusCertificates() once.");
        completedSurplusDistributions[_tokenId][generationPlantAddress] = true;
        
        // Time period check
        require(testing || balancePeriod < Commons.getBalancePeriod(balancePeriodLength, now), "balancePeriod has not yet ended.");
        
        uint256 certificateTokenId = energyToken.getTokenId(EnergyToken.TokenKind.Certificate, balancePeriod, generationPlantAddress);
        bytes memory additionalData;
        
        // Surplus Distribution
        if(tokenKind == EnergyToken.TokenKind.AbsoluteForward) {
            uint256 totalForwards = energyToken.totalSupply(_tokenId);
            (, uint256 generatedEnergy, , bool generated, ) = energyToken.energyDocumentations(generationPlantAddress, balancePeriod);
            require(generated, "Generation plant has not produced any energy.");
            if(generatedEnergy > totalForwards) {
                energyToken.safeTransferFrom(address(this), generationPlantAddress, certificateTokenId, generatedEnergy.sub(totalForwards), additionalData);
            }
            return;
        }
        
        if(tokenKind == EnergyToken.TokenKind.ConsumptionBasedForward) {
            // Only allow transfer of undistributable certificates if all consumption plants have gotten their certificates because otherwise it's not possible to figure out how many certificates are undistributable.
            require(energyToken.numberOfRelevantConsumptionPlantsForGenerationPlant(balancePeriod, generationPlantAddress) == numberOfCompletedConsumptionBasedDistributions[balancePeriod][generationPlantAddress], "Transfer of undistributable certificates is only allowed after all consumption plants have received their certificates.");
            uint256 distributorCertificatesBalance = energyToken.balanceOf(address(this), certificateTokenId);
            energyToken.safeTransferFrom(address(this), generationPlantAddress, certificateTokenId, distributorCertificatesBalance, additionalData);
            return;
        }
        
        require(false, "Inapplicable token kind.");
    }
}
