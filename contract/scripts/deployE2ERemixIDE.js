// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

class Utils {
  static dapp_contracts_info_folder_path = "";
  static contracts_setup_outputs = {};

  static async display_hardhat_network_info() {
    let provider = hre.ethers.provider;

    const hardhat_network_info = {
      chainId: parseInt((await provider.getNetwork()).chainId),
    };

    console.log("\n---------------- Hardhat Network Info ----------------");
    console.log(`${JSON.stringify(hardhat_network_info, null, 2)}`);
    console.log("------------------------------------------------------\n");
  }

  static async setup_dapp_contracts_info() {
    const folder_path = "browser/dapp_contracts_info/";

    try {
      await remix.fileManager.mkdir(folder_path);
    } catch (error) {
      console.log(`Folder (${folder_path}) already exists.`);
    }

    return folder_path;
  }

  static async generate_dapp_contract_info(contractName, contractInstances) {
    const artifact = JSON.parse(
      await remix.fileManager.getFile(
        `browser/contracts/artifacts/${contractName}.json`
      )
    );

    const dapp_contract_info = {
      contractName: contractName,
      contractInstances: contractInstances,
      abi: artifact.abi,
    };

    await remix.fileManager.writeFile(
      `${Utils.dapp_contracts_info_folder_path}${dapp_contract_info.contractName}.json`,
      JSON.stringify(dapp_contract_info, null, 2)
    );
  }
}

class BaseContract {
  constructor(contract_name, contract_instance_name) {
    this.contract_name = contract_name;
    this.contract_instance_name = contract_instance_name;
    this.contract_address = "";
    this.contract = null;
    this.contract_constructor_args = [];

    if (!(this.contract_name in Utils.contracts_setup_outputs)) {
      Utils.contracts_setup_outputs[this.contract_name] = {};
    }
    Utils.contracts_setup_outputs[this.contract_name][
      this.contract_instance_name
    ] = {};
  }

  async deployContract() {
    const maxRetries = 6;
    const retryDelaySeconds = 10;

    let retries = 0;

    while (retries < maxRetries) {
      try {
        const Contract = await hre.ethers.getContractFactory(
          this.contract_name
        );
        this.contract = await Contract.deploy(
          ...this.contract_constructor_args
        );
        await this.contract.deployed();
        break;
      } catch (error) {
        if ("code" in error && error.code === "UND_ERR_HEADERS_TIMEOUT") {
          console.error(
            `Error UND_ERR_HEADERS_TIMEOUT (${this.contract_name} contract - ${this.contract_instance_name} contract_instance). Retrying in ${retryDelaySeconds} seconds ...`
          );

          retries++;

          await new Promise((resolve) =>
            setTimeout(resolve, retryDelaySeconds * 1000)
          );
        } else {
          throw error;
        }
      }
    }

    if (retries === maxRetries) {
      console.error(
        `Error UND_ERR_HEADERS_TIMEOUT (${this.contract_name} contract - ${this.contract_instance_name} contract_instance). Failed to deploy after ${maxRetries} retries.`
      );
      process.exitCode = 1;
    }

    this.contract_address = this.contract.address;

    Utils.contracts_setup_outputs[this.contract_name][
      this.contract_instance_name
    ]["address"] = this.contract_address;
  }
}

class Token extends BaseContract {
  constructor(contract_instance_name, contract_constructor_args) {
    super("Token", contract_instance_name);

    this.symbol = contract_constructor_args.symbol;
    this.contract_constructor_args = [
      contract_constructor_args.name,
      contract_constructor_args.symbol,
      contract_constructor_args.maxSupply,
    ];
  }

  async mint(to, amount) {
    await (await this.contract.mint(to, amount)).wait();

    if (parseInt(await this.contract.balanceOf(to)) !== amount) {
      throw new Error(
        `Error in ${this.mint.name}() method while setting up ${this.contract_name} contract - ${this.contract_instance_name} contract_instance`
      );
    }
  }
}

class NFTMinter extends BaseContract {
  constructor(contract_instance_name, output_nft_info) {
    super("NFTMinter", contract_instance_name);

    this.output_nft_info = output_nft_info;
    this.contract_constructor_args = [
      output_nft_info.nft_collection_name,
      output_nft_info.symbol,
    ];
  }

  async addCustomPaymentCurrency(currency_index, name, symbol, token, cost) {
    await (
      await this.contract.addCustomPaymentCurrency(name, symbol, token, cost)
    ).wait();

    const customPaymentCurrency = await this.contract.customPaymentCurrencies(
      currency_index
    );

    if (
      customPaymentCurrency.symbol !== symbol ||
      customPaymentCurrency.token !== token ||
      parseInt(customPaymentCurrency.cost) !== cost
    ) {
      throw new Error(
        `Error in ${this.addCustomPaymentCurrency.name}() method while setting up ${this.contract_name} contract - ${this.contract_instance_name} contract_instance`
      );
    }
  }
}

class MarketplaceNFTMinter extends BaseContract {
  constructor(contract_instance_name, output_nft_info) {
    super("MarketplaceNFTMinter", contract_instance_name);

    this.output_nft_info = output_nft_info;
    this.contract_constructor_args = [
      output_nft_info.nft_collection_name,
      output_nft_info.symbol,
    ];
  }
}

class NFTMarketplace extends BaseContract {
  constructor(contract_instance_name) {
    super("NFTMarketplace", contract_instance_name);
  }

  async addNFTCollection(nft_collection_index, name, nftMinterAddress) {
    await (await this.contract.addNFTCollection(name, nftMinterAddress)).wait();

    const nftCollection = await this.contract.nftCollections(
      nft_collection_index
    );

    if (
      nftCollection.name !== name ||
      nftCollection.nftMinterAddress !== nftMinterAddress
    ) {
      throw new Error(
        `Error in ${this.addNFTCollection.name}() method while setting up ${this.contract_name} contract - ${this.contract_instance_name} contract_instance`
      );
    }
  }
}

class BaseDeploy {
  constructor() {
    this.tokens = [];
    this.nft_collections = [];
    this.marketplace_nft_collections = [];
    this.nft_marketplaces = [];
  }

  async deploy() {
    const token_alp = new Token("token_alpha", {
      name: "Token Alpha",
      symbol: "TKN-ALP",
      maxSupply: 1000000,
    });

    this.tokens = [token_alp];

    for (const token of this.tokens) {
      await token.deployContract();
    }

    const hash_wallet_accounts = JSON.parse(
      await remix.fileManager.getFile("browser/hash_wallet_accounts.json")
    );

    for (const token of this.tokens) {
      for (const account of hash_wallet_accounts) {
        await token.mint(account.address, 10000);
      }
    }

    const output_nfts_info = await this.get_output_nfts_info();

    this.nft_collections = [];
    var begin = 0;
    const end = 0;
    for (let output_nft_info in output_nfts_info) {
      if (begin > end) {
        break;
      }

      output_nft_info = output_nfts_info[output_nft_info];

      const nft_collection = new NFTMinter(
        output_nft_info.nft_collection_id,
        output_nft_info
      );
      this.nft_collections.push(nft_collection);

      begin += 1;
    }

    for (const nft_collection of this.nft_collections) {
      await nft_collection.deployContract();
    }

    for (const [c_index, nft_collection] of this.nft_collections.entries()) {
      for (const [t_index, token] of this.tokens.entries()) {
        const cost = parseInt((c_index + 1) * (t_index + 1));
        await nft_collection.addCustomPaymentCurrency(
          t_index,
          token.contract_instance_name,
          token.symbol,
          token.contract_address,
          cost
        );
      }
    }

    const marketplace_nft_collection = new MarketplaceNFTMinter(
      "collection_marketplace",
      {
        nft_collection_id: "collection_marketplace",
        nft_collection_name: "NFT Collection Marketplace",
        name: "Collection Marketplace",
        symbol: "COL-MRK",
      }
    );
    this.marketplace_nft_collections = [marketplace_nft_collection];
    await marketplace_nft_collection.deployContract();

    const nft_marketplace = new NFTMarketplace("nft_marketplace");
    this.nft_marketplaces = [nft_marketplace];
    await nft_marketplace.deployContract();

    await nft_marketplace.addNFTCollection(
      0,
      marketplace_nft_collection.contract_instance_name,
      marketplace_nft_collection.contract_address
    );

    for (const [
      nft_collection_index,
      nft_collection,
    ] of this.nft_collections.entries()) {
      await nft_marketplace.addNFTCollection(
        nft_collection_index + 1,
        nft_collection.contract_instance_name,
        nft_collection.contract_address
      );
    }

    const dapp_contracts_info = [
      {
        contractName: this.tokens[0].contract_name,
        contractInstances: this.tokens.map((token) => ({
          name: token.contract_instance_name,
          address: token.contract_address,
        })),
      },
      {
        contractName: this.nft_collections[0].contract_name,
        contractInstances: this.nft_collections.map((nft_collection) => ({
          name: nft_collection.contract_instance_name,
          address: nft_collection.contract_address,
          nftCollection: nft_collection.output_nft_info.name,
        })),
      },
      {
        contractName: this.marketplace_nft_collections[0].contract_name,
        contractInstances: this.marketplace_nft_collections.map(
          (marktplace_nft_collection) => ({
            name: marktplace_nft_collection.contract_instance_name,
            address: marktplace_nft_collection.contract_address,
            nftCollection: marktplace_nft_collection.output_nft_info.name,
          })
        ),
      },
      {
        contractName: this.nft_marketplaces[0].contract_name,
        contractInstances: this.nft_marketplaces.map((nft_marketplace) => ({
          name: nft_marketplace.contract_instance_name,
          address: nft_marketplace.contract_address,
        })),
      },
    ];

    for (const dapp_contract_info of dapp_contracts_info) {
      await Utils.generate_dapp_contract_info(
        dapp_contract_info.contractName,
        dapp_contract_info.contractInstances
      );
    }
  }
}

class DeployE2E extends BaseDeploy {
  async deployE2E() {
    await this.deploy();
  }

  async get_output_nfts_info() {
    const output_nfts_info = {
      tom_and_jerry: {
        nft_collection_id: "tom_and_jerry",
        nft_collection_name: "NFT Collection TomAndJerry",
        name: "Tom and Jerry",
        symbol: "COL-TNJ",
        image_name: "tom_and_jerry.png",
        num_copies: 0,
        ipfs_node_rpc_api: "/ip4/127.0.0.1/tcp/5001",
        nft_image_folder_cid: "",
        nft_metadata_folder_cid: "",
      },
      mickey_mouse: {
        nft_collection_id: "mickey_mouse",
        nft_collection_name: "NFT Collection MickeyMouse",
        name: "Mickey Mouse",
        symbol: "COL-MCM",
        image_name: "mickey_mouse.png",
        num_copies: 0,
        ipfs_node_rpc_api: "/ip4/127.0.0.1/tcp/5001",
        nft_image_folder_cid: "",
        nft_metadata_folder_cid: "",
      },
    };

    return output_nfts_info;
  }
}

(async () => {
  try {
    Utils.dapp_contracts_info_folder_path =
      await Utils.setup_dapp_contracts_info();

    await Utils.display_hardhat_network_info();

    console.log("-----------------------------------------------------");
    console.log("------------- Contracts Deployment Info -------------");
    console.log("-----------------------------------------------------");

    const deploy_e2e = new DeployE2E();
    await deploy_e2e.deployE2E();

    console.log(`\n${JSON.stringify(Utils.contracts_setup_outputs, null, 2)}`);
    console.log("-----------------------------------------------------");

    console.log("\nSUCCESS: contracts deployment ... DONE");
  } catch (error) {
    console.log(
      "\n--------------------------- ERROR --------------------------\n"
    );
    console.error(error);
    console.log(
      "\n------------------------------------------------------------\n"
    );
    console.log(
      "ERROR NOTE:\n \
      1) Make sure hardhat network is running.\n \
      2) Make sure you have properly updated contracts_setup_inputs.json file."
    );
    process.exitCode = 1;
  }
})();
