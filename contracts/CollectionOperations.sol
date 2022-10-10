// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@openzeppelin/contracts/utils/Counters.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "@openzeppelin/contracts/utils/Address.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

interface IWETH {
    function deposit() external payable;

    function balanceOf(address) external returns (uint256);

    function withdraw(uint256 wad) external;

    function approve(address, uint256) external;

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) external returns (bool);
}

interface ILazyCollection {
    function justBurn(uint256 _tokenId) external;

    function justTransfer(
        address from,
        address to,
        uint256 _id
    ) external;
}

interface ILazyCollectionFactory {
    function getAcceptedTokens(address _tokenAddress)
        external
        view
        returns (bool);

    function setAcceptedTokens(address nftAddress, bool status) external;

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

    function getCollectionNFT(address _tokenAddress, uint256 _tokenID)
        external
        view
        returns (CollectionNFT memory nft);

    function setCollectionNft(CollectionNFT memory nft) external;
}

pragma experimental ABIEncoderV2;
pragma solidity >=0.8.0;

contract CollectionOperations is Ownable {
    using Counters for Counters.Counter;
    using Address for address;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public adminFeeAddress;
    address public collectionFactory;
    uint8 public marketOperationsFeePercent = 5;
    address public MarketOperations;
    address public WETH;
    ILazyCollectionFactory collecFactory;

    modifier onlyOperations() {
        address _sender = msg.sender;
        require(
            MarketOperations == _sender,
            "This is not the collection factory"
        );
        _;
    }

    modifier _validateTokenOwner(
        address _sender,
        address tokenAddress,
        uint256 _tokenId,
        bool deadlineReached
    ) {
        require(
            IERC721(tokenAddress).ownerOf(_tokenId) == _sender ||
                (deadlineReached && owner() == _sender),
            "Validation failed, You are not the owner"
        );

        require(
            collecFactory.getAcceptedTokens(tokenAddress),
            "This token is not accepted on our platform"
        );

        _;
    }

    modifier _validateBuyer(address tokenAddress, uint256 _tokenId) {
        ILazyCollectionFactory.CollectionNFT memory nft = collecFactory
            .getCollectionNFT(tokenAddress, _tokenId);

        require(
            collecFactory.getAcceptedTokens(tokenAddress),
            "This token is not accepted on our platform"
        );

        _;
    }
    modifier _validateOfferer(
        address _sender,
        address _tokenAddr,
        uint256 _tokenId,
        uint256 _offer
    ) {
        require(
            _sender != IERC721(_tokenAddr).ownerOf(_tokenId),
            "You can't bid your nft"
        );
        require(
            collecFactory.getAcceptedTokens(_tokenAddr),
            "This token is not accepted on our platform"
        );

        _;
    }

    /// Accepted Payments are marketToken and BUSD.
    /// This contract is not directly used but used on MarketOperations contract. Because I did it to make this reachable on other contract To make it easy to implement on frontend
    /// @notice Owner of this contract and MarketOperations Admin should be the SAME ADDRESS
    constructor(address _weth, address _adminFeeAddress) {
        adminFeeAddress = _adminFeeAddress;
        WETH = _weth;
    }

    function setMarketOperations(address _ops) public onlyOwner {
        MarketOperations = _ops;
    }

    /// Set this address as collectionFactory. Use this after Deployment of MarketOperations
    function setCollectionFactory(address _factory) public onlyOwner {
        collectionFactory = _factory;
        collecFactory = ILazyCollectionFactory(_factory);
    }

    /**
     * @dev Sell the NFT with the payment method MarketToken or BUSD
     * @param sender Seller the owner of the NFT
     * @param _tokenAddress Market LazyCollection contract address
     * @param _tokenId token_id of the collection NFT
     * @param price price as uint256
     *
     */
    function justSell(
        address sender,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 price
    )
        external
        _validateTokenOwner(sender, _tokenAddress, _tokenId, false)
        onlyOperations
    {
        ILazyCollectionFactory.CollectionNFT
            memory nft = ILazyCollectionFactory(collectionFactory)
                .getCollectionNFT(_tokenAddress, _tokenId);
        require(nft.status == 0, "It is already listed or on auction");

        nft._tokenId = _tokenId;
        nft._tokenAddress = _tokenAddress;
        nft.status = 1;
        nft.price = price;
        ILazyCollectionFactory(collectionFactory).setCollectionNft(nft);
    }

    /// This function is for buying from justSell option or instant buyer!
    /// @param sender  the buyer of the NFT
    /// @param _tokenAddress Collection NFT address
    /// @param _tokenId Collection NFT tokenID
    function buy(
        address sender,
        address _tokenAddress,
        uint256 _tokenId
    )
        external
        payable
        _validateBuyer(_tokenAddress, _tokenId)
        onlyOperations
        returns (uint256)
    {
        require(
            collecFactory.getAcceptedTokens(_tokenAddress),
            "Token is not accepted"
        );
        ILazyCollectionFactory.CollectionNFT memory nft = collecFactory
            .getCollectionNFT(_tokenAddress, _tokenId);
        require(
            IWETH(WETH).balanceOf(sender) + address(msg.sender).balance >
                nft.price,
            "Insufficient Funds"
        );

        require(
            (nft.status == 1) || (nft.instBuyPrice > 0 && (nft.status == 3)),
            "Error: This token is on Auction."
        );
        uint256 instPrice = nft.instBuyPrice;
        uint256 nprice = nft.price;
        nft.status = 0;
        _justTrade(sender, _tokenAddress, _tokenId);
        if (instPrice > 0) {
            address prevBidder = nft.lastBidder;
            if (prevBidder != address(0)) {
                IWETH(WETH).transfer(prevBidder, nprice);
            }
            nft.instBuyPrice = 0;
            nft.lastBidder = address(0);
        }
        nft.owner = sender;
        nft.price = 0;
        collecFactory.setCollectionNft(nft);
        return nprice;
    }

    /**
     * @dev Update the Price
     * @param sender  the owner of the NFT
     * @param _tokenAddress Collection NFT tokenAddress
     * @param _tokenId Collection NFT tokenID
     * @param _price Wanted Price
     *
     */
    function updatePriceAsOwner(
        address sender,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _price
    )
        external
        _validateTokenOwner(sender, _tokenAddress, _tokenId, false)
        onlyOperations
        returns (uint256)
    {
        ILazyCollectionFactory.CollectionNFT memory nft = collecFactory
            .getCollectionNFT(_tokenAddress, _tokenId);
        uint256 oldPrice = nft.price;
        nft.price = _price;
        collecFactory.setCollectionNft(nft);

        return oldPrice;
    }

    /// Cancel the auction or the sale. Owner of this token or the admin can call this.
    /// @param sender  the owner of the NFT
    /// @param _tokenAddress Collection NFT tokenAddress
    /// @param _tokenId Collection NFT tokenID
    function cancelAuctionOrSale(
        address sender,
        address _tokenAddress,
        uint256 _tokenId
    )
        external
        _validateTokenOwner(sender, _tokenAddress, _tokenId, true)
        onlyOperations
    {
        ILazyCollectionFactory.CollectionNFT memory nft = collecFactory
            .getCollectionNFT(_tokenAddress, _tokenId);

        address lastbidder = nft.lastBidder;
        require(lastbidder == address(0), "Can't cancel when you have bidders");

        address payable prevBidder = payable(nft.lastBidder);
        uint256 _prevPrice = nft.price;
        require(nft.status > 0, "This token is not on an auction or on sale");
        uint8 state = nft.status;
        nft.status = 0;
        if (state == 3) {
            if (nft.deadline != 0) {
                nft.deadline = 0;
            }

            if (prevBidder != address(0)) {
                IWETH(WETH).transfer(prevBidder, _prevPrice);
            }
            nft.lastBidder = address(0);
            nft.price = 0;
            nft.instBuyPrice = 0;
        }
        collecFactory.setCollectionNft(nft);
    }

    /**
     *  @dev Create an auction with deadline (status: 3)   Time respect to seconds but not miliseconds care!!
     * @param sender Offerer user
     * @param _tokenAddress  Collection NFT address
     * @param _tokenId token_id of the Collection NFT
     * @param _price offer amount of the bid
     * @param _minBidIncreasePercent minimum percent Of Increase on bids in range of 0-50 %
     * @param _deadline Deadline as seconds => unixTimeStamp/1000
     * @param _instantBuyPrice (optional) Instant Buy Price user can buy instantly. Make it 0 if not used
     * @notice If deadline finished owner or MarketPlatform Admin should cancel the auction.
     *
     *
     */

    function createDeadlineAuction(
        address sender,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _price,
        uint8 _minBidIncreasePercent,
        uint256 _deadline,
        uint256 _instantBuyPrice
    )
        external
        _validateTokenOwner(sender, _tokenAddress, _tokenId, false)
        onlyOperations
    {
        ILazyCollectionFactory.CollectionNFT memory nft = collecFactory
            .getCollectionNFT(_tokenAddress, _tokenId);
        require(nft.status != 3, "This has already listed");
        nft.minBidIncPercent = _minBidIncreasePercent;
        nft.price = _price;
        nft.instBuyPrice = _instantBuyPrice;
        nft.status = 3;
        nft.deadline = _deadline;
        collecFactory.setCollectionNft(nft);
    }

    /**
     * @dev Making a bid offer
     * @param sender Offerer user
     * @param _tokenAddress  Collection NFT address
     * @param _tokenId token_id of the Collection NFT
     * @param _offer offer amount of the bid
     */
    function makeOffer(
        address sender,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _offer
    )
        external
        _validateOfferer(sender, _tokenAddress, _tokenId, _offer)
        onlyOperations
    {
        ILazyCollectionFactory.CollectionNFT memory nft = collecFactory
            .getCollectionNFT(_tokenAddress, _tokenId);
        require(nft.deadline >= block.timestamp, "Deadline reached");
        require(nft.lastBidder != sender, "You bidded already!");
        address prevBidder = nft.lastBidder;
        uint256 _prevPrice = nft.price;

        require(
            ((_prevPrice.mul(nft.minBidIncPercent)).div(100)) + _prevPrice <=
                _offer ||
                (prevBidder == address(0) && _offer == nft.price),
            "Bid bigger than minBidIncPercent"
        );
        if (prevBidder != address(0)) {
            IWETH(WETH).transfer(prevBidder, _prevPrice);
        }

        IWETH(WETH).transferFrom(MarketOperations, address(this), _offer);
        nft.lastBidder = sender;
        nft.price = _offer;
        collecFactory.setCollectionNft(nft);
    }

    /**
     * @dev Accept last bid offer of the auction and reset the token stats
     * @param _sender owner of the auction
     * @param _tokenAddress Collection Address of the nft
     * @param _id token_id of the collection nft
     * @return _owner
     * @return _lastBidder
     * @return _lastPrice
     * @return tokenAddress
     * @return id
     */
    function acceptOffer(
        address _sender,
        address _tokenAddress,
        uint256 _id
    )
        external
        _validateTokenOwner(_sender, _tokenAddress, _id, false)
        onlyOperations
        returns (
            address _owner,
            address _lastBidder,
            uint256 _lastPrice,
            address tokenAddress,
            uint256 id
        )
    {
        ILazyCollectionFactory.CollectionNFT memory nft = collecFactory
            .getCollectionNFT(_tokenAddress, _id);
        require(
            (nft.status == 3),
            "You are not on auction, or deadline has not been reached"
        );
        require(nft.lastBidder != address(0), "You have no bidder");
        _owner = IERC721(_tokenAddress).ownerOf(_id);
        _lastBidder = nft.lastBidder;
        nft.minBidIncPercent = 0;
        _lastPrice = nft.price;
        nft.price = 0;
        nft.instBuyPrice = 0;
        nft.status = 0;
        nft.lastBidder = address(0);
        tokenAddress = _tokenAddress;
        id = _id;
        _trade(_tokenAddress, _id, _lastPrice, _lastBidder);
        nft.owner = _lastBidder;

        nft.instBuyPrice = 0;
        collecFactory.setCollectionNft(nft);
    }

    /**
     * @dev Accept last bid offer of the auction and reset the token stats
     * @param _sender owner of the auction
     * @param nft  the nft object that is used
     */
    function buyFromApprovedOffer(
        address _sender,
        ILazyCollectionFactory.CollectionNFT calldata nft
    ) external onlyOperations {
        ILazyCollectionFactory.CollectionNFT memory _nft = collecFactory
            .getCollectionNFT(nft._tokenAddress, nft._tokenId);

        require(_nft.status == 0, "Can't do it while you are listed");
        _nft.minBidIncPercent = 0;

        _nft.price = 0;
        _nft.instBuyPrice = 0;
        _nft.status = 0;
        IWETH(WETH).transferFrom(MarketOperations, address(this), nft.price);
        _trade(nft._tokenAddress, nft._tokenId, nft.price, nft.approvedOfferer);
        // if sender is not the bidder this means this offer is from another place and lastBidder has stuck funds.

        _nft.instBuyPrice = 0;
        _nft.owner = _sender;
        collecFactory.setCollectionNft(_nft);
    }

    function _justTrade(
        address _sender,
        address tokenAddr,
        uint256 _id
    ) internal {
        ILazyCollectionFactory.CollectionNFT memory nft = collecFactory
            .getCollectionNFT(tokenAddr, _id);
        address payable _owner = payable(IERC721(tokenAddr).ownerOf(_id));
        address payable _buyer = payable(_sender);
        uint256 _price = nft.price;
        address payable _creator = payable(nft.creator);

        uint8 creatorLoyaltyFee = nft.creatorLoyalty;

        uint256 _commissionValue = _price.mul(marketOperationsFeePercent).div(
            100
        );
        uint256 _loyaltyValue = _price.mul(creatorLoyaltyFee).div(100);
        uint256 _sellerValue = (_price.sub(_commissionValue)).sub(
            _loyaltyValue
        );

        _owner.transfer(_sellerValue);
        payable(adminFeeAddress).transfer(_commissionValue);
        payable(_creator).transfer(_loyaltyValue);
        ILazyCollection(tokenAddr).justTransfer(_owner, _buyer, _id);

        // If buyer sent more than price, we send them back their rest of funds
        if (msg.value > _price) {
            _buyer.transfer(msg.value - _price);
        }
        collecFactory.setCollectionNft(nft);
    }

    function _trade(
        address _tokenAddr,
        uint256 _id,
        uint256 _price,
        address lastBidder
    ) internal {
        address paymentToken = WETH;

        ILazyCollectionFactory.CollectionNFT memory nft = collecFactory
            .getCollectionNFT(_tokenAddr, _id);
        address payable _owner = payable(IERC721(_tokenAddr).ownerOf(_id));
        address payable _buyer = payable(lastBidder);
        address payable _creator = payable(nft.creator);

        uint8 creatorLoyaltyFee = nft.creatorLoyalty;

        uint256 _commissionValue = _price.mul(marketOperationsFeePercent).div(
            100
        );
        uint256 _loyaltyValue = _price.mul(creatorLoyaltyFee).div(100);
        uint256 _sellerValue = (_price.sub(_commissionValue)).sub(
            _loyaltyValue
        );
        ILazyCollection(_tokenAddr).justTransfer(_owner, _buyer, _id);

        IWETH(paymentToken).transfer(_owner, _sellerValue);
        IWETH(paymentToken).transfer(adminFeeAddress, _commissionValue);
        IWETH(paymentToken).transfer(_creator, _loyaltyValue);
    }

    /**
     * @dev Burn a NFT token. Callable by owner only.
     */
    function burn(
        address sender,
        address _tokenAddress,
        uint256 _tokenId
    )
        external
        _validateTokenOwner(sender, _tokenAddress, _tokenId, false)
        onlyOperations
    {
        ILazyCollection(_tokenAddress).justBurn(_tokenId);
    }
}
