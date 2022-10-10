## `LazyCollectionFactory`





### `isAdmin()`





### `isOperator()`






### `constructor(address marketToken, address payable _feeAdmin, address _collectionOperations, address acceptedPaymentTokens1, address acceptedPaymentTokens2, address acceptedPaymentTokens3)` (public)

intentionally put 3 payment method additional to market token to avoid unnecessary loops and arrays.
This approach is much more stable.
/



### `getAcceptedPaymentAddress(uint256 _paymentID) → address` (external)





### `changePaymentMethod(uint256 _paymentID, address _erc20Address)` (external)

Dont use _paymentID as bigger than 3. It is fixed.
/

change payment method
changing payment method of the payment method of paymentID index of acceptedPaymentAddresses


### `getCollectionNFT(address _tokenAddress, uint256 _tokenID) → struct LazyCollectionFactory.CollectionNFT nft` (external)

Show NFT with the tokenID of the collection




### `setCollectionNft(struct LazyCollectionFactory.CollectionNFT nft)` (external)

Set NFT with the tokenID of the collection




### `setMarketCut(uint8 percentage)` (public)

Set Market cut



### `setRedeemed(uint256 id, uint256 minPrice, string baseUri, uint8 _creatorLoyalty, address creator)` (external)



setRedeemed function for tell the factory contract that An NFT redeemed on a child collection
called from collection Contract externally, checks if the contract is an accepted contract with acceptedTokens array

/

### `getAcceptedTokens(address _tokenAddress) → bool` (external)





### `setAcceptedTokens(address nftAddress, bool status)` (internal)





### `createCollection(string collectionName, string collectionSymbol, address acceptedPayment, address[] _payees, uint8[] _shares, string baseUri) → address` (public)

Payees and shares should be for example like this format: payees: ["address","address2","address3"] shares: [%20,%30,%50]
/

Create a new ERC721 lazyCollection contract


### `withdrawFees()` (public)






### `CollectionCreated(address collection, string collectionName, string collectionSymbol, address[] _payees, uint8[] _shares, address _owner, uint8 _cut, string _baseUri, address acceptedPayment)`





### `Redeemed(uint256 token_id, uint256 minPrice, string baseUri, uint8 loyalty_fee, address signer)`






### `CollectionNFT`


uint256 _tokenId


address _tokenAddress


address creator


uint8 creatorLoyalty


uint8 status


uint8 minBidIncPercent


uint256 price


address lastBidder


uint256 instBuyPrice


uint256 deadline


address acceptedPaymentMethod



