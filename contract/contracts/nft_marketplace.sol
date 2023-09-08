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

    function listNFTs(
        uint256 nftCollectionIndex,
        uint256[] calldata tokenIds,
        uint256[] calldata sellPrices
    ) external payable nonReentrant {
        require(
            nftCollectionIndex < nftCollections.length,
            "invalid nftCollectionIndex"
        );

        NFTCollection storage nftCollection = nftCollections[
            nftCollectionIndex
        ];

        require(tokenIds.length > 0, "tokenIds must contain atleast 1 tokenId");

        require(
            tokenIds.length == sellPrices.length,
            "mismatch in tokenIds and sellPrices"
        );

        require(
            msg.value == (nftListingFee * tokenIds.length),
            "insufficient nftListingFee"
        );

        uint256 tokenId;
        uint256 sellPrice;
        for (uint i = 0; i < tokenIds.length; i++) {
            tokenId = tokenIds[i];
            sellPrice = sellPrices[i];

            require(
                IERC721(nftCollection.nftMinterAddress).ownerOf(tokenId) ==
                    msg.sender,
                "token doesn't belong to the user"
            );
            require(
                marketplaceNFTs[nftCollectionIndex][tokenId].nftOnMarketplace ==
                    false,
                "token already listed on marketplace"
            );
            require(sellPrice > 0, "sellPrice must be greater than 0");

            IERC721(nftCollection.nftMinterAddress).transferFrom(
                msg.sender,
                address(this),
                tokenId
            );

            marketplaceNFTs[nftCollectionIndex][tokenId] = MarketplaceNFT({
                nftOnMarketplace: true,
                nftCollectionIndex: nftCollectionIndex,
                tokenId: tokenId,
                seller: payable(msg.sender),
                sellPrice: sellPrice
            });
        }

        emit NFTsListed(nftCollectionIndex, tokenIds, msg.sender, sellPrices);
    }
}
