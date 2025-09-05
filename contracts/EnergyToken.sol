// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "./Commons.sol";
import "./IdentityContractFactory.sol";
import "./ClaimVerifier.sol";
import "./IEnergyToken.sol";
import "./EnergyTokenLib.sol";
import "./../dependencies/erc-1155/contracts/ERC1155.sol";
import "./IERC165.sol";

/**
 * The EnergyToken contract manages forwards and certificates.
 */
contract EnergyToken is ERC1155, IEnergyToken, IERC165 {
    enum PlantType {Generation, Consumption}

    event EnergyDocumented(PlantType plantType, uint256 value, address indexed plant, bool corrected, uint64 indexed balancePeriod, address indexed meteringAuthority);
    event ForwardsCreated(TokenKind tokenKind, uint64 balancePeriod, AbstractDistributor distributor, uint256 id);
    event TokenFamilyCreation(uint248);
    event BalanceConvertedToSoulbound(uint256 tokenId, address owner, uint256 value);
    
    // id => whetherCreated
    mapping (uint256 => bool) createdForwards;
    
    IdentityContract public marketAuthority;

    mapping(address => mapping(uint64 => EnergyTokenLib.EnergyDocumentation)) public energyDocumentations;
    mapping(address => mapping(uint64 => uint256)) storagePlantEnergyUsedForTemporalTransportation;
    mapping(uint64 => mapping(address => uint256)) public energyConsumedRelevantForGenerationPlant;
    mapping(uint64 => mapping(address => address[])) relevantGenerationPlantsForConsumptionPlant;
    mapping(uint64 => mapping(address => uint256)) public numberOfRelevantConsumptionPlantsUnmeasuredForGenerationPlant;
    mapping(uint64 => mapping(address => uint256)) public numberOfRelevantConsumptionPlantsForGenerationPlant;
    mapping(uint256 => AbstractDistributor) public id2Distributor;
    mapping(uint64 => mapping(address => EnergyTokenLib.ForwardKindOfGenerationPlant)) public forwardKindOfGenerationPlant;
    mapping(uint248 => EnergyTokenLib.TokenFamilyProperties) public tokenFamilyProperties;
    
    bool reentrancyLock;
    modifier noReentrancy {
        require(!reentrancyLock);
        reentrancyLock = true;
        _;
        reentrancyLock = false;
    }
    
    modifier onlyMeteringAuthorities {
        require(ClaimVerifier.getClaimOfType(marketAuthority, msg.sender, "", ClaimCommons.ClaimType.IsMeteringAuthority) != 0, "Invalid IsMeteringAuthority claim.");
        _;
    }
    
    modifier onlyGenerationPlants(address _plant, uint64 _balancePeriod) {
        ClaimVerifier.f_onlyGenerationPlants(marketAuthority, _plant, _balancePeriod);
        _;
    }
    
    modifier onlyStoragePlants(address _plant, uint64 _balancePeriod) {
        ClaimVerifier.f_onlyStoragePlants(marketAuthority, _plant, _balancePeriod);
        _;
    }
    
    modifier onlyGenerationOrStoragePlants(address _plant, uint64 _balancePeriod) {
        ClaimVerifier.f_onlyGenerationOrStoragePlants(marketAuthority, _plant, _balancePeriod);
        _;
    }
    
    modifier onlyDistributors(address _distributor, uint64 _balancePeriod) {
        require(ClaimVerifier.getClaimOfType(marketAuthority, _distributor, "", ClaimCommons.ClaimType.AcceptedDistributorClaim, _balancePeriod) != 0, "Invalid AcceptedDistributorClaim.");
        _;
    }

    constructor(IdentityContract _marketAuthority) {
        marketAuthority = _marketAuthority;
    }
    
    // For the definitions of the interface identifiers, see InterfaceIds.sol.
    function supportsInterface(bytes4 interfaceID) override(IERC165, ERC1155) external pure returns (bool) {
        return
            interfaceID == 0x01ffc9a7 ||
            interfaceID == 0xd9b67a26 ||
            interfaceID == 0x16c97c18;
    }
    
    function decimals() external override(IEnergyToken) pure returns (uint8) {
        return 18;
    }
    
    function mint(uint256 _id, address[] calldata _to, uint256[] calldata _quantities) external override(IEnergyToken) noReentrancy {
        address payable generationPlantP;
        string memory realWorldPlantId;
        { // Block for avoiding stack too deep error.
        // Token needs to be mintable.
        (TokenKind tokenKind, uint64 balancePeriod, address generationPlant) = getTokenIdConstituents(_id);
        generationPlantP = payable(generationPlant);
        require(tokenKind == TokenKind.AbsoluteForward || tokenKind == TokenKind.ConsumptionBasedForward || tokenKind == TokenKind.PropertyForward, "tokenKind cannot be minted.");
        
        // Just required for nicer error messages.
        require(generationPlant != address(0), "Token family needs to be created first.");
        
        // msg.sender needs to be allowed to mint.
        require(msg.sender == generationPlant, "msg.sender needs to be allowed to mint.");
        
        // Forwards can only be minted prior to their balance period.
        require(balancePeriod > marketAuthority.getBalancePeriod(block.timestamp), "Wrong balance period.");
        
        // Forwards must have been created.
        require(id2Distributor[_id] != AbstractDistributor(address(0)), "Forwards not created.");
        
        realWorldPlantId = ClaimVerifier.getRealWorldPlantId(marketAuthority, generationPlantP);
        require(ClaimVerifier.getClaimOfTypeWithMatchingField(marketAuthority, generationPlant, realWorldPlantId, ClaimCommons.ClaimType.ExistenceClaim, "type", "generation", marketAuthority.getBalancePeriod(block.timestamp)) != 0 ||
          ClaimVerifier.getClaimOfTypeWithMatchingField(marketAuthority, generationPlant, realWorldPlantId, ClaimCommons.ClaimType.ExistenceClaim, "type", "storage", marketAuthority.getBalancePeriod(block.timestamp)) != 0, "Invalid ExistenceClaim.");
        EnergyTokenLib.checkClaimsForTransferSending(marketAuthority, id2Distributor, generationPlantP, realWorldPlantId, _id);
        }

        // Perform a mint operation for each recipient.
        for (uint256 i = 0; i < _to.length; ++i) {
            address to = _to[i];
            uint256 quantity = _quantities[i];

            require(to != address(0x0), "_to must be non-zero.");

            if(to != msg.sender) {
                EnergyTokenLib.checkClaimsForTransferReception(marketAuthority, id2Distributor, payable(to), ClaimVerifier.getRealWorldPlantId(marketAuthority, to), _id);
            }

            // Grant the items to the caller.
            mint(to, _id, quantity);

            // In the case of absolute forwards, require that the increased supply is not above the plant's capability if a MaxPowerGenerationClaim exists.
            TokenKind tokenKind = EnergyTokenLib.tokenKindFromTokenId(_id);
            if(tokenKind == TokenKind.AbsoluteForward) {
                (uint64 balancePeriodLength, , ) = marketAuthority.balancePeriodConfiguration();
                uint256 maxGen = EnergyTokenLib.getPlantGenerationCapability(marketAuthority, generationPlantP, realWorldPlantId);
                // Only check capability if max generation capability is known.
                if(maxGen != 0) {
                    require(supply[_id] * (1000 * 3600) <= maxGen * balancePeriodLength * 10**18, "Plant's capability exceeded.");
                }
            }

            // Emit the Transfer/Mint event.
            // The 0x0 source address implies a mint.
            // It will also provide the circulating supply info.
            emit TransferSingle(msg.sender, address(0x0), to, _id, quantity);

            if(to != msg.sender) {
                _doSafeTransferAcceptanceCheck(msg.sender, msg.sender, to, _id, quantity, '');
            }
            
            { // Block for avoiding stack too deep error.
            (, uint64 balancePeriod, address generationPlant) = getTokenIdConstituents(_id);
            if(tokenKind == TokenKind.ConsumptionBasedForward)
                addPlantRelationship(generationPlant, _to[i], balancePeriod);
            }
        }
    }
    
    // A reentrancy lock is not needed for this function because it does not call a different contract.
    // The recipient always is msg.sender. Therefore, _doSafeTransferAcceptanceCheck() is not called.
    function createForwards(uint64 _balancePeriod, TokenKind _tokenKind, SimpleDistributor _distributor) external override(IEnergyToken) onlyGenerationPlants(msg.sender, _balancePeriod) onlyDistributors(address(_distributor), _balancePeriod) {
        require(_tokenKind != TokenKind.Certificate && _tokenKind != TokenKind.PropertyForward, "_tokenKind cannot be Certificate or PropertyForward.");
        require(_balancePeriod > marketAuthority.getBalancePeriod(block.timestamp));
        
        createTokenFamily(_balancePeriod, msg.sender, 0);
        
        uint256 id = getTokenId(_tokenKind, _balancePeriod, msg.sender, 0);
        require(!createdForwards[id], "Forwards have already been created.");
        createdForwards[id] = true;
        
        EnergyTokenLib.setId2Distributor(id2Distributor, id, _distributor);
        EnergyTokenLib.setForwardKindOfGenerationPlant(forwardKindOfGenerationPlant, _balancePeriod, msg.sender, _tokenKind);
        
        emit ForwardsCreated(_tokenKind, _balancePeriod, _distributor, id);
        
        if(_tokenKind == TokenKind.GenerationBasedForward) {
            uint256 value = 100E18;
            mint(msg.sender, id, value);
            emit TransferSingle(msg.sender, address(0x0), msg.sender, id, value);
        }
    }
    
    function createPropertyForwards(uint64 _balancePeriod, ComplexDistributor _distributor, EnergyTokenLib.Criterion[] calldata _criteria) external override(IEnergyToken) onlyStoragePlants(msg.sender, _balancePeriod) onlyDistributors(address(_distributor), _balancePeriod) {
        require(_balancePeriod > marketAuthority.getBalancePeriod(block.timestamp));
        
        bytes32 criteriaHash = keccak256(abi.encode(_criteria));
        createPropertyTokenFamily(_balancePeriod, msg.sender, 0, criteriaHash);
        
        uint256 id = getPropertyTokenId(_balancePeriod, msg.sender, 0, criteriaHash);
        require(!createdForwards[id], "Forwards have already been created.");
        createdForwards[id] = true;
        
        EnergyTokenLib.setId2Distributor(id2Distributor, id, _distributor);
        
        // Do not set forward kind of generation plant because storage plants can have multiple forwards for the same balance period.
        
        emit ForwardsCreated(TokenKind.PropertyForward, _balancePeriod, _distributor, id);
        
        _distributor.setPropertyForwardsCriteria(id, _criteria);
    }

    function addMeasuredEnergyConsumption(address _plant, uint256 _value, uint64 _balancePeriod) external override(IEnergyToken) onlyMeteringAuthorities {
        bool corrected = false;
        // Recognize corrected energy documentations.
        if(energyDocumentations[_plant][_balancePeriod].entered) {
            corrected = true;
        } else {
            address[] storage affectedGenerationPlants = relevantGenerationPlantsForConsumptionPlant[_balancePeriod][_plant];
            for(uint32 i = 0; i < affectedGenerationPlants.length; ++i) {
                energyConsumedRelevantForGenerationPlant[_balancePeriod][affectedGenerationPlants[i]] += _value;
                numberOfRelevantConsumptionPlantsUnmeasuredForGenerationPlant[_balancePeriod][affectedGenerationPlants[i]]--;
            }
        }

        addMeasuredEnergyConsumption_capabilityCheck(_plant, _value);

        energyDocumentations[_plant][_balancePeriod] = EnergyTokenLib.EnergyDocumentation(IdentityContract(msg.sender), _value, corrected, false, true);
        emit EnergyDocumented(PlantType.Consumption, _value, _plant, corrected, _balancePeriod, msg.sender);
    }
    
    function addMeasuredEnergyGeneration(address _plant, uint256 _value, uint64 _balancePeriod) external override(IEnergyToken) onlyMeteringAuthorities onlyGenerationOrStoragePlants(_plant, marketAuthority.getBalancePeriod(block.timestamp)) noReentrancy {
        bool corrected = false;
        // Recognize corrected energy documentations.
        if(energyDocumentations[_plant][_balancePeriod].entered) {
            corrected = true;
        }
        
        // Don't allow documentation of a reading above capability.
        addMeasuredEnergyGeneration_capabilityCheck(_plant, _value);

        EnergyTokenLib.EnergyDocumentation memory energyDocumentation = EnergyTokenLib.EnergyDocumentation(IdentityContract(msg.sender), _value, corrected, true, true);
        energyDocumentations[_plant][_balancePeriod] = energyDocumentation;
        
        // Mint certificates unless correcting.
        if(!corrected) {
            EnergyTokenLib.ForwardKindOfGenerationPlant memory forwardKind = forwardKindOfGenerationPlant[_balancePeriod][_plant];

            // If the forwards were not created, send the certificates to the generation plant. Otherwise, send them to the distributor of the forwards.
            address certificateReceiver;
            if(!forwardKind.set) {
                // When sending certificates directly to the receiver, the token family needs to be created here.
                // This is because function createForwards() was never called, which is how token famalies are
                // created in the case of certificates with forwards associated with them.
                createTokenFamily(_balancePeriod, _plant, 0);
                
                certificateReceiver = _plant;
            } else {
                uint256 forwardId = getTokenId(forwardKind.forwardKind, _balancePeriod, _plant, 0);
                AbstractDistributor distributor = id2Distributor[forwardId];
                certificateReceiver = address(distributor);
            }

            uint256 certificateId = getTokenId(TokenKind.Certificate, _balancePeriod, _plant, 0);
            if(_value > 0) {
                mint(certificateReceiver, certificateId, _value);
                // Emit the Transfer/Mint event.
                // the 0x0 source address implies a mint
                // It will also provide the circulating supply info.
                emit TransferSingle(msg.sender, address(0), certificateReceiver, certificateId, _value);
                // Do not call _doSafeTransferAcceptanceCheck because the recipient must accept the certificates.
            }
        }
        emit EnergyDocumented(PlantType.Generation, _value, _plant, corrected, _balancePeriod, msg.sender);        
    }
    
    function createTokenFamily(uint64 _balancePeriod, address _generationPlant, uint248 _previousTokenFamilyBase) override(IEnergyToken) public {
        uint248 tokenFamilyBase = uint248(uint256(keccak256(abi.encodePacked(_balancePeriod, _generationPlant, _previousTokenFamilyBase))));
        tokenFamilyProperties[tokenFamilyBase] = EnergyTokenLib.TokenFamilyProperties(_balancePeriod, _generationPlant, _previousTokenFamilyBase);
        emit TokenFamilyCreation(tokenFamilyBase);
    }
    
    function createPropertyTokenFamily(uint64 _balancePeriod, address _generationPlant, uint248 _previousTokenFamilyBase, bytes32 _criteriaHash) override(IEnergyToken) public {
        uint248 tokenFamilyBase = uint248(uint256(keccak256(abi.encodePacked(_balancePeriod, _generationPlant, _previousTokenFamilyBase, _criteriaHash))));
        tokenFamilyProperties[tokenFamilyBase] = EnergyTokenLib.TokenFamilyProperties(_balancePeriod, _generationPlant, _previousTokenFamilyBase);
        emit TokenFamilyCreation(tokenFamilyBase);
    }
    
    function temporallyTransportCertificates(uint256 _originalCertificateId, uint256 _targetForwardId, uint256 _value) external
      onlyDistributors(msg.sender, uint64(block.timestamp)) override(IEnergyToken) returns(uint256 __targetCertificateId) {
        // Prepare variables.
        uint64 balancePeriod = tokenFamilyProperties[uint248(_targetForwardId)].balancePeriod;
        address storagePlant = tokenFamilyProperties[uint248(_targetForwardId)].generationPlant;

        // Make sure that energy can only flow into the future.
        (, uint64 balancePeriodOriginalCertificates,) = getTokenIdConstituents(_originalCertificateId);
        require(balancePeriodOriginalCertificates < balancePeriod, "energy must flow into the future");
        
        // Make sure that the storage plant has transported enough energy temporally.
        // Note that correcting documentations affect the behavior of this function.
        EnergyTokenLib.EnergyDocumentation storage energyDocumentation = energyDocumentations[storagePlant][balancePeriod];
        require(energyDocumentation.generated, "The storage plant has not generated any energy.");
        storagePlantEnergyUsedForTemporalTransportation[storagePlant][balancePeriod] += _value;
        require(storagePlantEnergyUsedForTemporalTransportation[storagePlant][balancePeriod] <= energyDocumentation.value, "The storage plant has not generated enough energy.");
        
        // Create the new token family (idempotent operation).
        createTokenFamily(balancePeriod, storagePlant, uint248(_originalCertificateId));
        __targetCertificateId = getTokenId(TokenKind.Certificate, balancePeriod, storagePlant, uint248(_originalCertificateId));
        
        // Perform the actual temporal transportation.
        burn(msg.sender, _originalCertificateId, _value);
        mint(msg.sender, __targetCertificateId, _value);
    }

    function makeSoulbound(uint256 _id, uint256 _value) external {
        require(balances[_id][msg.sender] >= _value, "insuficient funds");
        balances[_id][msg.sender] -= _value;
        balancesSoulbound[_id][msg.sender] += _value;
        emit BalanceConvertedToSoulbound(_id, msg.sender, _value);
    }
    
    // ########################
    // # Overridden ERC-1155 functions
    // ########################
    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes calldata _data) override(ERC1155, IEnergyToken) external noReentrancy {
        (TokenKind tokenKind, uint64 balancePeriod, address generationPlant) = getTokenIdConstituents(_id);
        require(supply[_id] != 0, "Token does not exist.");

        if(tokenKind == TokenKind.Certificate) {
            (, , uint64 certificateTradingWindow) = marketAuthority.balancePeriodConfiguration();
            require(balancePeriod + certificateTradingWindow > marketAuthority.getBalancePeriod(block.timestamp),
              "balancePeriod must be within the certificate trading window.");
        } else {
            require(balancePeriod > marketAuthority.getBalancePeriod(block.timestamp), "balancePeriod must be in the future.");
        }
        
        if(tokenKind == TokenKind.ConsumptionBasedForward)
            addPlantRelationship(generationPlant, _to, balancePeriod);
        
        bool performSafeTransferAcceptanceCheck = true;
        // This needs to be checked because otherwise distributors would need real world plant IDs
        // as without them, getting the real world plant ID to pass on to checkClaimsForTransferSending
        // and checkClaimsForTransferReception would cause a revert.
        if(_data.length > 0) {
            (uint256 forwardId) = abi.decode(_data, (uint256));
            if(id2Distributor[forwardId] == AbstractDistributor(_from)) {
                // No requirements if the sender is a distributor.
                // Not even the acceptance check.
                performSafeTransferAcceptanceCheck = false;
            } else {
                require(ClaimVerifier.getClaimOfType(marketAuthority, _to, "", ClaimCommons.ClaimType.AcceptedDistributorClaim, marketAuthority.getBalancePeriod(block.timestamp)) != 0,
                "Must be from or to distributor."); // May be intended to be from or to distributor as the forward ID check cannot tell the user's intention.
                // If the require was passed, the user's intention is to send to a distributor.
                // Therefore, only the sender's claims need to be checked.
                string memory realWorldPlantIdFrom = ClaimVerifier.getRealWorldPlantId(marketAuthority, _from);
                EnergyTokenLib.checkClaimsForTransferSending(marketAuthority, id2Distributor, payable(_from), realWorldPlantIdFrom, _id);
            }
        } else {
            checkClaimsForTransferAllIncluded(_from, _to, _id);
        }

        // ########################
        // ERC1155.safeTransferFrom(_from, _to, _id, _value, _data);
        // ########################
        require(_from == msg.sender || operatorApproval[_from][msg.sender] == true, "Need operator approval.");

        // SafeMath will throw with insuficient funds _from
        // or if _id is not valid (balance will be 0).
        // This require() is for better error messages.
        require(balances[_id][_from] >= _value, "insuficient funds");
        balances[_id][_from] -= _value;
        balances[_id][_to]   += _value;

        // MUST emit event
        emit TransferSingle(msg.sender, _from, _to, _id, _value);

        // Now that the balance is updated and the event was emitted,
        // call onERC1155Received. The destination always is a contract.
        if(performSafeTransferAcceptanceCheck) {
            _doSafeTransferAcceptanceCheck(msg.sender, _from, _to, _id, _value, _data);
        }
    }
    
    /**
    * This function is disabled because it's difficult to write without exceeding the limit
    * on the number of items on the stack and because it would exceed the block gas limit anyway.
    *
    * Make sure to comment noReentrancy back in when re-activating this function (it's commented
    * out to avoid a compiler warning about unreachable code). Also: remove keyword 'pure'.
    */
    function safeBatchTransferFrom(address /*_from*/, address /*_to*/, uint256[] calldata /*_ids*/, uint256[] calldata /*_values*/, bytes calldata /*_data*/) override(ERC1155, IEnergyToken) external /*noReentrancy*/ pure {
        revert("safeBatchTransferFrom is disabled");
        /*
        uint64 currentBalancePeriod = marketAuthority.getBalancePeriod(block.timestamp);
        
        if(_data.length > 0) {
            (uint256 forwardId) = abi.decode(_data, (uint256));
            require(
                id2Distributor[forwardId] == AbstractDistributor(_from) ||
                (ClaimVerifier.getClaimOfType(marketAuthority, _to, "", ClaimCommons.ClaimType.AcceptedDistributorClaim, currentBalancePeriod) != 0 && true),
                "Must be from or to distributor."
            );
        }

        bool performSafeTransferAcceptanceCheck = true;
        if(_data.length > 0) {
            (uint256 forwardId) = abi.decode(_data, (uint256));
            if(id2Distributor[forwardId] == AbstractDistributor(_from)) {
                // No requirements if the sender is a distributor.
                // Not even the acceptance check.
                performSafeTransferAcceptanceCheck = false;
            } else {
                require(ClaimVerifier.getClaimOfType(marketAuthority, _to, "", ClaimCommons.ClaimType.AcceptedDistributorClaim, currentBalancePeriod) != 0,
                "Must be from or to distributor."); // May be intended to be from or to distributor as the forward ID check cannot tell the user's intention.
                // If the require was passed, the user's intention is to send to a distributor.
                // Therefore, only the sender's claims need to be checked.
                string memory realWorldPlantIdFrom = ClaimVerifier.getRealWorldPlantId(marketAuthority, _from);
                for (uint256 i = 0; i < _ids.length; ++i) {
                    EnergyTokenLib.checkClaimsForTransferSending(marketAuthority, id2Distributor, payable(_from), realWorldPlantIdFrom, _ids[i]);
                }
            }
        } else {
            for (uint256 i = 0; i < _ids.length; ++i) {
                checkClaimsForTransferAllIncluded(_from, _to, _ids[i]);
            }
        }
        
        (, , uint64 certificateTradingWindow) = marketAuthority.balancePeriodConfiguration();
        for (uint256 i = 0; i < _ids.length; ++i) {
            (TokenKind tokenKind, uint64 balancePeriod, address generationPlant) = getTokenIdConstituents(_ids[i]);
            if(tokenKind == TokenKind.Certificate) {
                require(balancePeriod + certificateTradingWindow > currentBalancePeriod,
                  "balancePeriod must be within the certificate trading window.");
            } else {
                require(balancePeriod > currentBalancePeriod, "balancePeriod must be in the future.");
            }
            
            if(tokenKind == TokenKind.ConsumptionBasedForward)
                addPlantRelationship(generationPlant, _to, balancePeriod);
        }
        
        // ########################
        // ERC1155.safeBatchTransferFrom(_from, _to, _ids, _values, _data);
        // ########################
        // MUST Throw on errors
        require(_ids.length == _values.length, "_ids and _values array length must match.");
        require(_from == msg.sender || operatorApproval[_from][msg.sender] == true, "Need operator approval for 3rd party transfers.");

        for (uint256 i = 0; i < _ids.length; ++i) {
            uint256 id = _ids[i];
            uint256 value = _values[i];

            // SafeMath will throw with insuficient funds _from
            // or if _id is not valid (balance will be 0)
            balances[id][_from] -= value;
            balances[id][_to]   += value;
        }

        // Note: instead of the below batch versions of event and acceptance check you MAY have emitted a TransferSingle
        // event and a subsequent call to _doSafeTransferAcceptanceCheck in above loop for each balance change instead.
        // Or emitted a TransferSingle event for each in the loop and then the single _doSafeBatchTransferAcceptanceCheck below.
        // However it is implemented the balance changes and events MUST match when a check (i.e. calling an external contract) is done.

        // MUST emit event
        emit TransferBatch(msg.sender, _from, _to, _ids, _values);

        // Now that the balances are updated and the events are emitted,
        // call onERC1155BatchReceived. The destination always is a contract.
        if(performSafeTransferAcceptanceCheck) {
            _doSafeBatchTransferAcceptanceCheck(msg.sender, _from, _to, _ids, _values, _data);
        }
        */
    }
    
    function checkClaimsForTransferAllIncluded(address _from, address _to, uint256 _id) internal view {
        string memory realWorldPlantIdFrom = ClaimVerifier.getRealWorldPlantId(marketAuthority, _from);
        string memory realWorldPlantIdTo = ClaimVerifier.getRealWorldPlantId(marketAuthority, _to);
        EnergyTokenLib.checkClaimsForTransferSending(marketAuthority, id2Distributor, payable(_from), realWorldPlantIdFrom, _id);
        EnergyTokenLib.checkClaimsForTransferReception(marketAuthority, id2Distributor, payable(_to), realWorldPlantIdTo, _id);
    }
    
    
    // ########################
    // # Public support functions
    // ########################

    function getTokenIdConstituents(uint256 _tokenId) public view override(IEnergyToken) returns(TokenKind __tokenKind, uint64 __balancePeriod, address __identityContractAddress) {
        __identityContractAddress = tokenFamilyProperties[uint248(_tokenId)].generationPlant;
        __balancePeriod = tokenFamilyProperties[uint248(_tokenId)].balancePeriod;
        __tokenKind = number2TokenKind(uint8(_tokenId >> 248));
    }
    
    function tokenKind2Number(TokenKind _tokenKind) public pure override(IEnergyToken) returns (uint8 __number) {
        __number = EnergyTokenLib.tokenKind2Number(_tokenKind);
    }
    
    function number2TokenKind(uint8 _number) public pure override(IEnergyToken) returns (TokenKind __tokenKind) {
        __tokenKind = EnergyTokenLib.number2TokenKind(_number);
    }
    
    /**
     * tokenId: tokenKind number (8 bit) || hash (248 bit)
     */
    function getTokenId(TokenKind _tokenKind, uint64 _balancePeriod, address _generationPlant, uint248 _previousTokenFamilyBase) public pure override(IEnergyToken) returns (uint256 __tokenId) {
        __tokenId = uint256(keccak256(abi.encodePacked(_balancePeriod, _generationPlant, _previousTokenFamilyBase)));
        __tokenId = __tokenId & 0x00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff; // Set the most significant byte to 0x00.
        __tokenId = __tokenId + (uint256(tokenKind2Number(_tokenKind)) << 248); // Place the token kind in the left-most byte for easy readability.
    }
    
    function getPropertyTokenId(uint64 _balancePeriod, address _generationPlant, uint248 _previousTokenFamilyBase, bytes32 _criteriaHash) public pure override(IEnergyToken) returns (uint256 __tokenId) {
        __tokenId = uint256(keccak256(abi.encodePacked(_balancePeriod, _generationPlant, _previousTokenFamilyBase, _criteriaHash)));
        __tokenId = __tokenId & 0x00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff; // Set the most significant byte to 0x00.
        __tokenId = __tokenId + (uint256(tokenKind2Number(TokenKind.PropertyForward)) << 248); // Place the token kind in the left-most byte for easy readability.
    }
    
    function getCriteriaHash(EnergyTokenLib.Criterion[] calldata _criteria) external pure override(IEnergyToken) returns(bytes32) {
        return keccak256(abi.encode(_criteria));
    }
    
    function getInitialGenerationPlant(uint256 _tokenId) external view override(IEnergyToken) returns(address __initialGenerationPlant) {
        while(tokenFamilyProperties[uint248(_tokenId)].previousTokenFamilyBase != 0)
            _tokenId = tokenFamilyProperties[uint248(_tokenId)].previousTokenFamilyBase;
        
        __initialGenerationPlant = tokenFamilyProperties[uint248(_tokenId)].generationPlant;
    }
    
    // ########################
    // # Internal functions
    // ########################
    function addPlantRelationship(address _generationPlant, address _consumptionPlant, uint64 _balancePeriod) public {
        relevantGenerationPlantsForConsumptionPlant[_balancePeriod][_consumptionPlant].push(_generationPlant);
        
        if(!energyDocumentations[_consumptionPlant][_balancePeriod].generated)
            require(energyDocumentations[_consumptionPlant][_balancePeriod].value == 0, "_consumptionPlant does already have energyDocumentations for _balancePeriod.");
        
        numberOfRelevantConsumptionPlantsForGenerationPlant[_balancePeriod][_generationPlant]++; // not gonna overflow
        numberOfRelevantConsumptionPlantsUnmeasuredForGenerationPlant[_balancePeriod][_generationPlant]++; // not gonna overflow
    }
    
    function addMeasuredEnergyGeneration_capabilityCheck(address _plant, uint256 _value) internal view {
        // [maxGen] = W
        // [_value] = kWh / 1e18 = 1000 * 3600 / 1e18 * W * s
        // [balancePeriodLength] = s
        
        string memory realWorldPlantId = ClaimVerifier.getRealWorldPlantId(marketAuthority, _plant);
        uint256 maxGen = EnergyTokenLib.getPlantGenerationCapability(marketAuthority, _plant, realWorldPlantId);
        // Only check capability if max generation capability is known.
        if(maxGen == 0) {
            return;
        }
        
        (uint64 balancePeriodLength, , ) = marketAuthority.balancePeriodConfiguration();
        require(_value * 1000 * 3600 <= maxGen * balancePeriodLength * 10**18, "Plant's capability exceeded.");
    }

    function addMeasuredEnergyConsumption_capabilityCheck(address _plant, uint256 _value) internal view {
        // [maxCon] = W
        // [_value] = kWh / 1e18 = 1000 * 3600 / 1e18 * W * s
        // [balancePeriodLength] = s
        
        string memory realWorldPlantId = ClaimVerifier.getRealWorldPlantId(marketAuthority, _plant); 
        uint256 maxCon = EnergyTokenLib.getPlantConsumptionCapability(marketAuthority, _plant, realWorldPlantId);
        // Only check capability if max consumption capability is known.
        if (maxCon == 0) {
            return;
        }
        
        (uint64 balancePeriodLength, , ) = marketAuthority.balancePeriodConfiguration();
        require(_value * 1000 * 3600 <= maxCon * balancePeriodLength * 10**18, "Plant's capability exceeded.");
    }
}
