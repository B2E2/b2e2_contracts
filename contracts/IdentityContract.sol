// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./IdentityContractLib.sol";
import "./IIdentityContract.sol";
import "./IERC725.sol";
import "./IERC735.sol";
import "./IERC165.sol";

/**
 * An IdentityContract represents a user (i.e. a retail user or an authority, but also a distributor contract)
 * on the blockchain.
 */
contract IdentityContract is IERC725, IERC735, IIdentityContract, IERC165 {
    struct BalancePeriodConfiguration {
        uint64 length;
        uint64 offset;
        uint64 certificateTradingWindow;
    }

    // Attributes ERC-725
    address public owner;
    mapping (bytes32 => bytes) public data;
    
    // Attributes ERC-735
    mapping (uint256 => IdentityContractLib.Claim) claims;
    mapping (uint256 => uint256[]) topics2ClaimIds;
    mapping (uint256 => bool) burnedClaimIds;
    
    // Attributes related to ERC-1155
    // Energy token contract => token id => (token sender => PerishableValue)
    mapping (address => mapping (uint256 => mapping(address => IdentityContractLib.PerishableValue))) public receptionApproval;

    // Other attributes
    IdentityContract public marketAuthority;
    BalancePeriodConfiguration public balancePeriodConfiguration;
    uint256 public executionNonce;
    
    // Modifiers ERC-725
    modifier onlyOwner {
        require(msg.sender == owner || msg.sender == address(this), "Only owner.");
        _;
    }
    
    // Events related to ERC-1155
    event RequestTransfer(address recipient, address sender, uint256 value, uint64 expiryDate, uint256 tokenId);
    
    // Other events.
    event IdentityContractCreation(IdentityContract indexed marketAuthority, IdentityContract identityContract);

    /**
     * Market authorities need to set _marketAuthority to 0x0 and specify _balancePeriodLength.
     * Other IdentityContracts need to specify the Market Authority's address as _marketAuthority. Their specification of _balancePeriodLength will be ignored.
     */
    constructor(IdentityContract _marketAuthority, BalancePeriodConfiguration memory _balancePeriodConfiguration, address _owner) {
        if(_marketAuthority == IdentityContract(address(0))) {
            marketAuthority = this;
            balancePeriodConfiguration = _balancePeriodConfiguration;
        } else {
            marketAuthority = _marketAuthority;
            (balancePeriodConfiguration.length, balancePeriodConfiguration.offset, balancePeriodConfiguration.certificateTradingWindow) =
              _marketAuthority.balancePeriodConfiguration();
        }
        
        owner = _owner;
        
        emit IdentityContractCreation(_marketAuthority, this);
    }

    /**
    * Balance period does not start at 00:00:00 + i*15:00 but at 00:00:01 + i*15:00.
    * 
    * Timestamps are uint64 across this contract stack because they are included in identifiers
    * where space is scarce. 64 bits suffice.
    */
    function getBalancePeriod(uint256 _timestamp) public view returns(uint64 __beginningOfBalancePeriod) {
        _timestamp = _timestamp - balancePeriodConfiguration.offset;
        return uint64(_timestamp - (_timestamp % balancePeriodConfiguration.length) + balancePeriodConfiguration.offset);
    }
    
    // For the definitions of the interface identifiers, see InterfaceIds.sol.
    function supportsInterface(bytes4 interfaceID) override(IERC165) external virtual view returns (bool) {
        return
            interfaceID == 0x01ffc9a7 ||
            interfaceID == 0x6f15538d ||
            interfaceID == 0x848a042c ||
            interfaceID == 0x1fd50459;
    }
  
    function selfdestructIdc() override(IIdentityContract) external onlyOwner {
        selfdestruct(payable(owner));
    }
    
    // Functions ERC-725
    function changeOwner(address _owner) override(IIdentityContract) external onlyOwner {
        owner = _owner;
    }
    
    function getData(bytes32 _key) override(IERC725, IIdentityContract) external view returns (bytes memory __value) {
        return data[_key];
    }
    
    function setData(bytes32 _key, bytes calldata _value) override(IERC725, IIdentityContract) external onlyOwner {
        data[_key] = _value;
        emit DataChanged(_key, _value);
    }
    
    function execute(uint256 _operationType, address _to, uint256 _value, bytes calldata _data) override(IERC725, IIdentityContract) external onlyOwner {
        IdentityContractLib.execute(_operationType, _to, _value, _data);
    }
    
    function execute(uint256 _operationType, address _to, uint256 _value, bytes calldata _data, uint256 _executionNonce, bytes calldata _signature) external {
        // Limit the number of execution nonces that can be skipped to avoid overflows.
        require(_executionNonce >= executionNonce && _executionNonce <= executionNonce + 1e18);
        
        // Increment the stored execution nonce first.
        // This prevents attacks where a contract that is called later (e.g. because it receives money) replays the call to the execution function.
        executionNonce = _executionNonce + 1;
        IdentityContractLib.execute(owner, _executionNonce, _operationType, _to, _value, _data, _signature);
    }
    
    // Functions ERC-735
    function getClaim(uint256 _claimId) override(IERC735, IIdentityContract) external view returns(uint256 __topic, uint256 __scheme,
      address __issuer, bytes memory __signature, bytes memory __data, string memory __uri) {
        __topic = claims[_claimId].topic;
        __scheme = claims[_claimId].scheme;
        __issuer = claims[_claimId].issuer;
        __signature = claims[_claimId].signature;
        __data = claims[_claimId].data;
        __uri = claims[_claimId].uri;
    }
    
    function getClaimIdsByTopic(uint256 _topic) override(IERC735, IIdentityContract) external view returns(uint256[] memory __claimIds) {
        return topics2ClaimIds[_topic];
    }
    
    function addClaim(uint256 _topic, uint256 _scheme, address _issuer, bytes memory _signature, bytes memory _data, string memory _uri)
      override(IERC735, IIdentityContract) public returns (uint256 __claimRequestId) {
        return IdentityContractLib.addClaim(claims, topics2ClaimIds, burnedClaimIds, marketAuthority, _topic, _scheme, _issuer, _signature, _data, _uri);
    }
    
    function removeClaim(uint256 _claimId) override(IERC735, IIdentityContract) external returns (bool __success) {
        return IdentityContractLib.removeClaim(owner, claims, topics2ClaimIds, burnedClaimIds, _claimId);
    }

    function burnClaimId(uint256 _topic) override(IIdentityContract) external {
        IdentityContractLib.burnClaimId(burnedClaimIds, _topic);
    }
    
    function reinstateClaimId(uint256 _topic) override(IIdentityContract) external {
        IdentityContractLib.reinstateClaimId(burnedClaimIds, _topic);
    }
    
    // Funtions ERC-1155 and related
    function onERC1155Received(address /*_operator*/, address _from, uint256 _id, uint256 _value, bytes calldata /*_data*/) virtual override(IIdentityContract) external returns(bytes4) {
        IdentityContractLib.consumeReceptionApproval(receptionApproval, getBalancePeriod(block.timestamp), _id, _from, _value);
        return 0xf23a6e61;
    }
    
    function onERC1155BatchReceived(address /*_operator*/, address _from, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata /*_data*/)
      virtual override(IIdentityContract) external returns(bytes4) {
        for(uint32 i = 0; i < _ids.length; i++) {
            IdentityContractLib.consumeReceptionApproval(receptionApproval, getBalancePeriod(block.timestamp), _ids[i], _from, _values[i]);
        }
        
        return 0xbc197c81;
    }
    
    function approveSender(address _energyToken, address _sender, uint64 _expiryDate, uint256 _value, uint256 _id) override(IIdentityContract) external onlyOwner {
        receptionApproval[_energyToken][_id][_sender] = IdentityContractLib.PerishableValue(_value, _expiryDate);
        emit RequestTransfer(address(this), _sender, _value, _expiryDate, _id);
    }
    
    function approveBatchSender(address _energyToken, address _sender, uint64 _expiryDate, uint256[] calldata _values, uint256[] calldata _ids) override(IIdentityContract) external onlyOwner {
        require(_values.length < 4294967295, "_values array is too long.");
        require(_values.length == _ids.length, "Unequal array lengths.");
        
        for(uint32 i=0; i < _values.length; i++) {
            receptionApproval[_energyToken][_ids[i]][_sender] = IdentityContractLib.PerishableValue(_values[i], _expiryDate);
            emit RequestTransfer(address(this), _sender, _values[i], _expiryDate, _ids[i]);
        }
    }
}
