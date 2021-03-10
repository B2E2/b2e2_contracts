pragma solidity ^0.7.0;

import "./../dependencies/erc-1155/contracts/SafeMath.sol";
import "./../dependencies/openzeppelin-contracts/contracts/cryptography/ECDSA.sol";
import "./Commons.sol";
import "./ClaimCommons.sol";
import "./ClaimVerifier.sol";
import "./IdentityContract.sol";

library IdentityContractLib {
    using SafeMath for uint256;
    
    // Events ERC-725 (partially)
    event ContractCreated(address indexed contractAddress);
    
    // Events ERC-735 (partially)
    event ClaimAdded(uint256 indexed claimId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    event ClaimRemoved(uint256 indexed claimId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    event ClaimChanged(uint256 indexed claimId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    
    // Structs related to ERC-1155
    struct PerishableValue {
        uint256 value;
        uint64 expiryDate;
    }
    
    // Structs ERC-735
    struct Claim {
        uint256 topic;
        uint256 scheme;
        address issuer; // msg.sender
        bytes signature; // this.address + topic + data
        bytes data;
        string uri;
    }
    
    function execute(uint256 _operationType, address _to, uint256 _value, bytes memory _data) public {
        if(_operationType == 0) {
            (bool success, bytes memory returnData) = _to.call{value: _value}(_data);
            if (success == false) {
                assembly {
                    let ptr := mload(0x40)
                    let size := returndatasize()
                    returndatacopy(ptr, 0, size)
                    revert(ptr, size)
                }
            }
            return;
        }
        
        // Copy calldata to memory so it can easily be accessed via assembly.
        bytes memory dataMemory = _data;
        
        if(_operationType == 1) {
            address newContract;
            assembly {
                newContract := create(0, add(dataMemory, 0x20), mload(dataMemory))
            }
            emit ContractCreated(newContract);
            return;
        }
        
        require(false, "Unknown _operationType.");
    }
    
    function execute(address owner, uint256 _executionNonce, uint256 _operationType, address _to, uint256 _value, bytes calldata _data, bytes calldata _signature) external {
        // address(this) needs to be part of the struct so that the tx cannot be replayed to a different IDC owned by the same EOA.
        address signer = ECDSA.recover(keccak256(abi.encodePacked(_operationType, _to, _value, _data, address(this), _executionNonce)), _signature);
        require(signer == owner, "invalid signature / wrong signer / wrong nonce.");
        
        execute(_operationType, _to, _value, _data);
    }
    
    function addClaim(mapping (uint256 => Claim) storage claims, mapping (uint256 => uint256[]) storage topics2ClaimIds, mapping (uint256 => bool) storage burnedClaimIds, IdentityContract marketAuthority, uint256 _topic, uint256 _scheme, address _issuer, bytes memory _signature, bytes memory _data, string memory _uri) public returns (uint256 claimRequestId) {
        // Make sure that claim is correct if the topic is in the relevant range.
        if(_topic >= 10000 && _topic <= 11000) {
            ClaimCommons.ClaimType claimType = ClaimCommons.topic2ClaimType(_topic);
            require(ClaimVerifier.validateClaim(marketAuthority, claimType, address(this), _topic, _scheme, _issuer, _signature, _data), "Invalid claim.");
        }
        
        claimRequestId = getClaimId(_issuer, _topic);
        
        // Check for burned claim IDs.
        if(burnedClaimIds[claimRequestId])
            require(false, "Claim id burned.");
        
        // Emit and modify before adding to save gas.
        if(keccak256(claims[claimRequestId].signature) != keccak256(new bytes(32))) { // Claim existence check since signature cannot be 0.
            emit ClaimAdded(claimRequestId, _topic, _scheme, _issuer, _signature, _data, _uri);
            
            topics2ClaimIds[_topic].push(claimRequestId);
        } else {
            // Make sure that only issuer or holder can change claims
            require(msg.sender == address(this) || msg.sender == _issuer, "Only issuer or holder can change claims.");
            emit ClaimChanged(claimRequestId, _topic, _scheme, _issuer, _signature, _data, _uri);
        }
        
        claims[claimRequestId] = Claim(_topic, _scheme, _issuer, _signature, _data, _uri);
    }
    
    function removeClaim(address owner, mapping (uint256 => Claim) storage claims, mapping (uint256 => uint256[]) storage topics2ClaimIds, mapping (uint256 => bool) storage burnedClaimIds, uint256 _claimId) public returns (bool success) {
        require(msg.sender == owner || msg.sender == claims[_claimId].issuer, "Only issuer or holder can remove claims.");
        
        // Emit event and store burned signature before deleting to save gas for copy.
        IdentityContractLib.Claim storage claim = claims[_claimId];
        emit ClaimRemoved(_claimId, claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri);
        burnedClaimIds[_claimId] = true; // Make sure that this same claim cannot be added again.

        // Delete entries of helper directories.
        // Locate entry in topics2ClaimIds.
        uint32 positionInArray = 0;
        while(positionInArray < topics2ClaimIds[claim.topic].length && _claimId != topics2ClaimIds[claim.topic][positionInArray]) {
            positionInArray++;
        }
        
        // Make sure that the element has actually been found.
        require(positionInArray < topics2ClaimIds[claim.topic].length, "Claim element has not been found.");
        
        // Swap the last element in for it.
        topics2ClaimIds[claim.topic][positionInArray] = topics2ClaimIds[claim.topic][topics2ClaimIds[claim.topic].length - 1];
        
        // Delete the (now duplicated) last entry by shrinking the array.
        topics2ClaimIds[claim.topic].pop();
        
        // Delete the actual directory entry.
        claim.topic = 0;
        claim.scheme = 0;
        claim.issuer = address(0);
        claim.signature = "";
        claim.data = "";
        claim.uri = "";
        
        return true;
    }
    
    function burnClaimId(mapping (uint256 => bool) storage burnedClaimIds, uint256 _topic) public {
        burnedClaimIds[getClaimId(msg.sender, _topic)] = true;
    }
    
    function reinstateClaimId(mapping (uint256 => bool) storage burnedClaimIds, uint256 _topic) public {
        burnedClaimIds[getClaimId(msg.sender, _topic)] = false;
    }
    
    /**
     * Only consumes reception approval when handling forwards. Fails iff granted reception approval does not match.
     */
    function consumeReceptionApproval(mapping (address => mapping (uint256 => mapping(address => IdentityContractLib.PerishableValue))) storage receptionApproval, uint32 balancePeriodLength, uint256 _id, address _from, uint256 _value) public {
        // Accept all certificate ERC-1155 transfers.
        if(isCertificate(_id))
            return;
        
        address energyToken = msg.sender;
        require(receptionApproval[energyToken][_id][_from].value == _value, "Approval for token value does not match.");
        require(receptionApproval[energyToken][_id][_from].expiryDate >= Commons.getBalancePeriod(balancePeriodLength, block.timestamp), "Approval for token reception is expired.");
        
        receptionApproval[energyToken][_id][_from].value = 0;
    }
    
    
    // ########################
    // # Internal functions
    // ########################
    function getClaimId(address _issuer, uint256 _topic) internal pure returns (uint256 __claimRequestId) {
        // TODO: Addition or concatenation?
        bytes memory preimageIssuer = abi.encodePacked(_issuer);
        bytes memory preimageTopic = abi.encodePacked(_topic);
        return uint256(keccak256(abi.encodePacked(preimageIssuer, preimageTopic)));
    }
    
    function isCertificate(uint256 _id) internal pure returns (bool) {
        return (_id & 0x000000ff00000000000000000000000000000000000000000000000000000000) == 0x0000000400000000000000000000000000000000000000000000000000000000;
    }
}
