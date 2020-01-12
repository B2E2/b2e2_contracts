pragma solidity ^0.5.0;

import "../node_modules/openzeppelin-solidity/contracts/cryptography/ECDSA.sol";
import "./ClaimCommons.sol";
import "./ClaimVerifier.sol";
import "./IdentityContract.sol";

library IdentityContractLib {
    // Events ERC-725
    event DataChanged(bytes32 indexed key, bytes value);
    event ContractCreated(address indexed contractAddress);
    event OwnerChanged(address indexed ownerAddress);
    
    // Events ERC-735
    event ClaimRequested(uint256 indexed claimRequestId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    event ClaimAdded(bytes32 indexed claimId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    event ClaimRemoved(bytes32 indexed claimId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    event ClaimChanged(bytes32 indexed claimId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    
    // Structs ERC-735
    struct Claim {
        uint256 topic;
        uint256 scheme;
        address issuer; // msg.sender
        bytes signature; // this.address + topic + data
        bytes data;
        string uri;
    }
    
    // Constants ERC-735
    bytes constant public ETH_PREFIX = "\x19Ethereum Signed Message:\n32";
    uint256 constant public ECDSA_SCHEME = 1;
    
    function addClaim(mapping (bytes32 => Claim) storage claims, mapping (uint256 => bytes32[]) storage topics2ClaimIds, IdentityContract marketAuthority, uint256 _topic, uint256 _scheme, address _issuer, bytes memory _signature, bytes memory _data, string memory _uri) public returns (bytes32 claimRequestId) {
        ClaimCommons.ClaimType claimType = ClaimCommons.topic2ClaimType(_topic);
        require(keccak256(_signature) != keccak256(new bytes(32))); // Just to be safe. (See existence check below.)
        
        // Make sure that claim is correct if the topic is in the relevant range.
        if(_topic > 10000 && _topic < 11000) {
            require(ClaimVerifier.validateClaim(marketAuthority, claimType, _topic, _scheme, _issuer, _signature, _data));
        }
        
        // TODO: Addition or concatenation?
        bytes memory preimageIssuer;
        bytes memory preimageTopic;
        assembly {
             mstore(add(preimageIssuer, 20), _issuer)
             mstore(add(preimageTopic, 32), _topic)
        }
        claimRequestId = keccak256(abi.encodePacked(preimageIssuer, preimageTopic));
        
        // Emit and modify before adding to save gas.
        if(keccak256(claims[claimRequestId].signature) != keccak256(new bytes(32))) { // Claim existence check since signature cannot be 0.
            emit ClaimAdded(claimRequestId, _topic, _scheme, _issuer, _signature, _data, _uri);
            
            uint256 prevTopicCardinality = topics2ClaimIds[_topic].length;
            topics2ClaimIds[_topic].length = prevTopicCardinality + 1;
            topics2ClaimIds[_topic][prevTopicCardinality] = claimRequestId;
        } else {
            // Make sure that only issuer or holder can change claims
            require(msg.sender == address(this) || msg.sender == _issuer);
            emit ClaimChanged(claimRequestId, _topic, _scheme, _issuer, _signature, _data, _uri);
        }
        
        claims[claimRequestId] = Claim(_topic, _scheme, _issuer, _signature, _data, _uri);
    }
}