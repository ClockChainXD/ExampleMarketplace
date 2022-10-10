// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LazyCollection.sol";

interface ILazyCollection {
    function initialize(
        address[] memory,
        uint8[] memory,
        address owner,
        uint8 marketcut,
        address marketNftOperations,
        string memory _baseUri
    ) external returns (bool);
}

contract LazyCollectionFactory {
    event CollectionCreated(
        address indexed collection,
        string collectionName,
        string collectionSymbol,
        address[] _payees,
        uint8[] _shares,
        address _owner,
        uint8 _cut,
        string _baseUri,
        address indexed acceptedPayment
    );
    event Redeemed(
        uint256 token_id,
        uint256 minPrice,
        uint8 loyalty_fee,
        address signer
    );

    bytes32 public constant INIT_CODE_LAZY_HASH =
        keccak256(abi.encodePacked(type(LazyCollection).creationCode));
    mapping(address => mapping(uint256 => CollectionNFT)) public CollectionNFTs;
    mapping(bytes32 => bool) public isOld;
    mapping(address => bool) public acceptedTokens;
    uint256 public collectionCounter;
    address payable public feeAdmin;
    address public collectionOperations;
    mapping(uint256 => address) public collectionMap;
    address public WETH;

    uint8 public marketCut = 10;

    modifier isAdmin() {
        require(feeAdmin == msg.sender, "You are not the admin!!");
        _;
    }

    modifier isOperator() {
        require(
            msg.sender == collectionOperations,
            "You are not the operator??"
        );
        _;
    }
    struct CollectionNFT {
        uint256 _tokenId;
        address _tokenAddress;
        string tokenURI;
        address creator;
        address owner;
        uint8 creatorLoyalty;
        uint8 status;
        uint8 minBidIncPercent;
        uint256 price;
        address lastBidder;
        uint256 instBuyPrice;
        uint256 deadline;
        address approvedOfferer;
        uint256 nonce;
    }

    /**
 intentionally put 3 payment method additional to red token to avoid unnecessary loops and arrays.
 This approach is much more stable.
 
  */
    constructor(
        address _weth,
        address payable _feeAdmin,
        address _collectionOperations
    ) {
        WETH = _weth;
        feeAdmin = _feeAdmin;
        collectionOperations = _collectionOperations;
    }

    function getCollectionNFT(address _tokenAddress, uint256 _tokenID)
        external
        view
        returns (CollectionNFT memory nft)
    {
        return CollectionNFTs[_tokenAddress][_tokenID];
    }

    function setCollectionNft(CollectionNFT memory nft) external isOperator {
        CollectionNFTs[nft._tokenAddress][nft._tokenId] = nft;
    }

    function setMarketCut(uint8 percentage) public isAdmin {
        marketCut = percentage;
    }

    function setRedeemed(
        uint256 id,
        uint256 minPrice,
        uint8 creatorFee,
        address _creator,
        address _owner
    ) external {
        require(acceptedTokens[msg.sender], "Not an accepted collection");
        CollectionNFT storage nft = CollectionNFTs[msg.sender][id];
        nft.creator = _creator;
        nft.owner = _owner;
        nft.creatorLoyalty = creatorFee;
        nft._tokenId = id;
        nft._tokenAddress = msg.sender;
        nft.status = 0;
        nft.approvedOfferer = address(0);
        nft.lastBidder = address(0);
        emit Redeemed(id, minPrice, creatorFee, _creator);
    }

    function getAcceptedTokens(address _tokenAddress)
        external
        view
        returns (bool)
    {
        return acceptedTokens[_tokenAddress];
    }

    function setAcceptedTokens(address nftAddress, bool status) internal {
        acceptedTokens[nftAddress] = status;
    }

    function createCollection(
        string memory collectionName,
        string memory collectionSymbol,
        address[] memory payees,
        uint8[] memory _shares,
        string memory baseUri,
        uint256 initialPrice,
        uint256 initialSupply
    ) public returns (address) {
        require(
            payees.length < 10 && (payees.length == _shares.length),
            "Your payees maximum length is 10"
        );
        bytes32 salt = keccak256(
            abi.encodePacked(
                keccak256(bytes(collectionName)),
                keccak256(bytes(collectionSymbol))
            )
        );

        require(!isOld[salt], "Collection Exists can't deploy!");

        LazyCollection newCollection = new LazyCollection(
            collectionName,
            collectionSymbol,
            WETH,
            initialPrice,
            initialSupply,
            collectionOperations
        );

        isOld[salt] = true;
        collectionCounter = collectionCounter + 1;
        newCollection.initialize(
            payees,
            _shares,
            msg.sender,
            marketCut,
            baseUri
        );
        collectionMap[collectionCounter] = address(newCollection);
        setAcceptedTokens(address(newCollection), true);
        emit CollectionCreated(
            address(newCollection),
            collectionName,
            collectionSymbol,
            payees,
            _shares,
            msg.sender,
            marketCut,
            baseUri,
            WETH
        );
        return address(newCollection);
    }

    function withdrawFees() public isAdmin {
        require(msg.sender == feeAdmin, "YOU ARE NOT THE FEE ADMIN BRO");

        if (IWETH(WETH).balanceOf(address(this)) > 0)
            IWETH(WETH).transfer(
                msg.sender,
                IWETH(WETH).balanceOf(address(this))
            );
    }
}
