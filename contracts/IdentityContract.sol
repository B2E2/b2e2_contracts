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
    
    // Constants ERC-735
    bytes constant public ETH_PREFIX = "\x19Ethereum Signed Message:\n32";
    uint256 constant public ECDSA_SCHEME = 1;
    
    // Attributes ERC-725
    address public owner;
    mapping (bytes32 => bytes) public data;
    
    // Attributes ERC-735
    mapping (uint256 => IdentityContractLib.Claim) claims;
    mapping (uint256 => uint256[]) topics2ClaimIds;
    mapping (bytes => bool) burnedSignatures;

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
        require(msg.sender == owner);
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
        return IdentityContractLib.addClaim(claims, topics2ClaimIds, burnedSignatures, marketAuthority, _topic, _scheme, _issuer, _signature, _data, _uri);
    }
    
    function removeClaim(uint256 _claimId) public returns (bool success) {
        require(msg.sender == owner || msg.sender == claims[_claimId].issuer);
        
        // Emit event and store burned signature before deleting to save gas for copy.
        IdentityContractLib.Claim memory claim = claims[_claimId];
        emit ClaimRemoved(_claimId, claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri);
        burnedSignatures[claim.signature] = true; // Make sure that this same claim cannot be added again.
        
        delete claims[_claimId];
        return true;
        
        // TODO: Alles untendrunter nach Debugging Löschbefehl des Verzeichnisses vor diesen schreiben.
        // TODO: Seiteneffekt prüfen.
        uint256[] storage array = topics2ClaimIds[claim.topic];
        uint32 positionInArray = 0;
        while(_claimId != array[positionInArray]) {
            positionInArray++;
        }
        
        for(uint32 i = positionInArray; i < array.length - 1; i++) {
            array[i] = array[i+1];
        }
        
        array.length = array.length - 1;
        
        return true;
    }
    
    function claimAttributes2SigningFormat(address _subject, uint256 _topic, bytes memory _data) public pure returns (bytes32 __claimInSigningFormat) {
        return keccak256(abi.encodePacked(_subject, _topic, _data));
    }
    
    function getSignerAddress(bytes32 _claimInSigningFormat, bytes memory _signature) public pure returns (address __signer) {
        return ECDSA.recover(keccak256(abi.encodePacked(ETH_PREFIX, _claimInSigningFormat)), _signature);
    }
    
    function verifySignature(uint256 _topic, uint256 _scheme, address _issuer, bytes memory _signature, bytes memory _data) public view returns (bool __valid) {
         // Check for currently unsupported signature.
        if(_scheme != ECDSA_SCHEME)
            return false;
        
        address signer = getSignerAddress(claimAttributes2SigningFormat(address(this), _topic, _data), _signature);
        return signer == address(this) && _issuer == address(this);
    }
    

}
