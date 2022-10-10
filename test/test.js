const { BN, expectEvent } = require("@openzeppelin/test-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { ApproveOfferer } = require("../lib/approveOfferSign.js");
const { LazyMinter } = require("../lib/signTypedDatav4.js");

describe("Token contract", function () {
  let weth;
  let vault;
  let marketOps;
  let collectionOps;
  let collectionFac;
  let collec;
  let collecAddr;

  let owner;
  let addr1;
  let addr2;
  let addr3;
  let addr4;
  let addr5;

  let addrs;
  let prov;

  let testBaseUri = "https://ipfs.io/testcid/";

  it("Deploying contracts", async function () {
    // Get the ContractFactory and Signers here.
    [owner, addr1, addr2, addr3, addr4, addr5, ...addrs] =
      await ethers.getSigners();

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

    collectionOps = await CollectionOps.deploy(weth.address, addr1.address);

    await collectionOps.deployed();
    console.log("CollectionOperations deployed to:", collectionOps.address);

    const MarketOps = await hre.ethers.getContractFactory("MarketNFTOperations");
    marketOps = await MarketOps.deploy(
      weth.address,
      vault.address,
      owner.address,
      collectionOps.address
    );

    await marketOps.deployed();

    await collectionOps.setMarketOperations(marketOps.address);
    await vault.setContractForAccess(marketOps.address, true);
    console.log("MarketNFTOperations deployed to:", marketOps.address);

    const LazyCollectionFactory = await hre.ethers.getContractFactory(
      "LazyCollectionFactory"
    );
    collectionFac = await LazyCollectionFactory.deploy(
      weth.address,
      owner.address,
      collectionOps.address
    );

    await collectionFac.deployed();

    console.log("LazyCollectionFactory deployed: ", collectionFac.address);

    await collectionOps.setCollectionFactory(collectionFac.address);
  });

  describe("Creating NFT", function () {
    it("Should create NFT with fixed price status -> 1", async function () {
      let tx = await marketOps.mintAndSell(testBaseUri + "somehash.json", 5, 1);
      await tx.wait();

      expect(await vault.getStatus(1)).to.equal(1);
    });
    it("Should create NFT with auction with deadline status -> 3", async function () {
      let tx = await marketOps.mintAndCreateAuction(
        testBaseUri + "somehash.json",
        5,
        1,
        10,
        2,
        1687291500
      );
      await tx.wait();

      expect(await vault.getStatus(2)).to.equal(3);
    });
    it("Should create NFT with open for offers (status -> 0) ", async function () {
      let tx = await marketOps._mint(testBaseUri + "somehash.json", 5);
      await tx.wait();

      expect(await vault.getStatus(3)).to.equal(0);
    });

    it("Should lazy mint the signed NFT", async function () {
      const approver = new ApproveOfferer({
        contractAddress: marketOps.address,
        signer: addr1,
      });
      const [digest, nft, signature] = await approver.createVoucher(
        addr1.address,
        addr1.address,
        ethers.utils.parseEther("1"),
        0,
        vault.address,
        "ipfs://aksjkjdakjadkj",
        5,
        owner.address,
        123
      );

      // wait until the transaction is mined
      // console.log('signature: ', signature);

      // expect(recoveredAddress.wait()).to.equal(owner.address);

      let CollectionNFT = {
        _tokenAddress: vault.address,
        _tokenId: 0,
        approvedOfferer: owner.address,
        creator: addr1.address,
        owner: addr1.address,
        creatorLoyalty: 5,
        status: 0,
        minBidIncPercent: 0,
        price: ethers.utils.parseEther("1"),
        tokenURI: "ipfs://aksjkjdakjadkj",
        nonce: 900,
        lastBidder: owner.address,
        deadline: ethers.utils.parseEther("0"),
        instBuyPrice: ethers.utils.parseEther("0"),
      };
      let tx = await marketOps
        .connect(addr2)
        .lazyMint(CollectionNFT, digest, signature, {
          value: ethers.utils.parseEther("1"),
        });
      await tx.wait();
    });
  });

  describe("Operations on the minted single NFT.", function () {
    it("Should buy an  NFT from fixed price id:1", async function () {
      let tx = await marketOps
        .connect(addr1)
        .buy(vault.address, 1, { value: 1 });
      await tx.wait();

      expect(await vault.getStatus(1)).to.equal(0);
      expect(await vault.ownerOf(1)).to.equal(addr1.address);
    });

    it("Should bid to an auction id:2", async function () {
      let tx = await marketOps
        .connect(addr1)
        .makeOffer(vault.address, 2, 1, { value: 1 });
      await tx.wait();

      expect(await vault.getStatus(2)).to.equal(3);
      expect(await vault.getBidders(2)).to.equal(addr1.address);
    });

    it("Should accept the last bid on an auction id:2", async function () {
      let beforeBalance = await weth.balanceOf(owner.address);
      console.log("beforeBalance: ", beforeBalance);

      let tx = await marketOps.acceptOffer(vault.address, 2);
      await tx.wait();

      let afterBalance = await weth.balanceOf(owner.address);
      console.log("afterBalance: ", afterBalance);

      expect(await vault.getStatus(2)).to.equal(0);
      expect(await vault.ownerOf(2)).to.equal(addr1.address);
    });

    //Needs to be tested outside
    // ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    it("Should buy from his/her approved offer on the NFT id:2", async function () {
      const approver = new ApproveOfferer({
        contractAddress: marketOps.address,
        signer: addr1,
      });
      const [digest, nft, signature] = await approver.createVoucher(
        owner.address,
        addr1.address,
        ethers.utils.parseEther("2"),
        2,
        vault.address,
        "ipfs://aksjkjdakjadkj",
        5,
        owner.address,
        900
      );

      // wait until the transaction is mined
      // console.log('signature: ', signature);

      // expect(recoveredAddress.wait()).to.equal(owner.address);
      let beforeBalanceOwner = await weth.balanceOf(addr1.address);

      console.log("beforeBalanceOwner: ", beforeBalanceOwner);

      let CollectionNFT = {
        _tokenAddress: vault.address,
        _tokenId: 2,
        approvedOfferer: owner.address,
        creator: owner.address,
        owner: addr1.address,
        creatorLoyalty: 5,
        status: 0,
        minBidIncPercent: 0,
        price: ethers.utils.parseEther("2"),
        tokenURI: "ipfs://aksjkjdakjadkj",
        nonce: 900,
        lastBidder: owner.address,
        deadline: ethers.utils.parseEther("0"),
        instBuyPrice: ethers.utils.parseEther("0"),
      };

      let tx = await marketOps.buyFromApprovedOffer(
        CollectionNFT,
        digest,
        signature,
        { value: ethers.utils.parseEther("2") }
      );
      await tx.wait();

      let afterBalanceOwner = await weth.balanceOf(addr1.address);

      console.log("afterBalanceOwner: ", afterBalanceOwner);

      expect(await vault.getStatus(2)).to.equal(0);
      expect(await vault.ownerOf(2)).to.equal(owner.address);
    });

    it("Should Update the sale price as owner", async function () {
      expect(await vault.getStatus(3)).to.equal(0);

      let tx = await marketOps.justSell(
        vault.address,
        3,
        ethers.utils.parseEther("5")
      );

      await tx.wait();
      expect(await vault.getStatus(3)).to.equal(1);
      expect(await vault.getPrice(3)).to.equal(ethers.utils.parseEther("5"));

      let update = await marketOps.updatePriceAsOwner(
        vault.address,
        3,
        ethers.utils.parseEther("7")
      );
      await update.wait();
      expect(await vault.getPrice(3)).to.equal(ethers.utils.parseEther("7"));
    });
  });

  describe("CollectionFactory and Collection contract", function () {
    it(" CollectionFactory -> Should create a collection", async function () {
      let tx = await collectionFac
        .connect(addr1)
        .createCollection(
          "Transformers",
          "TRF",
          [addr1.address, addr2.address],
          [50, 50],
          "https://ipfs.io/theirsharedFolderCid/",
          ethers.utils.parseEther("1"),
          10000
        );

      let tx_receipt = await tx.wait();
      console.log(
        "New collection created with address: ",
        tx_receipt.events[0].args.collection
      );
      collec = await hre.ethers.getContractAt(
        "LazyCollection",
        tx_receipt.events[0].args.collection,
        addr1
      );

      expect(
        await collectionFac.getAcceptedTokens(
          tx_receipt.events[0].args.collection
        )
      ).to.equal(true);
    });

    it("Collection -> Should redeem an NFT from the collection", async function () {
      let VirtualCollection = {
        generation: {
          id: 0,
          name: "Transformers",
          lastTokenId: 10000,
          price: ethers.utils.parseEther("1"),
        },
        creatorFee: 5,
      };
      console.log("Collection address coming?: ", collec.address);

      let redeemer = new LazyMinter({
        contractAddress: collec.address,
        signer: addr1,
      });
      const [digest, nft, signature] = await redeemer.createVoucher(
        0,
        "Transformers",
        10000,
        ethers.utils.parseEther("1"),
        5
      );
      let beforeBalance = await weth.balanceOf(addr1.address);
      console.log("Before Redeem :", beforeBalance);

      let tx = await collec.redeem(
        owner.address,
        VirtualCollection,
        digest,
        signature,
        { value: ethers.utils.parseEther("1") }
      );
      let receipt = await tx.wait();

      let afterBalance = await weth.balanceOf(addr1.address);
      console.log("after redeem :", afterBalance);
      console.log("New TokenID: ", receipt.events[1].args.tokenId);
      console.log("Checking if it is available to withdraw...");
      expect(await collec.connect(addr1).availableToWithdraw()).to.equal(
        ethers.BigNumber.from("450000000000000000")
      );
      expect(await collec.connect(addr2).availableToWithdraw()).to.equal(
        ethers.BigNumber.from("450000000000000000")
      );
    });

    it("Collection ->  Withdraw the pending withdrawal from NFT sales", async function () {
      let beforeWithdraw = await weth.balanceOf(addr1.address);
      console.log("Before Withdraw:", beforeWithdraw);

      let tx = await collec.connect(addr1).withdraw();
      await tx.wait();

      let afterWithdraw = await weth.balanceOf(addr1.address);
      console.log("After Withdraw:", afterWithdraw);
      expect(await collec.connect(addr1).availableToWithdraw()).to.equal(0);
    });

    it("Collection -> Add new artists then remove some of them", async function () {
      let tx = await collec
        .connect(addr1)
        .addArtists([addr2.address, addr3.address, addr4.address]);
      await tx.wait();

      expect(await collec.isArtist(addr2.address)).to.equal(true);
      expect(await collec.isArtist(addr3.address)).to.equal(true);
      expect(await collec.isArtist(addr4.address)).to.equal(true);

      let tx2 = await collec
        .connect(addr1)
        .removeArtists([addr2.address, addr4.address]);
      await tx2.wait();

      expect(await collec.isArtist(addr2.address)).to.equal(false);
      expect(await collec.isArtist(addr3.address)).to.equal(true);
      expect(await collec.isArtist(addr4.address)).to.equal(false);
    });
    it("Collection -> Change Payees and Shares", async function () {
      let tx = await collec
        .connect(addr1)
        .changePayeesAndShares(
          [addr1.address, addr5.address, addr3.address, addr2.address],
          [25, 25, 25, 25]
        );
      let tx_res = await tx.wait();
      expect(tx_res.events[0].args.newPayeesList[0]).to.equal(
        "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
      );
      expect(tx_res.events[0].args.newPayeesList[1]).to.equal(
        "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc"
      );
      expect(tx_res.events[0].args.newPayeesList[2]).to.equal(
        "0x90F79bf6EB2c4f870365E785982E1f101E93b906"
      );
      expect(tx_res.events[0].args.newPayeesList[3]).to.equal(
        "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
      );
    });

    it("Collection -> Create New Generation and redeem from it", async function () {
      let tx = await collec
        .connect(addr3)
        .createNewGeneration(
          "Mutated Transformers",
          10,
          ethers.BigNumber.from("400000000000000000")
        );
      let txRes = await tx.wait();
      console.log(txRes.events[0].args.name);

      expect(txRes.events[0].args.name).to.equal("Mutated Transformers");
    });

    it("Collection -> Should redeem an NFT from the new Generation of the collection", async function () {
      let VirtualCollection = {
        generation: {
          id: 1,
          name: "Mutated Transformers",
          lastTokenId: 10010,
          price: ethers.BigNumber.from("400000000000000000"),
        },
        creatorFee: 5,
      };
      console.log("Collection address coming?: ", collec.address);

      let redeemer = new LazyMinter({
        contractAddress: collec.address,
        signer: addr1,
      });
      const [digest, nft, signature] = await redeemer.createVoucher(
        1,
        "Mutated Transformers",
        10010,
        ethers.BigNumber.from("400000000000000000"),
        5
      );

      let tx = await collec.redeem(
        owner.address,
        VirtualCollection,
        digest,
        signature,
        { value: ethers.BigNumber.from("400000000000000000") }
      );
      let receipt = await tx.wait();

      console.log("New TokenID: ", receipt.events[1].args.tokenId);
      console.log("Checking if it is available to withdraw...");
      expect(await collec.connect(addr3).availableToWithdraw()).to.equal(
        ethers.BigNumber.from("90000000000000000")
      );
      expect(await collec.connect(addr5).availableToWithdraw()).to.equal(
        ethers.BigNumber.from("90000000000000000")
      );
    });

    it("Collection ->  Withdraw the pending withdrawal from NFT sales", async function () {
      let beforeWithdraw = await weth.balanceOf(addr3.address);
      console.log("Before Withdraw:", beforeWithdraw);

      let tx = await collec.connect(addr3).withdraw();
      await tx.wait();

      let afterWithdraw = await weth.balanceOf(addr3.address);
      console.log("After Withdraw:", afterWithdraw);
      expect(await collec.connect(addr3).availableToWithdraw()).to.equal(0);
    });

    it("CollectionFactory -> Claim the market platform fees", async function () {
      expect(await weth.balanceOf(collectionFac.address)).to.not.equal(0);

      let tx = await collectionFac.withdrawFees();
      await tx.wait();

      expect(await weth.balanceOf(collectionFac.address)).to.equal(0);
    });
  });

  describe("Operations on the redeemed Collection NFT", function () {
    it("Should sell the collection NFT from marketOps interface", async function () {
      let nftBefore = await collectionFac.getCollectionNFT(collec.address, 1);

      expect(nftBefore.status).to.equal(0);

      let tx = await marketOps.justSell(
        collec.address,
        1,
        ethers.utils.parseEther("1")
      );
      await tx.wait();
      let nft = await collectionFac.getCollectionNFT(collec.address, 1);

      expect(nft.status).to.equal(1);
      expect(nft.price).to.equal(ethers.utils.parseEther("1"));
      expect(nft._tokenAddress).to.equal(collec.address);
      expect(nft._tokenId).to.equal(1);
    });

    it("Should Buy the collection NFT", async function () {
      let tx = await marketOps
        .connect(addr1)
        .buy(collec.address, 1, { value: ethers.utils.parseEther("1") });
      await tx.wait();

      let nft = await collectionFac.getCollectionNFT(collec.address, 1);

      expect(nft.status).to.equal(0);
      expect(nft.owner).to.equal(addr1.address);
      expect(nft._tokenAddress).to.equal(collec.address);
      expect(nft._tokenId).to.equal(1);
    });

    it("Should Create auction with collection NFT", async function () {
      let tx = await marketOps
        .connect(addr1)
        .createDeadlineAuction(
          collec.address,
          1,
          ethers.BigNumber.from("90000000000000000"),
          5,
          1912918335,
          ethers.utils.parseEther("2")
        );

      await tx.wait();

      let nft = await collectionFac.getCollectionNFT(collec.address, 1);

      expect(nft.status).to.equal(3);
      expect(nft.owner).to.equal(addr1.address);
      expect(nft._tokenAddress).to.equal(collec.address);
      expect(nft._tokenId).to.equal(1);
      expect(nft.price).to.equal(ethers.BigNumber.from("90000000000000000"));
      expect(nft.instBuyPrice).to.equal(ethers.utils.parseEther("2"));
    });

    it("Should bid on the auction of a collection NFT", async function () {
      expect(await weth.balanceOf(collectionOps.address)).to.equal(0);

      let tx = await marketOps.makeOffer(
        collec.address,
        1,
        ethers.BigNumber.from("90000000000000000"),
        { value: ethers.BigNumber.from("90000000000000000") }
      );
      await tx.wait();
      expect(await weth.balanceOf(collectionOps.address)).to.equal(
        ethers.BigNumber.from("90000000000000000")
      );

      let nft = await collectionFac.getCollectionNFT(collec.address, 1);

      expect(nft.status).to.equal(3);
      expect(nft.owner).to.equal(addr1.address);
      expect(nft._tokenAddress).to.equal(collec.address);
      expect(nft._tokenId).to.equal(1);
      expect(nft.price).to.equal(ethers.BigNumber.from("90000000000000000"));

      let tx2 = await marketOps
        .connect(addr3)
        .makeOffer(
          collec.address,
          1,
          ethers.BigNumber.from("100000000000000000"),
          { value: ethers.BigNumber.from("100000000000000000") }
        );
      await tx2.wait();

      let nft2 = await collectionFac.getCollectionNFT(collec.address, 1);

      expect(nft2.status).to.equal(3);
      expect(nft2.owner).to.equal(addr1.address);
      expect(nft2._tokenAddress).to.equal(collec.address);
      expect(nft2._tokenId).to.equal(1);
      expect(nft2.price).to.equal(ethers.BigNumber.from("100000000000000000"));
      expect(nft2.lastBidder).to.equal(addr3.address);
      expect(await weth.balanceOf(collectionOps.address)).to.equal(
        ethers.BigNumber.from("100000000000000000")
      );
    });

    it("Should accept the highest bid on the auction", async function () {
      expect(await weth.balanceOf(collectionOps.address)).to.equal(
        ethers.BigNumber.from("100000000000000000")
      );
      console.log(
        "Before ending auction: ",
        await weth.balanceOf(addr1.address)
      );
      let tx = await marketOps.connect(addr1).acceptOffer(collec.address, 1);
      await tx.wait();

      console.log(
        "After ending auction: ",
        await weth.balanceOf(addr1.address)
      );

      expect(await weth.balanceOf(collectionOps.address)).to.equal(
        ethers.BigNumber.from("0")
      );
    });

    it("Should buy from his/her approved offer on the collection NFT id:1", async function () {
      const approver = new ApproveOfferer({
        contractAddress: marketOps.address,
        signer: addr3,
      });
      const [digest, nft, signature] = await approver.createVoucher(
        owner.address,
        addr3.address,
        ethers.utils.parseEther("2"),
        1,
        collec.address,
        "ipfs://aksjkjdakjadkj",
        5,
        owner.address,
        124
      );

      // wait until the transaction is mined
      // console.log('signature: ', signature);

      // expect(recoveredAddress.wait()).to.equal(owner.address);
      let beforeBalanceOwner = await weth.balanceOf(addr3.address);

      console.log("beforeBalanceOwner: ", beforeBalanceOwner);

      let CollectionNFT = {
        _tokenAddress: collec.address,
        _tokenId: 1,
        approvedOfferer: owner.address,
        creator: owner.address,
        owner: addr3.address,
        creatorLoyalty: 5,
        status: 0,
        minBidIncPercent: 0,
        price: ethers.utils.parseEther("2"),
        tokenURI: "ipfs://aksjkjdakjadkj",
        nonce: 124,
        lastBidder: owner.address,
        deadline: ethers.utils.parseEther("0"),
        instBuyPrice: ethers.utils.parseEther("0"),
      };

      let tx = await marketOps.buyFromApprovedOffer(
        CollectionNFT,
        digest,
        signature,
        { value: ethers.utils.parseEther("2") }
      );
      await tx.wait();

      let afterBalanceOwner = await weth.balanceOf(addr3.address);

      console.log("afterBalanceOwner: ", afterBalanceOwner);
    });

    it("Should Update The Price of nfts", async function () {
      let nftBefore = await collectionFac.getCollectionNFT(collec.address, 1);

      expect(nftBefore.status).to.equal(0);

      let tx = await marketOps.justSell(
        collec.address,
        1,
        ethers.utils.parseEther("1")
      );
      await tx.wait();
      let nft = await collectionFac.getCollectionNFT(collec.address, 1);

      expect(nft.status).to.equal(1);
      expect(nft.price).to.equal(ethers.utils.parseEther("1"));
      expect(nft._tokenAddress).to.equal(collec.address);
      expect(nft._tokenId).to.equal(1);

      let update = await marketOps.updatePriceAsOwner(
        collec.address,
        1,
        ethers.utils.parseEther("7")
      );
      await update.wait();
      let nft2 = await collectionFac.getCollectionNFT(collec.address, 1);

      expect(nft2.price).to.equal(ethers.utils.parseEther("7"));
    });

    it("Should Buy with An Instant Buy Price on Auctioned NFT", async function () {
      let tx = await marketOps.createDeadlineAuction(
        collec.address,
        1,
        ethers.BigNumber.from("90000000000000000"),
        5,
        1912918335,
        ethers.utils.parseEther("1")
      );

      await tx.wait();

      let nft = await collectionFac.getCollectionNFT(collec.address, 1);

      expect(nft.status).to.equal(3);
      expect(nft.owner).to.equal(owner.address);
      expect(nft._tokenAddress).to.equal(collec.address);
      expect(nft._tokenId).to.equal(1);
      expect(nft.price).to.equal(ethers.BigNumber.from("90000000000000000"));
      expect(nft.instBuyPrice).to.equal(ethers.utils.parseEther("1"));

      let tx2 = await marketOps
        .connect(addr3)
        .buy(collec.address, 1, { value: ethers.utils.parseEther("1") });

      await tx2.wait();
      let nftAfter = await collectionFac.getCollectionNFT(collec.address, 1);

      expect(nftAfter.status).to.equal(0);
      expect(nftAfter.owner).to.equal(addr3.address);
      expect(nftAfter._tokenAddress).to.equal(collec.address);
      expect(nftAfter._tokenId).to.equal(1);
      expect(nftAfter.price).to.equal(0);
    });

    it("Should Cancel An auction that has no offers", async function () {
      let tx = await marketOps
        .connect(addr3)
        .createDeadlineAuction(
          collec.address,
          1,
          ethers.BigNumber.from("90000000000000000"),
          5,
          1912918335,
          ethers.utils.parseEther("1")
        );

      await tx.wait();

      let nft = await collectionFac.getCollectionNFT(collec.address, 1);

      expect(nft.status).to.equal(3);
      expect(nft.owner).to.equal(addr3.address);
      expect(nft._tokenAddress).to.equal(collec.address);
      expect(nft._tokenId).to.equal(1);
      expect(nft.price).to.equal(ethers.BigNumber.from("90000000000000000"));
      expect(nft.instBuyPrice).to.equal(ethers.utils.parseEther("1"));

      let tx2 = await marketOps.cancelAuctionOrSale(collec.address, 1);
      await tx2.wait();

      let nft2 = await collectionFac.getCollectionNFT(collec.address, 1);
      expect(nft2.status).to.equal(0);
    });
  });
});
