const { ethers } = require("hardhat");
const { TypedDataUtils } = require('ethers-eip712')

const SIGNING_DOMAIN_NAME = "Transformers"
const SIGNING_DOMAIN_VERSION = "1"

class LazyMinter {

  constructor({ contractAddress, signer }) {
    this.contractAddress = contractAddress
    this.signer = signer

    this.types = {
        EIP712Domain: [
          { name: "name", type: "string" },
          { name: "version", type: "string" },
          { name: "chainId", type: "uint256" },
          { name: "verifyingContract", type: "address" },
        ],
        VirtualCollection: [
          {name: "id", type: "uint256"},
          { name: "name", type: "string" },
          { name: "lastTokenId", type: "uint256" },
          { name: "price", type: "uint256" },
          { name: "creatorFee", type: "uint8" }

        ],
      };
  }

   _signingDomain() {
    const chainId = 31337
    this._domain = {
      name: SIGNING_DOMAIN_NAME,
      version: SIGNING_DOMAIN_VERSION,
      chainId,
      verifyingContract: this.contractAddress,
    }
    return this._domain
  }

  async _formatVoucher(nft) {
    const domain =  this._signingDomain()
    return {
      types: {
        EIP712Domain: [
          { name: "name", type: "string" },
          { name: "version", type: "string" },
          { name: "chainId", type: "uint256" },
          { name: "verifyingContract", type: "address" },
        ],
        VirtualCollection: [
          {name: "id", type: "uint256"},
          { name: "name", type: "string" },
          { name: "lastTokenId", type: "uint256" },
          { name: "price", type: "uint256" },
          { name: "creatorFee", type: "uint8" }
        ],
    
      },
      primaryType: "VirtualCollection",
      domain: domain,
      message: nft,
    };
  }

  async createVoucher(id,name,lastTokenId,price, creatorFee) {

 
    
    const nft = { id,name,lastTokenId,price, creatorFee }
    /* const typedData = await this._formatVoucher(nft)
    
    // const digest = TypedDataUtils.encodeDigest(typedData)
    const domain =  this._signingDomain()

    const signature =  this.signer._signTypedData(this._domain,
        { NFT: this.types.NFT },
        nft);
     const recoveredAddress=  ethers.utils.verifyTypedData( this._domain,
      { NFT: this.types.NFT },
      voucher,signature);  */
      const typedData = await this._formatVoucher(nft);

      const digest = TypedDataUtils.encodeDigest(typedData)
     const domain = this._signingDomain();
 
    // const [method, argData] = ['eth_sig', typedData]
     const signature= await this.signer.signMessage(digest);
    // console.log(digest);
     /* const signature = await this.signer._signTypedData(
       this._domain,
       { CollectionNFT: this.types.CollectionNFT },
       nft
     ); */
     const recoveredAddress=  ethers.utils.verifyMessage( digest,signature);
 
       
      /*  console.log("Digest: ",digest.toString())
     console.log("Signature: ", signature);
       console.log("Recoverted: ",recoveredAddress) */
     return [digest,nft,signature];
  }

}

  


module.exports = {
  LazyMinter
}