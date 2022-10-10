## `LazyCollection`





### `isOwner()`





### `isFactory()`






### `constructor(string name, string symbol, address acceptedPayment)` (public)

Name symbol of the contract and accepted ERC20 Payment Token address



### `_baseURI() → string` (internal)





### `tokenURI(uint256 tokenId) → string` (public)

This can be used to determine tokenUri's before actual minting.
And that can be used to listing NFT's without needing to add them seperately to the collection page

/

TokenURI overriden to make it more usable by market platform.


### `justBurn(uint256 _tokenId)` (external)





### `redeem(address redeemer, struct LazyCollection.VirtualCollection virtualNft, bytes signature) → uint256` (public)



Redeem is for redeeming the lazy minted NFT with using the creator's signature


### `initialize(address[] _payees, uint8[] _shares, address _owner, uint8 _cut, string _baseUri)` (external)



Initialize of the contract immediately after creation of this contract, on the createCollection method


### `splitPayment(uint256 amount)` (internal)



splits payments used only on redeem.
splits payments to payees with respec to their shares
/

### `addArtists(address[] newArtists)` (public)



adds new artists


### `removeArtists(address[] oldArtists)` (public)



adds new artists


### `changePayeesAndShares(address[] newPayeesList, uint8[] newShareList)` (public)



change payees and shares, they will be completely swapped with new arrays


### `withdraw()` (public)



withdraw function to withdraw collectionAcceptedPaymentMethod
/

### `availableToWithdraw() → uint256` (public)





### `_hash(struct LazyCollection.VirtualCollection virtualNft) → bytes32` (internal)

Returns a hash of the given VirtualCollection, prepared using EIP712 typed data hashing rules.




### `_verify(struct LazyCollection.VirtualCollection virtualNft, bytes signature) → address` (internal)

Verifies the signature for a given VirtualCollection, returning the address of the signer.


Will revert if the signature is invalid. Does not verify that the signer is authorized to mint NFTs.


### `supportsInterface(bytes4 interfaceId) → bool` (public)

classic supportsInterface method to see supported interface of this contract




### `ArtistAdded(address newArtist)`





### `ArtistRemoved(address oldArtist)`





### `PayeesAndSharesChanged(address[] newPayeesList, uint8[] newShareList)`





### `PaymentSplitted(address[] guys, uint8[] shares, uint256 amount)`






### `VirtualCollection`


uint256 tokenId


uint256 minPrice


string baseUri


uint8 creatorFee



