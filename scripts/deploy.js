// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {

  // We get the contract to deploy

  
  let weth;
  let vault;
  let marketOps;
  let collectionOps;
  let collectionFac;
  const [owner] = await ethers.getSigners();

  const MockToken = await hre.ethers.getContractFactory("WETH9");
   weth = await MockToken.deploy();

  await weth.deployed();
  console.log("MockToken deployed to: ", weth.address);


  const Vault = await hre.ethers.getContractFactory("MarketNFTVault");
   vault = await Vault.deploy();

  await vault.deployed();

  console.log("Vault deployed to:", vault.address);

  const CollectionOps = await hre.ethers.getContractFactory(
    "CollectionOperations"
  );

   collectionOps = await CollectionOps.deploy(weth.address,owner.address);

  await collectionOps.deployed();
  console.log("CollectionOperations deployed to:", collectionOps.address);


  const MarketOps = await hre.ethers.getContractFactory("MarketNFTOperations");
   marketOps = await MarketOps.deploy(weth.address, vault.address,owner.address,collectionOps.address);

  await marketOps.deployed();

  await collectionOps.setMarketOperations(marketOps.address)
  await vault.setContractForAccess(marketOps.address,true)
  console.log("MarketNFTOperations deployed to:", marketOps.address);

  const LazyCollectionFactory = await hre.ethers.getContractFactory(
    "LazyCollectionFactory"
  );
   collectionFac = await LazyCollectionFactory.deploy(weth.address,owner.address,collectionOps.address);

  await collectionFac.deployed();

  console.log(
    "LazyCollectionFactory deployed: ",
    collectionFac.address
  );

  await collectionOps.setCollectionFactory(collectionFac.address);

  
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
