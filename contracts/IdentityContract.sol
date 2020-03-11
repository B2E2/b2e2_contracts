pragma solidity ^0.5.0;

import "./IdentityContractLib.sol";

contract IdentityContract {
    // Events ERC-725
    event DataChanged(bytes32 indexed key, bytes value);
    event ContractCreated(address indexed contractAddress);
    event OwnerChanged(address indexed ownerAddress);
    
    // Events ERC-735
    event ClaimRequested(uint256 indexed claimRequestId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    event ClaimAdded(uint256 indexed claimId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    event ClaimRemoved(uint256 indexed claimId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    event ClaimChanged(uint256 indexed claimId, uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    
    // Events related to ERC-1155
    event RequestTransfer(address recipient, address sender, uint256 value, uint64 expiryDate, uint256 tokenId);
    
    // Constants ERC-735
    uint256 constant public ECDSA_SCHEME = 1;
    
    // Attributes ERC-725
    address public owner;
    mapping (bytes32 => bytes) public data;
    
    // Attributes ERC-735
    mapping (uint256 => IdentityContractLib.Claim) claims;
    mapping (uint256 => uint256[]) topics2ClaimIds;
    mapping (uint256 => bool) burnedClaimIds;
    
    // Attributes related to ERC-1155
    // id => (sender => PerishableValue)
    mapping (uint256 => mapping(address => IdentityContractLib.PerishableValue)) receptionApproval;

    // Other attributes
    IdentityContract public marketAuthority;

    constructor(IdentityContract _marketAuthority) public {
        if(_marketAuthority == IdentityContract(0)) {
            marketAuthority = this;
        } else {
            marketAuthority = _marketAuthority;
        }
        
        owner = msg.sender;
    }
    
    // Modifiers ERC-725
    modifier onlyOwner {
        require(msg.sender == owner || msg.sender == address(this));
        _;
    }
    
    // Functions ERC-725
    function changeOwner(address _owner) public onlyOwner {
        owner = _owner;
        emit OwnerChanged(_owner);
    }
    
    function getData(bytes32 _key) external view returns (bytes memory _value) {
        return data[_key];
    }
    
    function setData(bytes32 _key, bytes calldata _value) external onlyOwner {
        data[_key] = _value;
        emit DataChanged(_key, _value);
    }
    
    function execute(uint256 _operationType, address _to, uint256 _value, bytes calldata _data) external onlyOwner {
        if(_operationType == 0) {
            (bool success, ) = _to.call.value(_value)(_data);
            if(!success)
                require(false);
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
        
        require(false);
    }
    
    // Functions ERC-735
    function getClaim(uint256 _claimId) public view returns(uint256 __topic, uint256 __scheme, address __issuer, bytes memory __signature, bytes memory __data, string memory __uri) {
        __topic = claims[_claimId].topic;
        __scheme = claims[_claimId].scheme;
        __issuer = claims[_claimId].issuer;
        __signature = claims[_claimId].signature;
        __data = claims[_claimId].data;
        __uri = claims[_claimId].uri;
    }
    
    function getClaimIdsByTopic(uint256 _topic) public view returns(uint256[] memory claimIds) {
        return topics2ClaimIds[_topic];
    }
    
    function addClaim(uint256 _topic, uint256 _scheme, address _issuer, bytes memory _signature, bytes memory _data, string memory _uri) public returns (uint256 claimRequestId) {
        return IdentityContractLib.addClaim(claims, topics2ClaimIds, burnedClaimIds, marketAuthority, _topic, _scheme, _issuer, _signature, _data, _uri);
    }
    
    function removeClaim(uint256 _claimId) public returns (bool success) {
        return IdentityContractLib.removeClaim(owner, claims, topics2ClaimIds, burnedClaimIds, _claimId);
    }

    function burnClaimId(uint256 _topic) public {
        IdentityContractLib.burnClaimId(burnedClaimIds, _topic);
    }
    
    function reinstateClaimId(uint256 _topic) public {
        IdentityContractLib.reinstateClaimId(burnedClaimIds, _topic);
    }
    
    // Funtions ERC-1155 and related
    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata _data) external returns(bytes4) {
        IdentityContractLib.consumeReceptionApproval(receptionApproval, _id, _from, _value);
        return 0xf23a6e61;
    }
    
    function onERC1155BatchReceived(address _operator, address _from, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external returns(bytes4) {
        for(uint32 i = 0; i < _ids.length; i++) {
            IdentityContractLib.consumeReceptionApproval(receptionApproval, _ids[i], _from, _values[i]);
        }
        
        return 0xbc197c81;
    }
    
    function approveSender(address _sender, uint64 _expiryDate, uint256 _value, uint256 _id) public onlyOwner returns (bool __success) {
        receptionApproval[_id][_sender] = IdentityContractLib.PerishableValue(_value, _expiryDate);
        emit RequestTransfer(address(this), _sender, _value, _expiryDate, _id);
        return true;
    }
    
    function approveBatchSender(address _sender, uint64 _expiryDate, uint256[] memory _values, uint256[] memory _ids) public onlyOwner {
        require(_values.length < 4294967295);
        
        for(uint32 i; i < _values.length; i++) {
            receptionApproval[_ids[i]][_sender] = IdentityContractLib.PerishableValue(_values[i], _expiryDate);
            emit RequestTransfer(address(this), _sender, _values[i], _expiryDate, _ids[i]);
        }
    }
}
