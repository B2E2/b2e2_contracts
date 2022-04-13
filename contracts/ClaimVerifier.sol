// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "./IERC725.sol";
import "./IERC735.sol";
import "./../dependencies/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "./../dependencies/jsmnSol/contracts/JsmnSolLib.sol";
import "./Commons.sol";
import "./IdentityContract.sol";
import "./IdentityContractLib.sol";
import "./ClaimCommons.sol";

/**
 * This library contains functionality that concerns the verification of claims.
 */
library ClaimVerifier {
    // Constants ERC-735
    uint256 constant public ECDSA_SCHEME = 1;
    
    // JSON parsing constants.
    uint256 constant MAX_NUMBER_OF_JSON_FIELDS = 20;
    
    /**
     * Iff _requiredValidAt is not zero, only claims that are not expired at that time and
     * are already valid at that time are considered. If it is set to zero, no expiration
     * or starting date check is performed.
     */
    function verifyClaim(IdentityContract marketAuthority, address _subject, uint256 _claimId, uint64 _requiredValidAt, bool allowFutureValidity) public view returns(bool __valid) {
        (uint256 topic, uint256 scheme, address issuer, bytes memory signature, bytes memory data, ) = IdentityContract(_subject).getClaim(_claimId);
        ClaimCommons.ClaimType claimType = ClaimCommons.topic2ClaimType(topic);
        
        if(_requiredValidAt != 0) {
            uint64 currentTime = marketAuthority.getBalancePeriod(_requiredValidAt);
            if(getExpiryDate(data) < currentTime || ((!allowFutureValidity) && getStartDate(data) > currentTime))
                return false;
        }
        
        if(claimType == ClaimCommons.ClaimType.IsBalanceAuthority
           || claimType == ClaimCommons.ClaimType.IsMeteringAuthority
           || claimType == ClaimCommons.ClaimType.IsPhysicalAssetAuthority
           || claimType == ClaimCommons.ClaimType.IdentityContractFactoryClaim
           || claimType == ClaimCommons.ClaimType.EnergyTokenContractClaim
           || claimType == ClaimCommons.ClaimType.MarketRulesClaim
           || claimType == ClaimCommons.ClaimType.RealWorldPlantIdClaim) {
            return verifySignature(_subject, topic, scheme, issuer, signature, data);
        }
        
        if(claimType == ClaimCommons.ClaimType.MeteringClaim
           || claimType == ClaimCommons.ClaimType.BalanceClaim
           || claimType == ClaimCommons.ClaimType.ExistenceClaim
           || claimType == ClaimCommons.ClaimType.MaxPowerGenerationClaim
           || claimType == ClaimCommons.ClaimType.MaxPowerConsumptionClaim
           || claimType == ClaimCommons.ClaimType.GenerationTypeClaim
           || claimType == ClaimCommons.ClaimType.LocationClaim
           || claimType == ClaimCommons.ClaimType.AcceptedDistributorClaim) {
            return verifySignature(_subject, topic, scheme, issuer, signature, data) && (getClaimOfType(marketAuthority, address(uint160(issuer)), "", ClaimCommons.getHigherLevelClaim(claimType), _requiredValidAt) != 0);
        }
        
        revert("Claim verification failed because the claim type was not recognized.");
    }
    
    function verifyClaim(IdentityContract marketAuthority, address _subject, uint256 _claimId) public view returns(bool __valid) {
        return verifyClaim(marketAuthority, _subject, _claimId, uint64(block.timestamp), false);
    }
    
    /**
     * This method does not verify that the given claim exists in the contract. It merely checks whether it is a valid claim.
     * 
     * Use this method before adding claims to make sure that only valid claims are added.
     */
    function validateClaim(IdentityContract marketAuthority, ClaimCommons.ClaimType _claimType, address _subject, uint256 _topic, uint256 _scheme, address _issuer, bytes memory _signature, bytes memory _data) public view returns(bool) {
        if(ClaimCommons.claimType2Topic(_claimType) != _topic)
            return false;
       
        if(_claimType == ClaimCommons.ClaimType.IsBalanceAuthority
           || _claimType == ClaimCommons.ClaimType.IsMeteringAuthority
           || _claimType == ClaimCommons.ClaimType.IsPhysicalAssetAuthority
           || _claimType == ClaimCommons.ClaimType.IdentityContractFactoryClaim
           || _claimType == ClaimCommons.ClaimType.EnergyTokenContractClaim
           || _claimType == ClaimCommons.ClaimType.MarketRulesClaim
           || _claimType == ClaimCommons.ClaimType.RealWorldPlantIdClaim) {
            if(_claimType == ClaimCommons.ClaimType.RealWorldPlantIdClaim) {
                if(_issuer != _subject)
                    return false;
            } else {
                if(_issuer != address(marketAuthority))
                    return false;
            }
            
            bool correct = verifySignature(_subject, _topic, _scheme, _issuer, _signature, _data);
            return correct;
        }
        
        if(_claimType == ClaimCommons.ClaimType.MeteringClaim
           || _claimType == ClaimCommons.ClaimType.BalanceClaim
           || _claimType == ClaimCommons.ClaimType.ExistenceClaim
           || _claimType == ClaimCommons.ClaimType.MaxPowerGenerationClaim
           || _claimType == ClaimCommons.ClaimType.MaxPowerConsumptionClaim
           || _claimType == ClaimCommons.ClaimType.GenerationTypeClaim
           || _claimType == ClaimCommons.ClaimType.LocationClaim
           || _claimType == ClaimCommons.ClaimType.AcceptedDistributorClaim) {
            bool correctAccordingToSecondLevelAuthority = verifySignature(_subject, _topic, _scheme, _issuer, _signature, _data);
            return correctAccordingToSecondLevelAuthority;
        }
        
        revert("Claim validation failed because the claim type was not recognized.");
    }
    
    /**
     * Returns the claim ID of a claim of the stated type. Only valid claims are considered.
     * 
     * Iff _requiredValidAt is not zero, only claims that are not expired at that time and are already valid at that time are considered. If it is set to zero, no expiration or startig date check is performed.
     */
    function getClaimOfType(IdentityContract marketAuthority, address _subject, string memory _realWorldPlantId, ClaimCommons.ClaimType _claimType, uint64 _requiredValidAt) public view returns (uint256 __claimId) {
        //return 1; // TODO: REMOVE
        uint256 topic = ClaimCommons.claimType2Topic(_claimType);
        uint256[] memory claimIds = IdentityContract(_subject).getClaimIdsByTopic(topic);
        
        bytes32 realWorldPlantIdHash = keccak256(abi.encodePacked(_realWorldPlantId));
        for(uint64 i = 0; i < claimIds.length; i++) {
            // Checking the claim's type is important because a malicious IDC can return claims of a different topic via getClaimIdsByTopic().
            (uint256 cTopic, , , , bytes memory data,) = IdentityContract(_subject).getClaim(claimIds[i]);
            if(cTopic != topic)
                continue;
            
            if(_claimType == ClaimCommons.ClaimType.MeteringClaim
               || _claimType == ClaimCommons.ClaimType.BalanceClaim
               || _claimType == ClaimCommons.ClaimType.ExistenceClaim
               || _claimType == ClaimCommons.ClaimType.MaxPowerGenerationClaim
               || _claimType == ClaimCommons.ClaimType.MaxPowerConsumptionClaim
               || _claimType == ClaimCommons.ClaimType.GenerationTypeClaim
               || _claimType == ClaimCommons.ClaimType.LocationClaim) {
                if(keccak256(abi.encodePacked(getRealWorldPlantId(data))) != realWorldPlantIdHash)
                    continue;
            }
            
            if(!verifyClaim(marketAuthority, _subject, claimIds[i], _requiredValidAt, false))
                continue;
            
            return claimIds[i];
        }
        
        return 0;
    }
    
    function getClaimOfType(IdentityContract marketAuthority, address _subject, string memory _realWorldPlantId, ClaimCommons.ClaimType _claimType) public view returns (uint256 __claimId) {
        return getClaimOfType(marketAuthority, _subject, _realWorldPlantId, _claimType, marketAuthority.getBalancePeriod(block.timestamp));
    }
    
    function getClaimOfTypeByIssuer(IdentityContract marketAuthority, address _subject, ClaimCommons.ClaimType _claimType, address _issuer, uint64 _requiredValidAt) public view returns (uint256 __claimId) {
        uint256 topic = ClaimCommons.claimType2Topic(_claimType);
        uint256 claimId = IdentityContractLib.getClaimId(_issuer, topic);

        (uint256 cTopic, , , , ,) = IdentityContract(_subject).getClaim(claimId);
        
        if(cTopic != topic)
            return 0;
        
        if(!verifyClaim(marketAuthority, _subject, claimId, _requiredValidAt, false))
            return 0;
        
        return claimId;
    }
    
    function getClaimOfTypeByIssuer(IdentityContract marketAuthority, address _subject, ClaimCommons.ClaimType _claimType, address _issuer) public view returns (uint256 __claimId) {
        return getClaimOfTypeByIssuer(marketAuthority, _subject, _claimType, _issuer, marketAuthority.getBalancePeriod(block.timestamp));
    }
    
    function getClaimOfTypeWithMatchingField(IdentityContract marketAuthority, address _subject, string memory _realWorldPlantId, ClaimCommons.ClaimType _claimType, string memory _fieldName, string memory _fieldContent, uint64 _requiredValidAt) public view returns (uint256 __claimId) {
        uint256 topic = ClaimCommons.claimType2Topic(_claimType);
        uint256[] memory claimIds = IdentityContract(_subject).getClaimIdsByTopic(topic);

        bytes32 realWorldPlantIdHash = keccak256(abi.encodePacked(_realWorldPlantId));
        for(uint64 i = 0; i < claimIds.length; i++) {
            (uint256 cTopic, , , , bytes memory cData,) = IdentityContract(_subject).getClaim(claimIds[i]);
            
            if(cTopic != topic)
                continue;
            
            if(_claimType == ClaimCommons.ClaimType.MeteringClaim
               || _claimType == ClaimCommons.ClaimType.BalanceClaim
               || _claimType == ClaimCommons.ClaimType.ExistenceClaim
               || _claimType == ClaimCommons.ClaimType.MaxPowerGenerationClaim
               || _claimType == ClaimCommons.ClaimType.GenerationTypeClaim
               || _claimType == ClaimCommons.ClaimType.LocationClaim
               || _claimType == ClaimCommons.ClaimType.AcceptedDistributorClaim) {
                if(keccak256(abi.encodePacked(getRealWorldPlantId(cData))) != realWorldPlantIdHash)
                    continue;
            }
            
            if(getClaimOfTypeWithMatchingField_temporalValidityCheck(marketAuthority, _requiredValidAt, cData))
                continue;
            
            if(!verifyClaim(marketAuthority, _subject, claimIds[i]))
                continue;
            
            // Separate function call to avoid stack too deep error.
            if(doesMatchingFieldExist(_fieldName, _fieldContent, cData)) {
                return claimIds[i];
            }
        }
        
        return 0;
    }
    function getClaimOfTypeWithMatchingField_temporalValidityCheck(IdentityContract marketAuthority, uint64 _requiredValidAt, bytes memory cData) internal view returns(bool) {
        return (_requiredValidAt > 0 && getExpiryDate(cData) < marketAuthority.getBalancePeriod(_requiredValidAt));
    }

    function getClaimOfTypeWithGeqField(IdentityContract marketAuthority, address _subject, string memory _realWorldPlantId, ClaimCommons.ClaimType _claimType, string memory _fieldName, string memory _fieldContent, uint64 _requiredValidAt) public view returns (uint256 __claimId) {
        uint256 topic = ClaimCommons.claimType2Topic(_claimType);
        uint256[] memory claimIds = IdentityContract(_subject).getClaimIdsByTopic(topic);

        bytes32 realWorldPlantIdHash = keccak256(abi.encodePacked(_realWorldPlantId));
        for(uint64 i = 0; i < claimIds.length; i++) {
            (uint256 cTopic, , , , bytes memory cData,) = IdentityContract(_subject).getClaim(claimIds[i]);
            
            if(cTopic != topic)
                continue;
            
            if(_claimType == ClaimCommons.ClaimType.MeteringClaim
               || _claimType == ClaimCommons.ClaimType.BalanceClaim
               || _claimType == ClaimCommons.ClaimType.ExistenceClaim
               || _claimType == ClaimCommons.ClaimType.MaxPowerGenerationClaim
               || _claimType == ClaimCommons.ClaimType.GenerationTypeClaim
               || _claimType == ClaimCommons.ClaimType.LocationClaim
               || _claimType == ClaimCommons.ClaimType.AcceptedDistributorClaim) {
                if(keccak256(abi.encodePacked(getRealWorldPlantId(cData))) != realWorldPlantIdHash)
                    continue;
            }
            
            if(getClaimOfTypeWithMatchingField_temporalValidityCheck(marketAuthority, _requiredValidAt, cData))
                continue;
            
            if(!verifyClaim(marketAuthority, _subject, claimIds[i]))
                continue;
            
            // Separate function call to avoid stack too deep error.
            if(doesGeqFieldExist(_fieldName, _fieldContent, cData)) {
                return claimIds[i];
            }
        }
        
        return 0;
    }

    function getClaimOfTypeWithLeqField(IdentityContract marketAuthority, address _subject, string memory _realWorldPlantId, ClaimCommons.ClaimType _claimType, string memory _fieldName, string memory _fieldContent, uint64 _requiredValidAt) public view returns (uint256 __claimId) {
        uint256 topic = ClaimCommons.claimType2Topic(_claimType);
        uint256[] memory claimIds = IdentityContract(_subject).getClaimIdsByTopic(topic);

        bytes32 realWorldPlantIdHash = keccak256(abi.encodePacked(_realWorldPlantId));
        for(uint64 i = 0; i < claimIds.length; i++) {
            (uint256 cTopic, , , , bytes memory cData,) = IdentityContract(_subject).getClaim(claimIds[i]);
            
            if(cTopic != topic)
                continue;
            
            if(_claimType == ClaimCommons.ClaimType.MeteringClaim
               || _claimType == ClaimCommons.ClaimType.BalanceClaim
               || _claimType == ClaimCommons.ClaimType.ExistenceClaim
               || _claimType == ClaimCommons.ClaimType.MaxPowerGenerationClaim
               || _claimType == ClaimCommons.ClaimType.GenerationTypeClaim
               || _claimType == ClaimCommons.ClaimType.LocationClaim
               || _claimType == ClaimCommons.ClaimType.AcceptedDistributorClaim) {
                if(keccak256(abi.encodePacked(getRealWorldPlantId(cData))) != realWorldPlantIdHash)
                    continue;
            }
            
            if(getClaimOfTypeWithMatchingField_temporalValidityCheck(marketAuthority, _requiredValidAt, cData))
                continue;
            
            if(!verifyClaim(marketAuthority, _subject, claimIds[i]))
                continue;
            
            // Separate function call to avoid stack too deep error.
            if(doesLeqFieldExist(_fieldName, _fieldContent, cData)) {
                return claimIds[i];
            }
        }
        
        return 0;
    }
    
    function getUint64Field(string memory _fieldName, bytes memory _data) public pure returns(uint64) {
        int fieldAsInt = JsmnSolLib.parseInt(getStringField(_fieldName, _data));
        require(fieldAsInt >= 0, "fieldAsInt must be greater than or equal to 0.");
        require(fieldAsInt < 0x10000000000000000, "fieldAsInt must be less than 0x10000000000000000.");
        return uint64(uint256(fieldAsInt));
    }

    function getUint256Field(string calldata _fieldName, bytes calldata _data) external pure returns(uint256) {
        int fieldAsInt = JsmnSolLib.parseInt(getStringField(_fieldName, _data));
        require(fieldAsInt >= 0, "fieldAsInt must be greater than or equal to 0.");
        return uint256(fieldAsInt);
    }
    
    function getInt256Field(string memory _fieldName, bytes memory _data) internal pure returns(int256) {
        int fieldAsInt = JsmnSolLib.parseInt(getStringField(_fieldName, _data));
        return fieldAsInt;
    }
    
    function getStringField(string memory _fieldName, bytes memory _data) public pure returns(string memory) {
        string memory json = string(_data);
        (uint exitCode, JsmnSolLib.Token[] memory tokens, uint numberOfTokensFound) = JsmnSolLib.parse(json, MAX_NUMBER_OF_JSON_FIELDS);

        require(exitCode == 0, "Error in getStringField. Exit code is not 0.");
        bytes32 fieldNameHash = keccak256(abi.encodePacked(_fieldName));
        for(uint i = 1; i < numberOfTokensFound; i += 2) {
            JsmnSolLib.Token memory keyToken = tokens[i];
            JsmnSolLib.Token memory valueToken = tokens[i+1];
            
            if(keccak256(abi.encodePacked(JsmnSolLib.getBytes(json, keyToken.start, keyToken.end))) == fieldNameHash) {
                return JsmnSolLib.getBytes(json, valueToken.start, valueToken.end);
            }
        }
        
        revert(string(abi.encodePacked("_fieldName ", _fieldName, " not found.")));
    }
    
    function getExpiryDate(bytes memory _data) public pure returns(uint64) {
        return getUint64Field("expiryDate", _data);
    }
    
    function getRealWorldPlantId(bytes memory _data) public pure returns(string memory) {
        return getStringField("realWorldPlantId", _data);
    }
    
    function getRealWorldPlantId(IdentityContract _marketAuthority, address _plant) public view returns(string memory) {
        uint256 claimId = getClaimOfTypeByIssuer(_marketAuthority, _plant, ClaimCommons.ClaimType.RealWorldPlantIdClaim, _plant);
        (, , , , bytes memory data,) = IdentityContract(_plant).getClaim(claimId);
        return getRealWorldPlantId(data);
    }

    
    function getStartDate(bytes memory _data) public pure returns(uint64) {
        return getUint64Field("startDate", _data);
    }
    
    function verifySignature(address _subject, uint256 _topic, uint256 _scheme, address _issuer, bytes memory _signature, bytes memory _data) public view returns (bool __valid) {
         // Check for currently unsupported signature.
        if(_scheme != ECDSA_SCHEME)
            return false;
        
        address signer = getSignerAddress(claimAttributes2SigningFormat(_subject, _topic, _data), _signature);
        
        if(isContract(_issuer)) {
            return signer == IdentityContract(_issuer).owner();
        } else {
            return signer == _issuer;
        }
    }
    
    // ########################
    // # Modifier functions
    // ########################
    function f_onlyGenerationPlants(IdentityContract marketAuthority, address _plant, uint64 _balancePeriod) public view {
        string memory realWorldPlantId = getRealWorldPlantId(marketAuthority, _plant);
        
        require(getClaimOfType(marketAuthority, _plant, realWorldPlantId, ClaimCommons.ClaimType.BalanceClaim, _balancePeriod) != 0, "Invalid BalanceClaim.");
        require(getClaimOfTypeWithMatchingField(marketAuthority, _plant, realWorldPlantId, ClaimCommons.ClaimType.ExistenceClaim, "type", "generation", _balancePeriod) != 0, "Invalid ExistenceClaim.");
        require(getClaimOfType(marketAuthority, _plant, realWorldPlantId, ClaimCommons.ClaimType.MaxPowerGenerationClaim, _balancePeriod) != 0, "Invalid MaxPowerGenerationClaim.");
        require(getClaimOfType(marketAuthority, _plant, realWorldPlantId, ClaimCommons.ClaimType.MeteringClaim, _balancePeriod) != 0, "Invalid MeteringClaim.");
    }
    
        function f_onlyStoragePlants(IdentityContract marketAuthority, address _plant, uint64 _balancePeriod) public view {
        string memory realWorldPlantId = getRealWorldPlantId(marketAuthority, _plant);
        
        require(getClaimOfType(marketAuthority, _plant, realWorldPlantId, ClaimCommons.ClaimType.BalanceClaim, _balancePeriod) != 0, "Invalid BalanceClaim.");
        require(getClaimOfTypeWithMatchingField(marketAuthority, _plant, realWorldPlantId, ClaimCommons.ClaimType.ExistenceClaim, "type", "storage", _balancePeriod) != 0, "Invalid ExistenceClaim (type storage).");
        require(getClaimOfType(marketAuthority, _plant, realWorldPlantId, ClaimCommons.ClaimType.MaxPowerGenerationClaim, _balancePeriod) != 0, "Invalid MaxPowerGenerationClaim.");
        require(getClaimOfType(marketAuthority, _plant, realWorldPlantId, ClaimCommons.ClaimType.MaxPowerConsumptionClaim, _balancePeriod) != 0, "Invalid MaxPowerConsumptionClaim.");
        require(getClaimOfType(marketAuthority, _plant, realWorldPlantId, ClaimCommons.ClaimType.MeteringClaim, _balancePeriod) != 0, "Invalid MeteringClaim.");
        
    }
    
    function f_onlyGenerationOrStoragePlants(IdentityContract marketAuthority, address _plant, uint64 _balancePeriod) public view {
        string memory realWorldPlantId = getRealWorldPlantId(marketAuthority, _plant);
        
        require(getClaimOfType(marketAuthority, _plant, realWorldPlantId, ClaimCommons.ClaimType.BalanceClaim, _balancePeriod) != 0, "Invalid BalanceClaim.");
        require(getClaimOfTypeWithMatchingField(marketAuthority, _plant, realWorldPlantId, ClaimCommons.ClaimType.ExistenceClaim, "type", "generation", _balancePeriod) != 0
          || getClaimOfTypeWithMatchingField(marketAuthority, _plant, realWorldPlantId, ClaimCommons.ClaimType.ExistenceClaim, "type", "storage", _balancePeriod) != 0, "Invalid ExistenceClaim.");
        require(getClaimOfType(marketAuthority, _plant, realWorldPlantId, ClaimCommons.ClaimType.MaxPowerGenerationClaim, _balancePeriod) != 0, "Invalid MaxPowerGenerationClaim.");
        require(getClaimOfType(marketAuthority, _plant, realWorldPlantId, ClaimCommons.ClaimType.MeteringClaim, _balancePeriod) != 0, "Invalid MeteringClaim.");
    }
    
    // ########################
    // # Internal functions
    // ########################
    function doesMatchingFieldExist(string memory _fieldName, string memory _fieldContent, bytes memory _data) internal pure returns(bool) {
        string memory json = string(_data);
        (uint exitCode, JsmnSolLib.Token[] memory tokens, uint numberOfTokensFound) = JsmnSolLib.parse(json, MAX_NUMBER_OF_JSON_FIELDS);
        require(exitCode == 0, "Error in doesMatchingFieldExist. Exit code is not 0.");
        
        bytes32 fieldNameHash = keccak256(abi.encodePacked(_fieldName));
        bytes32 fieldContentHash = keccak256(abi.encodePacked(_fieldContent));
        for(uint i = 1; i < numberOfTokensFound; i += 2) {
            JsmnSolLib.Token memory keyToken = tokens[i];
            JsmnSolLib.Token memory valueToken = tokens[i+1];

            if((keccak256(abi.encodePacked(JsmnSolLib.getBytes(json, keyToken.start, keyToken.end))) == fieldNameHash) &&
            (keccak256(abi.encodePacked(JsmnSolLib.getBytes(json, valueToken.start, valueToken.end))) == fieldContentHash)) {
                return true;
            }
        }
        return false;
    }

    function doesGeqFieldExist(string memory _fieldName, string memory _fieldContent, bytes memory _data) internal pure returns(bool) {
        return getInt256Field(_fieldName, _data) >= JsmnSolLib.parseInt(_fieldContent);
    }

    function doesLeqFieldExist(string memory _fieldName, string memory _fieldContent, bytes memory _data) internal pure returns(bool) {
        return getInt256Field(_fieldName, _data) <= JsmnSolLib.parseInt(_fieldContent);
    }
    
    function claimAttributes2SigningFormat(address _subject, uint256 _topic, bytes memory _data) internal pure returns (bytes32 __claimInSigningFormat) {
        return keccak256(abi.encodePacked(_subject, _topic, _data));
    }
    
    function getSignerAddress(bytes32 _claimInSigningFormat, bytes memory _signature) internal pure returns (address __signer) {
        return ECDSA.recover(_claimInSigningFormat, _signature);
    }
    
    /**
     * Checks whether the address points to a contract by checking whether there is code
     * for that address.
     * 
     * Is not 100% reliable as someone could state an address and only later deploy a
     * contract to that address.
     * 
     * Source: https://stackoverflow.com/a/40939341
    */
    function isContract(address _addr) internal view returns (bool) {
        uint size;
        assembly { size := extcodesize(_addr) }
        return size > 0;
    }
}
