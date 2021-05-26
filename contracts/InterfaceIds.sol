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
    function getInterfaceIdIERC165() external view returns(bytes4) {
        return IERC165.supportsInterface.selector;
    }
    
    function getInterfaceIdERC1155() external view returns(bytes4) {
        return ERC1155.safeTransferFrom.selector ^ ERC1155.safeBatchTransferFrom.selector ^ ERC1155.balanceOf.selector ^ ERC1155.balanceOfBatch.selector ^ ERC1155.setApprovalForAll.selector ^ ERC1155.isApprovedForAll.selector;
    }
    
    function getInterfaceIdIEnergyToken() external view returns(bytes4) {
        return IEnergyToken.decimals.selector ^ IEnergyToken.mint.selector ^ IEnergyToken.createForwards.selector ^ IEnergyToken.createPropertyForwards.selector ^ IEnergyToken.addMeasuredEnergyConsumption.selector ^ IEnergyToken.addMeasuredEnergyGeneration.selector ^ IEnergyToken.createTokenFamily.selector ^ IEnergyToken.temporallyTransportCertificates.selector ^ IEnergyToken.safeTransferFrom.selector ^ IEnergyToken.safeBatchTransferFrom.selector ^ IEnergyToken.getTokenId.selector ^ IEnergyToken.getPropertyTokenId.selector ^ IEnergyToken.getCriteriaHash.selector ^ IEnergyToken.getTokenIdConstituents.selector ^ IEnergyToken.tokenKind2Number.selector ^ IEnergyToken.number2TokenKind.selector ^ IEnergyToken.getInitialGenerationPlant.selector;
    }
}