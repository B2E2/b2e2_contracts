pragma solidity ^0.5.0;
import "./IdentityContract.sol";
import "./EnergyToken.sol";

contract Distributor is IdentityContract {
    using SafeMath for uint256;
    
    EnergyToken public energyToken;
    
    // token ID => consumption plant address => bool
    mapping(uint256 => mapping(address => bool)) completedDistributions;
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
        require(testing || !completedDistributions[_tokenId][_consumptionPlantAddress], "_consumptionPlantAddress can only distribute certificates once.");
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

            if(_consumptionPlantAddress != generationPlantAddress) {
                energyToken.safeTransferFrom(address(this), _consumptionPlantAddress, certificateTokenId, Commons.min(absoluteForwardsOfConsumer, absoluteForwardsOfConsumer.mul(generatedEnergy).div(totalForwards)), additionalData);
            } else {
                if(generatedEnergy > totalForwards) {
                    energyToken.safeTransferFrom(address(this), _consumptionPlantAddress, certificateTokenId, generatedEnergy.sub(totalForwards), additionalData);
                }
            }
            return;
        }
        
        if(tokenKind == EnergyToken.TokenKind.GenerationBasedForward) {
            uint256 generationBasedForwardsOfConsumer = energyToken.balanceOf(_consumptionPlantAddress, _tokenId);
            (, uint256 generatedEnergy, , bool generated, ) = energyToken.energyDocumentations(generationPlantAddress, balancePeriod);
            require(generated, "Generation plant has not produced any energy.");

            if(_consumptionPlantAddress != generationPlantAddress) {
                energyToken.safeTransferFrom(address(this), _consumptionPlantAddress, certificateTokenId, generationBasedForwardsOfConsumer.mul(generatedEnergy).div(100E18), additionalData);
            } else {
                require(false, "_consumptionPlantAddress cannot be equal to address of generation plant.");
            }
            return;
        }
        
        if(tokenKind == EnergyToken.TokenKind.ConsumptionBasedForward) {
            if(_consumptionPlantAddress != generationPlantAddress) {
                uint256 consumptionBasedForwards = energyToken.balanceOf(_consumptionPlantAddress, _tokenId);
                (uint256 generatedEnergy, uint256 consumedEnergy) = getGeneratedAndConsumedEnergy(generationPlantAddress, _consumptionPlantAddress, balancePeriod);
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
            } else {
                // Only allow transfer of undistributable certificates if all consumption plants have gotten their certificates because otherwise it's not possible to figure out how many certificates are undistributable.
                require(energyToken.numberOfRelevantConsumptionPlantsForGenerationPlant(balancePeriod, generationPlantAddress) == numberOfCompletedConsumptionBasedDistributions[balancePeriod][generationPlantAddress], "Only transfers of undistributable certificates are allowed, if all consumption plants have gotten their certificates.");
                uint256 distributorCertificatesBalance = energyToken.balanceOf(address(this), certificateTokenId);
                energyToken.safeTransferFrom(address(this), _consumptionPlantAddress, certificateTokenId, distributorCertificatesBalance, additionalData);
            }
            return;
        }
        
        require(false, "Unknown tokenKind.");
    }
    
    function getGeneratedAndConsumedEnergy(address _generationPlantAddress, address _consumptionPlantAddress, uint64 _balancePeriod) internal view returns (uint256 __generatedEnergy, uint256 __consumedEnergy) {
        (, uint256 generatedEnergy, , bool gGen, ) = energyToken.energyDocumentations(_generationPlantAddress, _balancePeriod);
        (, uint256 consumedEnergy, , bool gCon, ) = energyToken.energyDocumentations(_consumptionPlantAddress, _balancePeriod);
        require(gGen && !gCon, "Either the generation plant has not generated or the consumption plant has not consumed any energy.");
        return (generatedEnergy, consumedEnergy);
    }
}
