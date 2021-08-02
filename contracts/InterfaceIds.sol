// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "./Commons.sol";
import "./IdentityContractFactory.sol";
import "./ClaimVerifier.sol";
import "./IEnergyToken.sol";
import "./EnergyTokenLib.sol";
import "./../dependencies/erc-1155/contracts/ERC1155.sol";
import "./IERC165.sol";

contract InterfaceIds {
    // 0x01ffc9a7
    function getInterfaceIdIERC165() external pure returns(bytes4) {
        return IERC165.supportsInterface.selector;
    }
    
    // 0x6f15538d
    function getInterfaceIdIERC725() external pure returns(bytes4) {
        return IERC725.execute.selector ^ IERC725.getData.selector ^ IERC725.setData.selector;
    }
    
    // 0x848a042c
    function getInterfaceIdIERC735() external pure returns(bytes4) {
        return IERC735.getClaim.selector ^ IERC735.getClaimIdsByTopic.selector ^ IERC735.addClaim.selector ^ IERC735.removeClaim.selector;
    }
    
    // 0x1fd50459
    function getInterfaceIdIdentityContract() external pure returns(bytes4) {
        return IIdentityContract.changeOwner.selector ^ IIdentityContract.getData.selector ^ IIdentityContract.setData.selector ^ IIdentityContract.execute.selector ^ IIdentityContract.getClaim.selector ^ IIdentityContract.getClaimIdsByTopic.selector ^ IIdentityContract.addClaim.selector ^ IIdentityContract.removeClaim.selector ^ IIdentityContract.burnClaimId.selector ^ IIdentityContract.reinstateClaimId.selector ^ IIdentityContract.onERC1155Received.selector ^ IIdentityContract.onERC1155BatchReceived.selector ^ IIdentityContract.approveSender.selector ^ IIdentityContract.approveBatchSender.selector;
    }
    
    // 0xd9b67a26
    function getInterfaceIdERC1155() external pure returns(bytes4) {
        return ERC1155.safeTransferFrom.selector ^ ERC1155.safeBatchTransferFrom.selector ^ ERC1155.balanceOf.selector ^ ERC1155.balanceOfBatch.selector ^ ERC1155.setApprovalForAll.selector ^ ERC1155.isApprovedForAll.selector;
    }
    
    // 0x16c97c18
    function getInterfaceIdIEnergyToken() external pure returns(bytes4) {
        return IEnergyToken.decimals.selector ^ IEnergyToken.mint.selector ^ IEnergyToken.createForwards.selector ^ IEnergyToken.createPropertyForwards.selector ^ IEnergyToken.addMeasuredEnergyConsumption.selector ^ IEnergyToken.addMeasuredEnergyGeneration.selector ^ IEnergyToken.createTokenFamily.selector ^ IEnergyToken.temporallyTransportCertificates.selector ^ IEnergyToken.safeTransferFrom.selector ^ IEnergyToken.safeBatchTransferFrom.selector ^ IEnergyToken.getTokenId.selector ^ IEnergyToken.getPropertyTokenId.selector ^ IEnergyToken.getCriteriaHash.selector ^ IEnergyToken.getTokenIdConstituents.selector ^ IEnergyToken.tokenKind2Number.selector ^ IEnergyToken.number2TokenKind.selector ^ IEnergyToken.getInitialGenerationPlant.selector;
    }
    
    // 0xad467c35
    function getInterfaceIdSimpleDistributor() external pure returns(bytes4) {
        return ComplexDistributor.setPropertyForwardsCriteria.selector ^ ComplexDistributor.distribute.selector ^ ComplexDistributor.withdrawSurplusCertificates.selector;
    }
    
    // 0x2e33b44b
    function getInterfaceIdComplexDistributor() external pure returns(bytes4) {
        return SimpleDistributor.distribute.selector ^ SimpleDistributor.withdrawSurplusCertificates.selector;
    }
}