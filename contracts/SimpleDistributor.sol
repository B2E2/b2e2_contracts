pragma solidity ^0.8.1;
import "./AbstractDistributor.sol";
import "./EnergyToken.sol";
import "./EnergyTokenLib.sol";
import "./IEnergyToken.sol";

contract SimpleDistributor is AbstractDistributor {
    EnergyToken public energyToken;
    
    // token ID => consumption plant address => bool
    mapping(uint256 => mapping(address => bool)) completedDistributions;
    // token ID => generation plant address => bool
    mapping(uint256 => mapping(address => bool)) completedSurplusDistributions;
    mapping(uint64 => mapping(address => uint256)) numberOfCompletedConsumptionBasedDistributions;
    
    bool testing;
    
    modifier onlyEnergyToken() {
        require(msg.sender == address(energyToken), "only the energy token contract may invoke this function");
        _;
    }

    constructor(EnergyToken _energyToken, bool _testing, address _owner) IdentityContract(_energyToken.marketAuthority(), 0, _owner) {
        energyToken = _energyToken;
        testing = _testing;
    }
    
    function distribute(address payable _consumptionPlantAddress, uint256 _tokenId) external onlyConsumptionPlants(_consumptionPlantAddress) {
        // Distributor applicability check. Required because this contract holding the necessary certificates to pay the consumption plant
        // is not sufficient grouns to assume that this is the correct distributor as soon as several forwards may cause payout of the
        // same certificates.
        require(energyToken.id2Distributor(_tokenId) == this, "Distributor contract does not belong to this _tokenId");
        
        // Single execution check
        require(testing || !completedDistributions[_tokenId][_consumptionPlantAddress], "_consumptionPlantAddress can only call distribute() once.");
        completedDistributions[_tokenId][_consumptionPlantAddress] = true;
        
        (IEnergyToken.TokenKind tokenKind, uint64 balancePeriod, address generationPlantAddress) = energyToken.getTokenIdConstituents(_tokenId);
        
        // Time period check
        require(testing || balancePeriod < Commons.getBalancePeriod(balancePeriodLength, block.timestamp), "balancePeriod has not yet ended.");
        
        uint256 certificateTokenId = energyToken.getTokenId(IEnergyToken.TokenKind.Certificate, balancePeriod, generationPlantAddress, 0);

        // Distribution
        if(tokenKind == IEnergyToken.TokenKind.AbsoluteForward) {
            uint256 totalForwards = energyToken.totalSupply(_tokenId);
            uint256 absoluteForwardsOfConsumer = energyToken.balanceOf(_consumptionPlantAddress, _tokenId);
            (, uint256 generatedEnergy, , bool generated, ) = energyToken.energyDocumentations(generationPlantAddress, balancePeriod);
            require(generated, "Generation plant has not produced any energy.");

            energyToken.safeTransferFrom(address(this), _consumptionPlantAddress, certificateTokenId, Commons.min(absoluteForwardsOfConsumer, (absoluteForwardsOfConsumer * generatedEnergy) / totalForwards), new bytes(0));
            return;
        }
        
        if(tokenKind == IEnergyToken.TokenKind.GenerationBasedForward) {
            uint256 generationBasedForwardsOfConsumer = energyToken.balanceOf(_consumptionPlantAddress, _tokenId);
            (, uint256 generatedEnergy, , bool generated, ) = energyToken.energyDocumentations(generationPlantAddress, balancePeriod);
            require(generated, "Generation plant has not produced any energy.");

            energyToken.safeTransferFrom(address(this), _consumptionPlantAddress, certificateTokenId, (generationBasedForwardsOfConsumer * generatedEnergy) / 100E18, new bytes(0));
            return;
        }
        
        if(tokenKind == IEnergyToken.TokenKind.ConsumptionBasedForward) {
            uint256 consumptionBasedForwards = energyToken.balanceOf(_consumptionPlantAddress, _tokenId);
            (uint256 generatedEnergy, uint256 consumedEnergy) = distribute_getGeneratedAndConsumedEnergy(generationPlantAddress, _consumptionPlantAddress, balancePeriod);
            uint256 totalConsumedEnergy = energyToken.energyConsumedRelevantForGenerationPlant(balancePeriod, generationPlantAddress);

            uint256 option1 = (consumptionBasedForwards * consumedEnergy) / 100E18;
            uint256 option2;
            if(totalConsumedEnergy > 0) {
                option2 = (consumptionBasedForwards * consumedEnergy * generatedEnergy) / (100E18 * totalConsumedEnergy);
            } else {
                option2 = option1;
            }
            
            require(energyToken.numberOfRelevantConsumptionPlantsUnmeasuredForGenerationPlant(balancePeriod, generationPlantAddress) == 0, "Missing energy energy documentations for at least one consumption plant.");
            
            numberOfCompletedConsumptionBasedDistributions[balancePeriod][generationPlantAddress]++;
            energyToken.safeTransferFrom(address(this), _consumptionPlantAddress, certificateTokenId, Commons.min(option1, option2), new bytes(0));
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
    function withdrawSurplusCertificates(uint256 _tokenId) external {
        (IEnergyToken.TokenKind tokenKind, uint64 balancePeriod, address generationPlantAddress) = energyToken.getTokenIdConstituents(_tokenId);
        
        // Distributor applicability check. Required because this contract holding the necessary certificates to pay the consumption plant
        // is not sufficient grouns to assume that this is the correct distributor as soon as several forwards may cause payout of the
        // same certificates.
        require(energyToken.id2Distributor(_tokenId) == this, "Distributor contract does not belong to this _tokenId");
        
        // Single execution check
        require(testing || !completedSurplusDistributions[_tokenId][generationPlantAddress], "_generationPlantAddress can only call withdrawSurplusCertificates() once.");
        completedSurplusDistributions[_tokenId][generationPlantAddress] = true;
        
        // Time period check
        require(testing || balancePeriod < Commons.getBalancePeriod(balancePeriodLength, block.timestamp), "balancePeriod has not yet ended.");
        
        uint256 certificateTokenId = energyToken.getTokenId(IEnergyToken.TokenKind.Certificate, balancePeriod, generationPlantAddress, 0);
        
        // Surplus Distribution
        if(tokenKind == IEnergyToken.TokenKind.AbsoluteForward) {
            uint256 totalForwards = energyToken.totalSupply(_tokenId);
            (, uint256 generatedEnergy, , bool generated, ) = energyToken.energyDocumentations(generationPlantAddress, balancePeriod);
            require(generated, "Generation plant has not produced any energy.");
            if(generatedEnergy > totalForwards) {
                energyToken.safeTransferFrom(address(this), generationPlantAddress, certificateTokenId, generatedEnergy - totalForwards, new bytes(0));
            }
            return;
        }
        
        if(tokenKind == IEnergyToken.TokenKind.ConsumptionBasedForward) {
            // Only allow transfer of undistributable certificates if all consumption plants have gotten their certificates because otherwise it's not possible to figure out how many certificates are undistributable.
            require(energyToken.numberOfRelevantConsumptionPlantsForGenerationPlant(balancePeriod, generationPlantAddress) == numberOfCompletedConsumptionBasedDistributions[balancePeriod][generationPlantAddress], "Transfer of undistributable certificates is only allowed after all consumption plants have received their certificates.");
            uint256 distributorCertificatesBalance = energyToken.balanceOf(address(this), certificateTokenId);
            energyToken.safeTransferFrom(address(this), generationPlantAddress, certificateTokenId, distributorCertificatesBalance, new bytes(0));
            return;
        }
        
        require(false, "Inapplicable token kind.");
    }
}
