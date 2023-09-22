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

    function unlistNFTs(
        uint256 nftCollectionIndex,
        uint256[] calldata tokenIds
    ) external nonReentrant {
        require(
            nftCollectionIndex < nftCollections.length,
            "invalid nftCollectionIndex"
        );

        NFTCollection storage nftCollection = nftCollections[
            nftCollectionIndex
        ];

        require(tokenIds.length > 0, "tokenIds must contain atleast 1 tokenId");

        uint256 tokenId;
        for (uint i = 0; i < tokenIds.length; i++) {
            tokenId = tokenIds[i];

            require(
                marketplaceNFTs[nftCollectionIndex][tokenId].nftOnMarketplace ==
                    true,
                "token not listed on marketplace"
            );

            require(
                marketplaceNFTs[nftCollectionIndex][tokenId].seller ==
                    msg.sender,
                "token doesn't belong to the user"
            );

            IERC721(nftCollection.nftMinterAddress).transferFrom(
                address(this),
                msg.sender,
                tokenId
            );

            delete marketplaceNFTs[nftCollectionIndex][tokenId];
        }

        emit NFTsUnlisted(nftCollectionIndex, tokenIds, msg.sender);
    }

    function buyNFT(
        uint256 nftCollectionIndex,
        uint256 tokenId
    ) external payable nonReentrant {
        require(
            nftCollectionIndex < nftCollections.length,
            "invalid nftCollectionIndex"
        );

        NFTCollection storage nftCollection = nftCollections[
            nftCollectionIndex
        ];

        require(
            marketplaceNFTs[nftCollectionIndex][tokenId].nftOnMarketplace ==
                true,
            "token not listed on marketplace"
        );

        require(
            msg.value == marketplaceNFTs[nftCollectionIndex][tokenId].sellPrice,
            "amount not equal to sellPrice"
        );

        marketplaceNFTs[nftCollectionIndex][tokenId].seller.transfer(msg.value);

        IERC721(nftCollection.nftMinterAddress).transferFrom(
            address(this),
            msg.sender,
            tokenId
        );

        delete marketplaceNFTs[nftCollectionIndex][tokenId];

        emit NFTBought(
            marketplaceNFTs[nftCollectionIndex][tokenId].nftCollectionIndex,
            marketplaceNFTs[nftCollectionIndex][tokenId].tokenId,
            marketplaceNFTs[nftCollectionIndex][tokenId].seller,
            marketplaceNFTs[nftCollectionIndex][tokenId].sellPrice,
            msg.sender
        );
    }

    function getListedNFTs(
        uint256 nftCollectionIndex
    ) external view returns (MarketplaceNFT[] memory) {
        require(
            nftCollectionIndex < nftCollections.length,
            "invalid nftCollectionIndex"
        );

        NFTCollection storage nftCollection = nftCollections[
            nftCollectionIndex
        ];

        uint256 totalNFTs = IERC721Enumerable(nftCollection.nftMinterAddress)
            .totalSupply();
        MarketplaceNFT[] memory tempNFTs = new MarketplaceNFT[](totalNFTs);

        uint256 length = 0;
        for (uint i = 0; i < totalNFTs; i++) {
            uint256 tokenId = i + 1;

            if (
                IERC721(nftCollection.nftMinterAddress).ownerOf(tokenId) ==
                address(this)
            ) {
                tempNFTs[length] = marketplaceNFTs[nftCollectionIndex][tokenId];
                length += 1;
            }
        }

        MarketplaceNFT[] memory listedNFTs = new MarketplaceNFT[](length);
        for (uint i = 0; i < length; i++) {
            listedNFTs[i] = tempNFTs[i];
        }

        return listedNFTs;
    }

    function getListedNFTsOfSeller(
        uint256 nftCollectionIndex
    ) external view returns (MarketplaceNFT[] memory) {
        require(
            nftCollectionIndex < nftCollections.length,
            "invalid nftCollectionIndex"
        );

        NFTCollection storage nftCollection = nftCollections[
            nftCollectionIndex
        ];

        uint256 totalNFTs = IERC721Enumerable(nftCollection.nftMinterAddress)
            .totalSupply();
        MarketplaceNFT[] memory tempNFTsOfSeller = new MarketplaceNFT[](
            totalNFTs
        );

        uint256 length = 0;
        for (uint i = 0; i < totalNFTs; i++) {
            uint256 tokenId = i + 1;

            if (
                (IERC721(nftCollection.nftMinterAddress).ownerOf(tokenId) ==
                    address(this)) &&
                (marketplaceNFTs[nftCollectionIndex][tokenId].seller ==
                    msg.sender)
            ) {
                tempNFTsOfSeller[length] = marketplaceNFTs[nftCollectionIndex][
                    tokenId
                ];
                length += 1;
            }
        }

        MarketplaceNFT[] memory listedNFTsOfSeller = new MarketplaceNFT[](
            length
        );
        for (uint i = 0; i < length; i++) {
            listedNFTsOfSeller[i] = tempNFTsOfSeller[i];
        }

        return listedNFTsOfSeller;
    }

    function getNFTsOfUser(
        uint256 nftCollectionIndex
    ) external view returns (uint256[] memory) {
        require(
            nftCollectionIndex < nftCollections.length,
            "invalid nftCollectionIndex"
        );

        NFTCollection storage nftCollection = nftCollections[
            nftCollectionIndex
        ];

        uint256 totalNFTs = IERC721Enumerable(nftCollection.nftMinterAddress)
            .totalSupply();
        uint256[] memory tempNFTsOfUser = new uint256[](totalNFTs);

        uint256 length = 0;
        for (uint i = 0; i < totalNFTs; i++) {
            uint256 tokenId = i + 1;

            if (
                IERC721(nftCollection.nftMinterAddress).ownerOf(tokenId) ==
                msg.sender
            ) {
                tempNFTsOfUser[length] = tokenId;
                length += 1;
            }
        }

        uint256[] memory nftsOfUser = new uint256[](length);
        for (uint i = 0; i < length; i++) {
            nftsOfUser[i] = tempNFTsOfUser[i];
        }

        return nftsOfUser;
    }

    function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        require(
            from != address(0x0),
            "cannot send(or mint) NFT token to nft marketplace contract directly"
        );
        return IERC721Receiver.onERC721Received.selector;
    }

    function withdraw() public payable onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}
