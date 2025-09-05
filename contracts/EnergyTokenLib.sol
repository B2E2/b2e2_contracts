// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "./IEnergyToken.sol";
import "./ClaimVerifier.sol";
import "./AbstractDistributor.sol";

/**
 * This library contains functionality that contains the EnergyToken contract.
 */
library EnergyTokenLib {
    struct EnergyDocumentation {
        IdentityContract documentingMeteringAuthority;
        uint256 value;
        bool corrected;
        bool generated;
        bool entered;
    }
    
    struct ForwardKindOfGenerationPlant {
        IEnergyToken.TokenKind forwardKind;
        bool set;
    }
    
    struct TokenFamilyProperties {
        uint64 balancePeriod;
        address generationPlant;
        uint248 previousTokenFamilyBase;
    }
    
    // When stating criteria, make sure to set the value field correctly.
    // EQUALITY COMPARISON VIA eq IS PERFORMED ON A BYTE LEVEL.
    // THIS MEANS THAT NUMBERS IN CLAIMS ARE TREATED AS UTF-8 STRINGS.
    // Example: If a field is supposed to be set to 300000000, you can use
    // this JS code to compute the value of the value field to give to web3:
    // '0x' + Buffer.from('300000000', 'utf8').toString('hex')
    enum Operator {eq, leq, geq}
    struct Criterion {
        uint256 topicId;
        string fieldName;
        Operator operator;
        bytes fieldValue;
    }
    
    // ########################
    // # Public support functions
    // ########################

    /**
     * | Bit (rtl) | Meaning                                         |
     * |-----------+-------------------------------------------------|
     * |         0 | Genus (Generation-based 0; Consumption-based 1) |
     * |         1 | Genus (Absolute 0; Relative 1)                  |
     * |         2 | Family (Forwards 0; Certificates 1)             |
     * |         3 | Order (Simple forwards 0; Property Forwards 1)  |
     * |         4 |                                                 |
     * |         5 |                                                 |
     * |         6 |                                                 |
     * |         7 |                                                 |
     * 
     * Bits are zero unless specified otherwise.
     */
    function tokenKind2Number(IEnergyToken.TokenKind _tokenKind) public pure returns (uint8 __number) {
        if(_tokenKind == IEnergyToken.TokenKind.AbsoluteForward) {
            return 0;
        }
        if(_tokenKind == IEnergyToken.TokenKind.GenerationBasedForward) {
            return 2;
        }
        if(_tokenKind == IEnergyToken.TokenKind.ConsumptionBasedForward) {
            return 3;
        }
        if(_tokenKind == IEnergyToken.TokenKind.Certificate) {
            return 4;
        }
        if(_tokenKind == IEnergyToken.TokenKind.PropertyForward) {
            return 8;
        }
        
        // Invalid TokenKind.
        require(false, "Invalid TokenKind.");
    }
    
    function number2TokenKind(uint8 _number) public pure returns (IEnergyToken.TokenKind __tokenKind) {
        if(_number == 0) {
            return IEnergyToken.TokenKind.AbsoluteForward;
        }
        if(_number == 2) {
            return IEnergyToken.TokenKind.GenerationBasedForward;
        }
        if(_number == 3) {
            return IEnergyToken.TokenKind.ConsumptionBasedForward;
        }
        if(_number == 4) {
            return IEnergyToken.TokenKind.Certificate;
        }
        if(_number == 8) {
            return IEnergyToken.TokenKind.PropertyForward;
        }
        
        // Invalid number.
        require(false, "Invalid number.");
    }
    
    function tokenKindFromTokenId(uint256 _id) public pure returns(IEnergyToken.TokenKind __tokenKind) {
        __tokenKind = number2TokenKind(uint8(_id >> 248));
    }
    
    /**
     * Checks all claims required for the particular given transfer regarding the sending side.
     */
    function checkClaimsForTransferSending(IdentityContract marketAuthority, mapping(uint256 => AbstractDistributor) storage id2Distributor,
      address payable _from, string memory _realWorldPlantId, uint256 _id) public view {
        IEnergyToken.TokenKind tokenKind = tokenKindFromTokenId(_id);
        
        uint256 balanceClaimId = ClaimVerifier.getClaimOfType(marketAuthority, _from, _realWorldPlantId, ClaimCommons.ClaimType.BalanceClaim);
        require(balanceClaimId != 0, "Invalid BalanceClaim.");
        require(ClaimVerifier.getClaimOfType(marketAuthority, _from, _realWorldPlantId, ClaimCommons.ClaimType.ExistenceClaim) != 0, "Invalid ExistenceClaim.");
        require(ClaimVerifier.getClaimOfType(marketAuthority, _from, _realWorldPlantId, ClaimCommons.ClaimType.MeteringClaim) != 0, "Invalid MeteringClaim.");
        
        if(tokenKind != IEnergyToken.TokenKind.Certificate) {
            (, , address balanceAuthoritySender, , ,) = IdentityContract(_from).getClaim(balanceClaimId);
            AbstractDistributor distributor = id2Distributor[_id];
            require(ClaimVerifier.getClaimOfTypeByIssuer(marketAuthority, address(distributor), ClaimCommons.ClaimType.AcceptedDistributorClaim, balanceAuthoritySender) != 0, "Invalid AcceptedDistributorClaim.");
        }
    }
    
    /**
     * Checks all claims required for the particular given transfer regarding the reception side.
     */
    function checkClaimsForTransferReception(IdentityContract marketAuthority, mapping(uint256 => AbstractDistributor) storage id2Distributor,
      address payable _to, string memory _realWorldPlantId, uint256 _id) public view {
        IEnergyToken.TokenKind tokenKind = tokenKindFromTokenId(_id);
        
        uint256 balanceClaimId = ClaimVerifier.getClaimOfType(marketAuthority, _to, _realWorldPlantId, ClaimCommons.ClaimType.BalanceClaim);
        require(balanceClaimId != 0, "Invalid BalanceClaim.");
        require(ClaimVerifier.getClaimOfType(marketAuthority, _to, _realWorldPlantId, ClaimCommons.ClaimType.ExistenceClaim) != 0, "Invalid ExistenceClaim." );
        require(ClaimVerifier.getClaimOfType(marketAuthority, _to, _realWorldPlantId, ClaimCommons.ClaimType.MeteringClaim) != 0, "Invalid MeteringClaim.");

        if(tokenKind != IEnergyToken.TokenKind.Certificate) {
            (, , address balanceAuthorityReceiver, , ,) = IdentityContract(_to).getClaim(balanceClaimId);
            AbstractDistributor distributor = id2Distributor[_id];
            require(ClaimVerifier.getClaimOfTypeByIssuer(marketAuthority, address(distributor), ClaimCommons.ClaimType.AcceptedDistributorClaim, balanceAuthorityReceiver) != 0,
                "Invalid AcceptedDistributorClaim.");
        }
    }
    
    // ########################
    // # Internal functions
    // ########################
    function getPlantGenerationCapability(IdentityContract marketAuthority, address _plant, string memory _realWorldPlantId) public view returns (uint256 __maxGen) {
        uint256 maxPowerGenerationClaimId = ClaimVerifier.getClaimOfType(marketAuthority, _plant, _realWorldPlantId, ClaimCommons.ClaimType.MaxPowerGenerationClaim);
        
        if (maxPowerGenerationClaimId == 0)
            return 0;
        
        (, , , , bytes memory claimData, ) = IdentityContract(_plant).getClaim(maxPowerGenerationClaimId);
        __maxGen = ClaimVerifier.getUint256Field("maxGen", claimData);
    }

    function getPlantConsumptionCapability(IdentityContract marketAuthority, address _plant, string memory _realWorldPlantId) internal view returns (uint256 __maxCon) {
        uint256 maxPowerConsumptionClaimId = ClaimVerifier.getClaimOfType(marketAuthority, _plant, _realWorldPlantId, ClaimCommons.ClaimType.MaxPowerConsumptionClaim);

        if (maxPowerConsumptionClaimId == 0)
            return 0;

        (, , , , bytes memory claimData, ) = IdentityContract(_plant).getClaim(maxPowerConsumptionClaimId);
        __maxCon = ClaimVerifier.getUint256Field("maxCon", claimData);
    }

    function setId2Distributor(mapping(uint256 => AbstractDistributor) storage id2Distributor, uint256 _id, AbstractDistributor _distributor) public {
        if(id2Distributor[_id] == _distributor)
            return;
        
        if(id2Distributor[_id] != AbstractDistributor(address(0)))
            require(false, "Distributor _id already used.");
        
        id2Distributor[_id] = _distributor;
    }
    
    function setForwardKindOfGenerationPlant(mapping(uint64 => mapping(address => ForwardKindOfGenerationPlant)) storage forwardKindOfGenerationPlant, uint64 _balancePeriod, address _generationPlant, IEnergyToken.TokenKind _forwardKind) public {
        if(!forwardKindOfGenerationPlant[_balancePeriod][_generationPlant].set) {
            forwardKindOfGenerationPlant[_balancePeriod][_generationPlant].forwardKind = _forwardKind;
            forwardKindOfGenerationPlant[_balancePeriod][_generationPlant].set = true;
        } else {
            require(_forwardKind == forwardKindOfGenerationPlant[_balancePeriod][_generationPlant].forwardKind, "Cannot set _forwardKind.");
        }
    }
}