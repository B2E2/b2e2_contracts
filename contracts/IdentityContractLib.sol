pragma solidity ^0.5.0;

import "../node_modules/openzeppelin-solidity/contracts/cryptography/ECDSA.sol";
import "./../dependencies/erc-1155/contracts/SafeMath.sol";
import "./Commons.sol";
import "./ClaimCommons.sol";
import "./ClaimVerifier.sol";
import "./IdentityContract.sol";

library IdentityContractLib {
    using SafeMath for uint256;
    
    // Events ERC-725
    event DataChanged(bytes32 indexed key, bytes value);
    event ContractCreated(address indexed contractAddress);
    event OwnerChanged(address indexed ownerAddress);
    
    // Events ERC-735
    event ClaimRequested(uint256 indexed claimRequestId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
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
    
    // Constants ERC-735
    bytes constant public ETH_PREFIX = "\x19Ethereum Signed Message:\n32";
    uint256 constant public ECDSA_SCHEME = 1;
    
    function addClaim(mapping (uint256 => Claim) storage claims, mapping (uint256 => uint256[]) storage topics2ClaimIds, mapping (uint256 => bool) storage burnedClaimIds, IdentityContract marketAuthority, uint256 _topic, uint256 _scheme, address _issuer, bytes memory _signature, bytes memory _data, string memory _uri) public returns (uint256 claimRequestId) {
        // Make sure that claim is correct if the topic is in the relevant range.
        if(_topic >= 10000 && _topic <= 11000) {
            ClaimCommons.ClaimType claimType = ClaimCommons.topic2ClaimType(_topic);
            require(ClaimVerifier.validateClaim(marketAuthority, claimType, address(this), _topic, _scheme, _issuer, _signature, _data));
        }
        
        claimRequestId = getClaimId(_issuer, _topic);
        
        // Check for burned claim IDs.
        if(burnedClaimIds[claimRequestId])
            require(false);
        
        // Emit and modify before adding to save gas.
        if(keccak256(claims[claimRequestId].signature) != keccak256(new bytes(32))) { // Claim existence check since signature cannot be 0.
            emit ClaimAdded(claimRequestId, _topic, _scheme, _issuer, _signature, _data, _uri);
            
            topics2ClaimIds[_topic].length++;
            topics2ClaimIds[_topic][topics2ClaimIds[_topic].length - 1] = claimRequestId;
        } else {
            // Make sure that only issuer or holder can change claims
            require(msg.sender == address(this) || msg.sender == _issuer);
            emit ClaimChanged(claimRequestId, _topic, _scheme, _issuer, _signature, _data, _uri);
        }
        
        claims[claimRequestId] = Claim(_topic, _scheme, _issuer, _signature, _data, _uri);
    }
    
    function removeClaim(address owner, mapping (uint256 => Claim) storage claims, mapping (uint256 => uint256[]) storage topics2ClaimIds, mapping (uint256 => bool) storage burnedClaimIds, uint256 _claimId) public returns (bool success) {
        require(msg.sender == owner || msg.sender == claims[_claimId].issuer);
        
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
        require(positionInArray < topics2ClaimIds[claim.topic].length);
        
        // Swap the last element in for it.
        topics2ClaimIds[claim.topic][positionInArray] = topics2ClaimIds[claim.topic][topics2ClaimIds[claim.topic].length - 1];
        
        // Delete the (now duplicated) last entry by shrinking the array.
        topics2ClaimIds[claim.topic].length--;
        
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
    
    function getClaimId(address _issuer, uint256 _topic) internal pure returns (uint256 __claimRequestId) {
        // TODO: Addition or concatenation?
        bytes memory preimageIssuer = abi.encodePacked(_issuer);
        bytes memory preimageTopic = abi.encodePacked(_topic);
        return uint256(keccak256(abi.encodePacked(preimageIssuer, preimageTopic)));
    }
    
    /**
     * Only consumes reception approval when handling forwards. Fails iff granted reception approval is insufficient.
     */
    function consumeReceptionApproval(mapping (uint256 => mapping(address => IdentityContractLib.PerishableValue)) storage receptionApproval, uint256 _id, address _from, uint256 _value) public {
        // Accept all certificate ERC-1155 transfers.
        if(isCertificate(_id))
            return;
        
        require(receptionApproval[_id][_from].expiryDate >= Commons.getBalancePeriod());
        require(receptionApproval[_id][_from].value >= _value);
        
        receptionApproval[_id][_from].value = receptionApproval[_id][_from].value.sub(_value);
    }
    
    function isCertificate(uint256 _id) internal pure returns (bool) {
        return (_id & 0x000000ff00000000000000000000000000000000000000000000000000000000) == 0x0000000400000000000000000000000000000000000000000000000000000000;
    }
}