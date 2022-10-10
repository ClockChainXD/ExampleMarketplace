const { ethers } = require("hardhat");
const { TypedDataUtils } = require('ethers-eip712')

const SIGNING_DOMAIN_NAME = "LEXITNFT";
const SIGNING_DOMAIN_VERSION = "1";

class ApproveOfferer {
  constructor({ contractAddress, signer }) {
    this.contractAddress = contractAddress;
    this.signer = signer;

    this.types = {
      EIP712Domain: [
        { name: "name", type: "string" },
        { name: "version", type: "string" },
        { name: "chainId", type: "uint256" },
        { name: "verifyingContract", type: "address" },
      ],
      CollectionNFT: [
        { name: "creator", type: "address" },
        { name: "owner", type: "address" },
        { name: "price", type: "uint256" },
        { name: "_tokenId", type: "uint256" },
        { name: "_tokenAddress", type: "address" },
        { name: "tokenURI", type: "string" },
        { name: "creatorLoyalty", type: "uint8" },
        { name: "approvedOfferer", type: "address" },
        { name: "nonce", type: "uint256" },
      ],
    };
  }

  _signingDomain() {
    //change this chainId if you don't use hardhat network
    const chainId = 31337;
    this._domain = {
      name: SIGNING_DOMAIN_NAME,
      version: SIGNING_DOMAIN_VERSION,
      chainId,
      verifyingContract: this.contractAddress,
    };
    return this._domain;
  }

  async _formatVoucher(nft) {
    const domain = this._signingDomain();
    return {
      types: {
        EIP712Domain: [
          { name: "name", type: "string" },
          { name: "version", type: "string" },
          { name: "chainId", type: "uint256" },
          { name: "verifyingContract", type: "address" },
        ],
        CollectionNFT: [
          { name: "creator", type: "address" },
          { name: "owner", type: "address" },
          { name: "price", type: "uint256" },
          { name: "_tokenId", type: "uint256" },
          { name: "_tokenAddress", type: "address" },
          { name: "tokenURI", type: "string" },
          { name: "creatorLoyalty", type: "uint8" },
          { name: "approvedOfferer", type: "address" },
          { name: "nonce", type: "uint256" },
        ],
      },
      primaryType: "CollectionNFT",
      domain: domain,
      message: nft,
    };
  }

  async createVoucher(
    creator,
    owner,
    price,
    _tokenId,
    _tokenAddress,
    tokenURI,
    creatorLoyalty,
    approvedOfferer,
    nonce
  ) {
    const nft = {
      creator,
      owner,
      price,
      _tokenId,
      _tokenAddress,
      tokenURI,
      creatorLoyalty,
      approvedOfferer,
      nonce,
    };
    const typedData = await this._formatVoucher(nft);

     const digest = TypedDataUtils.encodeDigest(typedData)
  //  const domain = this._signingDomain();

   // const [method, argData] = ['eth_sig', typedData]
    const signature= await this.signer.signMessage(digest);
   // console.log(digest);
    /* const signature = await this.signer._signTypedData(
      this._domain,
      { CollectionNFT: this.types.CollectionNFT },
      nft
    ); */
    //const recoveredAddress=  ethers.utils.verifyMessage( digest,signature);

      
    /*   console.log("Digest: ",digest.toString())
    console.log("Signature: ", signature);
      console.log("Recoverted: ",recoveredAddress) */
    return [digest,nft,signature];
  }
}

module.exports = {
  ApproveOfferer,
};
