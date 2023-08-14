// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MarketplaceNFTMinter is ERC721Enumerable, ERC721URIStorage, Ownable {
    using Strings for uint256;
    string public baseExtension = ".json";
    uint256 public cost = 0.0050 ether;
    bool public paused = false;

    constructor(
        string memory _name,
        string memory _symbol
    )
        ERC721(
            bytes(_name).length > 0 ? _name : "NFT Collection Null",
            bytes(_symbol).length > 0 ? _symbol : "COL-NUL"
        )
    {}

    function mint(
        address to,
        string calldata _NFTMetadataFolderCID,
        uint256 totalNFTs
    ) public payable {
        require(!paused, "minting is paused");
        require(
            bytes(_NFTMetadataFolderCID).length > 0,
            "_NFTMetadataFolderCID should not be empty"
        );
        require(totalNFTs > 0, "totalNFTs must be greater than 0");
        require(
            msg.value == (cost * totalNFTs),
            "amount not equal to minting cost"
        );

        uint256 supply = totalSupply();

        for (uint256 i = 1; i <= totalNFTs; i++) {
            uint256 tokenId = supply + i;
            string memory uri = string(
                abi.encodePacked(
                    "ipfs://",
                    _NFTMetadataFolderCID,
                    "/",
                    tokenId.toString(),
                    baseExtension
                )
            );

            _safeMint(to, tokenId);
            _setTokenURI(tokenId, uri);
        }
    }

    function withdraw() public payable onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function setCost(uint256 newCost) public onlyOwner {
        cost = newCost;
    }

    function setBaseExtension(
        string memory _newBaseExtension
    ) public onlyOwner {
        baseExtension = _newBaseExtension;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function walletOfOwner(
        address _owner
    ) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }
}
