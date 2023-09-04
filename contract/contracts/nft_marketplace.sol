// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is IERC721Receiver, ReentrancyGuard, Ownable {
    uint256 public nftListingFee = 0.0025 ether;

    struct NFTCollection {
        string name;
        address nftMinterAddress;
    }

    NFTCollection[] public nftCollections;

    struct MarketplaceNFT {
        bool nftOnMarketplace;
        uint256 nftCollectionIndex;
        uint256 tokenId;
        address payable seller;
        uint256 sellPrice;
    }

    mapping(uint256 nftCollectionIndex => mapping(uint256 tokenId => MarketplaceNFT marketplaceNFT))
        public marketplaceNFTs;

    event NFTsListed(
        uint256 nftCollectionIndex,
        uint256[] tokenIds,
        address seller,
        uint256[] sellPrices
    );

    event NFTsUnlisted(
        uint256 nftCollectionIndex,
        uint256[] tokenIds,
        address seller
    );

    event NFTBought(
        uint256 nftCollectionIndex,
        uint256 tokenId,
        address seller,
        uint256 sellPrice,
        address buyer
    );

    function setNFTListingFee(uint256 newNFTListingFee) external onlyOwner {
        nftListingFee = newNFTListingFee;
    }

    function addNFTCollection(
        string calldata _name,
        address _nftMinterAddress
    ) external onlyOwner {
        require(
            bytes(_name).length > 0,
            "nft collection name should not be empty"
        );
        nftCollections.push(
            NFTCollection({name: _name, nftMinterAddress: _nftMinterAddress})
        );
    }

    function removeNFTCollection(
        uint256 nftCollectionIndex
    ) external onlyOwner {
        require(
            nftCollectionIndex < nftCollections.length,
            "invalid nftCollectionIndex"
        );

        NFTCollection storage nftCollection = nftCollections[
            nftCollectionIndex
        ];

        uint256 totalNFTs = IERC721Enumerable(nftCollection.nftMinterAddress)
            .totalSupply();

        uint256 tokenId;
        for (uint i = 0; i < totalNFTs; i++) {
            tokenId = i + 1;

            if (
                marketplaceNFTs[nftCollectionIndex][tokenId].nftOnMarketplace ==
                true
            ) {
                delete marketplaceNFTs[nftCollectionIndex][tokenId];
            }
        }

        nftCollections[nftCollectionIndex] = nftCollections[
            nftCollections.length - 1
        ];
        nftCollections.pop();
    }

    function getNFTCollections()
        external
        view
        returns (NFTCollection[] memory)
    {
        return nftCollections;
    }
}
