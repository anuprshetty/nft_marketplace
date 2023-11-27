# NFT Marketplace

A dapp for selling and purchasing NFTs.

![nft_marketplace_dapp](media/nft_marketplace_dapp.png)

## Smart Contracts

- Token (token_alpha)
- NFTMinter (tom_and_jerry, mickey_mouse)
- MarketplaceNFTMinter (collection_marketplace)
- NFTMarketplace (nft_marketplace)

## Tools and Technologies Used

- nft:
  - IPFS, NFTs, Python
- contract:
  - Smart contracts (ERC20, IERC20, ERC721Enumerable, ERC721URIStorage, Ownable, IERC721Receiver)
  - Hardhat, Solidity, OpenZeppelin, Remix IDE, Blockchain, JavaScript, Mocha Testcases, Solidity code coverage
- dapp:
  - React.js, Web3.js, Nginx, Metamask wallet
- Docker and Containers
- Ethernal dashboard - EVM compatible private blockchain network explorer.
- GitHub actions

## How To Run?

- [Upload NFTs to IPFS](./nft/.vscode/tasks.json)
- [Deploy smart contracts to the blockchain](./contract/.vscode/tasks.json)
- [Run the dapp](./dapp/.vscode/tasks.json)

## Workflow

1. Token [name, symbol, maxSupply, totalSupply, balanceOf (hash_wallet_accounts)]
2. NFTMinter [name, symbol, owner, baseURI, maxSupply, totalSupply, cost, customPaymentCurrencies, getCustomPaymentCurrencies]
3. NFTMinter [mint - with native token for user (not for owner)]
4. Token [balanceOf (user), approve (all balance tokens of user as an allowance to spend by NFTMinter smart contract), allowance], NFTMinter [mint - with custom token for user (not for owner)]
5. NFTMinter [totalSupply, balanceOf, walletOfOwner, tokenURI, ownerOf]
6. MarketplaceNFTMinter [name, symbol, owner, totalSupply, cost]
7. MarketplaceNFTMinter [mint - 10 mickey_mouse NFTs for user(not for owner)]
8. MarketplaceNFTMinter [totalSupply, balanceOf, walletOfOwner, tokenURI, ownerOf]
9. NFTMarketplace [owner, nftCollections, getNFTCollections, nftListingFee]
10. NFTMinter and MarketplaceNFTMinter [setApprovalForAll (set NFTMarketplace smart contract as operator to handle all NFTs of a particular user account), isApprovedForAll]
11. NFTMarketplace [listNFTs, getListedNFTs, getListedNFTsOfSeller, getNFTsOfUser, marketplaceNFTs]
12. NFTMarketplace [buyNFT, getListedNFTs, getListedNFTsOfSeller, getNFTsOfUser, marketplaceNFTs]
13. NFTMarketplace [unlistNFTs, getListedNFTs, getListedNFTsOfSeller, getNFTsOfUser, marketplaceNFTs], NFTMinter or MarketplaceNFTMinter [ownerOf, walletOfOwner]
