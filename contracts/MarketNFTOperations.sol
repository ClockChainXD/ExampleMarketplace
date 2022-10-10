// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/utils/Context.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@openzeppelin/contracts/utils/Counters.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "@openzeppelin/contracts/utils/Address.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
pragma solidity ^0.8.4;

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

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false

interface ILazyCollectionFactory {
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
}

interface ICollectionOperations {
    function justSell(
        address sender,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 price
    ) external;

    function buy(
        address sender,
        address _tokenAddress,
        uint256 _tokenId
    ) external payable returns (uint256);

    function updatePriceAsOwner(
        address sender,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _price
    ) external returns (uint256);

    function cancelAuctionOrSale(
        address sender,
        address _tokenAddress,
        uint256 _tokenId
    ) external;

    function createAuction(
        address sender,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _price,
        uint8 _minBidIncreasePercent,
        uint256 _instantBuyPrice
    ) external;

    function createDeadlineAuction(
        address sender,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _price,
        uint8 _minBidIncreasePercent,
        uint256 _deadline,
        uint256 _instantBuyPrice
    ) external;

    function makeOffer(
        address sender,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _offer
    ) external;

    function acceptOffer(
        address sender,
        address _tokenAddress,
        uint256 _id
    )
        external
        returns (
            address _owner,
            address _lastBidder,
            uint256 _lastPrice,
            address tokenAddress,
            uint256 id
        );

    function buyFromApprovedOffer(
        address _sender,
        ILazyCollectionFactory.CollectionNFT calldata nft
    ) external;
}

interface IMarketNFTVault {
    function validateTokenOwner(uint256 _tokenId, address _sender)
        external
        view
        returns (bool);

    function validateBuyer(uint256 _tokenId, address _sender)
        external
        view
        returns (bool);

    function validateOfferer(
        uint256 _tokenId,
        uint256 _offer,
        address _sender
    ) external view returns (bool);

    function getFeePercent() external view returns (uint8);

    function getDeadline(uint256 _id) external view returns (uint256);

    function setDeadline(uint256 _id, uint256 _dl) external;

    function getStatus(uint256 _id) external view returns (uint8);

    function getCreatorArtist(uint256 _id) external view returns (address);

    function setCreatorArtist(uint256 _id, address _adres) external;

    function getminBidIncrease(uint256 _id) external view returns (uint8);

    function setMinBidIncrease(uint256 _id, uint8 _minbid) external;

    function getContractForAccess(address _conthash)
        external
        view
        returns (bool);

    function setContractForAccess(address _conthash, bool status) external;

    function getBidders(uint256 _id) external view returns (address);

    function setBidders(uint256 _id, address _bidder) external;

    function getPrice(uint256 _id) external view returns (uint256);

    function setPrice(uint256 _id, uint256 _newprice) external;

    function getInstantSellPrice(uint256 _id) external view returns (uint256);

    function setInstantSellPrice(uint256 _id, uint256 _newprice) external;

    function getNftId(uint256 _tokenId) external view returns (uint256);

    function getloyaltyFee(uint256 _id) external view returns (uint8);

    function getNftName(uint256 _nftId) external view returns (string memory);

    function getNftNameOfTokenId(uint256 _tokenId)
        external
        view
        returns (string memory);

    function setNftName(uint256 _nftId, string memory _name) external;

    function setFee(address _feeAddress, uint8 _feePercent) external;

    function getNftCount(uint256 _nftId) external view returns (uint256);

    function setNftCount(uint256 _tokenId, uint256 _count) external;

    function getNftBurntCount(uint256 _tokenId) external view returns (uint256);

    function setNftBurntCount(uint256 _tokenId, uint256 _count) external;

    function setStatus(uint256 _id, uint8 status) external;

    function justTransfer(
        address from,
        address to,
        uint256 _id
    ) external;

    function mint(
        address to,
        string memory _tokenURI,
        uint8 _loyaltyfee
    ) external returns (uint256);
}

pragma solidity ^0.8.4;

contract MarketNFTOperations is Ownable, EIP712 {
    using Counters for Counters.Counter;
    using Address for address;
    using SafeMath for uint256;
    using ECDSA for bytes32;

    address public MarketNFTVault;
    address public adminFeeAddress;
    address public collectionOperations;

    /// This is WETH or WBNB they have the same interface so no problem there.
    address public WETH;
    ICollectionOperations private collectionOps;

    event JustPurchased(
        address indexed previousOwner,
        address indexed newOwner,
        uint256 price,
        address _tokenAddress,
        uint256 tokenID
    );
    event JustInstantPurchased(
        address indexed previousOwner,
        address indexed newOwner,
        uint256 price,
        address _tokenAddress,
        uint256 tokenID
    );
    event AuctionCancelled(
        address indexed owner,
        address indexed _tokenAddress,
        uint256 nftID
    );
    event AuctionEnded(
        address indexed previousOwner,
        address indexed newOwner,
        uint256 price,
        address _tokenAddress,
        uint256 tokenID
    );
    event PriceUpdated(
        address indexed owner,
        uint256 oldPrice,
        uint256 newPrice,
        uint256 tokenID,
        address indexed tokenAddress
    );
    event AuctionStarted(
        address indexed owner,
        address indexed _tokenAddr,
        uint256 tokenID,
        uint256 openingPrice,
        uint8 minimumBidOfferIncreasePercent,
        uint256 instantBuyPrice
    );
    event AuctionWithDeadlineStarted(
        address indexed owner,
        address indexed _tokenAddr,
        uint256 tokenID,
        uint256 openingPrice,
        uint8 minimumBidOfferIncreasePercent,
        uint256 deadline,
        uint256 instantBuyPrice
    );
    event MadeOffer(
        address indexed owner,
        address indexed _tokenAddress,
        uint256 tokenID,
        uint256 price
    );
    event LazyMint(
        address indexed owner,
        uint256 tokenID,
        string tokenUri,
        uint8 loyaltyFee
    );

    event Mint(
        address indexed owner,
        uint256 tokenID,
        string tokenUri,
        uint8 loyaltyFee
    );

    event JustListedToSell(
        address indexed owner,
        address indexed tokenAddress,
        uint256 tokenId,
        uint256 price
    );
    event PurchasedFromOffer(
        address newOwner,
        address oldOwner,
        address _tokenAddress,
        uint256 tokenID,
        uint256 price
    );

    modifier _validateTokenOwner(address tokenAddress, uint256 _tokenId) {
        address _sender = msg.sender;
        if (tokenAddress == MarketNFTVault) {
            require(
                IMarketNFTVault(MarketNFTVault).validateTokenOwner(
                    _tokenId,
                    _sender
                ),
                "Validation failed"
            );
        }
        _;
    }

    modifier _validateBuyer(address tokenAddress, uint256 _tokenId) {
        if (tokenAddress == MarketNFTVault) {
            require(
                msg.value >= IMarketNFTVault(MarketNFTVault).getPrice(_tokenId),
                "Error, the amount is lower"
            );

            require(
                IMarketNFTVault(MarketNFTVault).validateBuyer(
                    _tokenId,
                    _msgSender()
                ),
                "Validation failed"
            );
        }

        _;
    }

    modifier checkBuyer(uint256 _price) {
        require(msg.value >= _price, " INSUFICIENT FUNDS");
        require(!Address.isContract(msg.sender), " You are a contract!!");
        _;
    }

    modifier checkApprovedBuyer(uint256 _price) {
        require(msg.value >= _price, " INSUFICIENT FUNDS");
        require(!Address.isContract(msg.sender), " You are a contract!!");
        _;
    }

    modifier _validateOfferer(
        address _tokenAddr,
        uint256 _tokenId,
        uint256 _offer
    ) {
        address _sender = _msgSender();
        if (_tokenAddr == MarketNFTVault)
            require(
                IMarketNFTVault(MarketNFTVault).validateOfferer(
                    _tokenId,
                    _offer,
                    _sender
                ),
                "Validation failed"
            );

        _;
    }

    /// put WETH or WBNB they have the same interface so no problem there. Just put the right address on deploy
    constructor(
        address _weth,
        address _vault,
        address _adminFeeAddress,
        address _collectionOperations
    ) EIP712("LEXITNFT", "1") {
        WETH = _weth;
        adminFeeAddress = _adminFeeAddress;
        MarketNFTVault = _vault;
        collectionOperations = _collectionOperations;
        collectionOps = ICollectionOperations(_collectionOperations);
    }

    function isValidInput(bytes32 _digestH, bytes memory _signature)
        public
        pure
        returns (address)
    {
        //  return msg.sender == ECDSA.recover(_digestH, _signature);

        return _digestH.toEthSignedMessageHash().recover(_signature);
    }

    /// this is for the hardhat
    function _verifyApprovedBuy(
        ILazyCollectionFactory.CollectionNFT calldata _nft,
        bytes32 _digestH,
        bytes memory signature
    ) public pure returns (address) {
        address signeraddress = _digestH.toEthSignedMessageHash().recover(
            signature
        );
        /*
        For the mainnet deployment:  
          bytes32 digest = _approveOfferHash(_nft);
        address eip712Signer=ECDSA.recover(digest, signature);
        return eip712Signer;
        */
        return signeraddress;
    }

    /// @notice Returns a hash of the given VirtualCollection, prepared using EIP712 typed data hashing rules.
    /// @param nft An VirtualNFT to hash.
    function _approveOfferHash(
        ILazyCollectionFactory.CollectionNFT calldata nft
    ) public view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "CollectionNFT(address creator,address owner,uint256 price,uint256 _tokenId,address _tokenAddress,string tokenURI,uint8 creatorLoyalty, address approvedOfferer,uint256 nonce)"
                        ),
                        nft.creator,
                        nft.owner,
                        nft.price,
                        nft._tokenId,
                        nft._tokenAddress,
                        keccak256(abi.encodePacked(nft.tokenURI)),
                        nft.creatorLoyalty,
                        nft.approvedOfferer,
                        nft.nonce
                    )
                )
            );
    }

    /*
     * 0=Not on Sale Nor On Auction
     * 1=On Auction
     * 2=On justSell
     */

    /// @dev Single nft mint
    /// @param _tokenURI URL of the nft metadata
    /// @param _loyaltyfee loyaltyFee
    function _mint(string memory _tokenURI, uint8 _loyaltyfee) external {
        uint256 _val = IMarketNFTVault(MarketNFTVault).mint(
            msg.sender,
            _tokenURI,
            _loyaltyfee
        );

        emit Mint(_msgSender(), _val, _tokenURI, _loyaltyfee);
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param _tokenURI URL of the nft metadata
    /// @param _loyaltyfee loyaltyFee
    /// @param price price of the nft as native currency
    function mintAndSell(
        string memory _tokenURI,
        uint8 _loyaltyfee,
        uint256 price
    ) external returns (uint256) {
        uint256 _tokenId = IMarketNFTVault(MarketNFTVault).mint(
            msg.sender,
            _tokenURI,
            _loyaltyfee
        );

        IMarketNFTVault(MarketNFTVault).setPrice(_tokenId, price);

        IMarketNFTVault(MarketNFTVault).setStatus(_tokenId, 1);
        emit Mint(_msgSender(), _tokenId, _tokenURI, _loyaltyfee);
        emit JustListedToSell(_msgSender(), MarketNFTVault, _tokenId, price);
        return _tokenId;
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param _tokenURI URL of the nft metadata
    /// @param _loyaltyfee loyaltyFee
    /// @param _price start price of the nft
    /// @param _minBidIncreasePercent price of the nft as native currency
    /// @param _instantBuyPrice instant buy price
    /// @param _deadline deadline of the auction but careful it is with seconds so different than unix date time. Don't give milliseconds to this
    function mintAndCreateAuction(
        string memory _tokenURI,
        uint8 _loyaltyfee,
        uint256 _price,
        uint8 _minBidIncreasePercent,
        uint256 _instantBuyPrice,
        uint256 _deadline
    ) external {
        uint256 _tokenId = IMarketNFTVault(MarketNFTVault).mint(
            msg.sender,
            _tokenURI,
            _loyaltyfee
        );

        emit Mint(_msgSender(), _tokenId, _tokenURI, _loyaltyfee);
        createDeadlineAuction(
            MarketNFTVault,
            _tokenId,
            _price,
            _minBidIncreasePercent,
            _deadline,
            _instantBuyPrice
        );
        emit AuctionWithDeadlineStarted(
            _msgSender(),
            MarketNFTVault,
            _tokenId,
            _price,
            _minBidIncreasePercent,
            _deadline,
            _instantBuyPrice
        );
    }

    //this is lazy mint like redeem on marketlazy
    function lazyMint(
        ILazyCollectionFactory.CollectionNFT calldata _nft,
        bytes32 _digestHash,
        bytes memory _signature
    ) public payable checkBuyer(_nft.price) {
        require(
            isValidInput(_digestHash, _signature) == _nft.creator,
            "Input is not Valid"
        );

        uint256 _val = IMarketNFTVault(MarketNFTVault).mint(
            _nft.creator,
            _nft.tokenURI,
            _nft.creatorLoyalty
        );

        payable(_nft.creator).transfer(msg.value);
        IMarketNFTVault(MarketNFTVault).justTransfer(
            _nft.creator,
            msg.sender,
            _val
        );

        emit LazyMint(_msgSender(), _val, _nft.tokenURI, _nft.creatorLoyalty);
    }

    //this is actually like the lazy mint but this time we are not minting just let the offerer buy it
    function buyFromApprovedOffer(
        ILazyCollectionFactory.CollectionNFT calldata _nft,
        bytes32 _digestH,
        bytes memory _signature
    ) public payable checkApprovedBuyer(_nft.price) {
        require(
            _verifyApprovedBuy(_nft, _digestH, _signature) ==
                IERC721(_nft._tokenAddress).ownerOf(_nft._tokenId),
            "This signature is fake"
        );
        require(_nft.approvedOfferer == msg.sender, "You are not the offerer");
        if (_nft._tokenAddress == MarketNFTVault) {
            require(
                IMarketNFTVault(MarketNFTVault).getStatus(_nft._tokenId) == 0,
                "You can't do this while on list"
            );

            IWETH(WETH).deposit{value: _nft.price}();
            if (msg.value > _nft.price) {
                payable(msg.sender).transfer(msg.value - _nft.price);
            }
            IMarketNFTVault(MarketNFTVault).setStatus(_nft._tokenId, 0);
            _trade(_nft._tokenId, _nft.price, msg.sender);
        } else {
            IWETH(WETH).deposit{value: _nft.price}();
            if (msg.value > _nft.price) {
                payable(msg.sender).transfer(msg.value - _nft.price);
            }
            IWETH(WETH).approve(collectionOperations, _nft.price);
            ICollectionOperations(collectionOperations).buyFromApprovedOffer(
                msg.sender,
                _nft
            );
        }
        emit PurchasedFromOffer(
            msg.sender,
            _nft.owner,
            _nft._tokenAddress,
            _nft._tokenId,
            _nft.price
        );
    }

    function justSell(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 price
    ) external _validateTokenOwner(_tokenAddress, _tokenId) {
        if (_tokenAddress == MarketNFTVault) {
            require(
                IMarketNFTVault(MarketNFTVault).getStatus(_tokenId) == 0,
                "It is already listed or in auction"
            );

            IMarketNFTVault(MarketNFTVault).setPrice(_tokenId, price);

            IMarketNFTVault(MarketNFTVault).setStatus(_tokenId, 1);

            emit JustListedToSell(_msgSender(), _tokenAddress, _tokenId, price);
        } else {
            collectionOps.justSell(msg.sender, _tokenAddress, _tokenId, price);
            emit JustListedToSell(_msgSender(), _tokenAddress, _tokenId, price);
        }
    }

    // This function is for buying from justSell option or instant buyer!
    function buy(address _tokenAddress, uint256 _tokenId)
        external
        payable
        _validateBuyer(_tokenAddress, _tokenId)
    {
        if (_tokenAddress == MarketNFTVault) {
            require(
                IMarketNFTVault(MarketNFTVault).getStatus(_tokenId) == 1 ||
                    (IMarketNFTVault(MarketNFTVault).getInstantSellPrice(
                        _tokenId
                    ) >
                        0 &&
                        ((IMarketNFTVault(MarketNFTVault).getStatus(_tokenId) ==
                            2) ||
                            IMarketNFTVault(MarketNFTVault).getStatus(
                                _tokenId
                            ) ==
                            3)),
                "You can't buy. This token is on Auction."
            );
            address _sellerman = IERC721(MarketNFTVault).ownerOf(_tokenId);
            address _buyerman = _msgSender();
            uint256 instPrice = IMarketNFTVault(MarketNFTVault)
                .getInstantSellPrice(_tokenId);
            uint256 nprice = IMarketNFTVault(MarketNFTVault).getPrice(_tokenId);
            IMarketNFTVault(MarketNFTVault).setStatus(_tokenId, 0);
            _justTrade(_tokenAddress, _tokenId);
            if (instPrice > 0) {
                address payable prevBidder = payable(
                    IMarketNFTVault(MarketNFTVault).getBidders(_tokenId)
                );
                if (prevBidder != address(0)) {
                    IWETH(WETH).transfer(prevBidder, nprice);
                }
                IMarketNFTVault(MarketNFTVault).setInstantSellPrice(
                    _tokenId,
                    0
                );
                IMarketNFTVault(MarketNFTVault).setBidders(
                    _tokenId,
                    address(0)
                );
                emit JustInstantPurchased(
                    _sellerman,
                    _buyerman,
                    instPrice,
                    _tokenAddress,
                    _tokenId
                );
            } else {
                emit JustPurchased(
                    _sellerman,
                    _buyerman,
                    IMarketNFTVault(MarketNFTVault).getPrice(_tokenId),
                    _tokenAddress,
                    _tokenId
                );
            }
        } else {
            address sellerman = IERC721(_tokenAddress).ownerOf(_tokenId);
            uint256 _price = ICollectionOperations(collectionOperations).buy{
                value: msg.value
            }(msg.sender, _tokenAddress, _tokenId);

            emit JustPurchased(
                sellerman,
                msg.sender,
                _price,
                _tokenAddress,
                _tokenId
            );
        }
    }

    // function instantBuy()
    // Increasing the price of auctioned nft
    function increaseBid(uint256 _tokenId, uint256 _price)
        internal
        returns (uint256)
    {
        uint256 oldPrice = IMarketNFTVault(MarketNFTVault).getPrice(_tokenId);
        IMarketNFTVault(MarketNFTVault).setPrice(_tokenId, _price);

        return oldPrice;
    }

    function updatePriceAsOwner(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _price
    ) external _validateTokenOwner(_tokenAddress, _tokenId) {
        if (_tokenAddress == MarketNFTVault) {
            uint256 oldPrice = IMarketNFTVault(MarketNFTVault).getPrice(
                _tokenId
            );
            IMarketNFTVault(MarketNFTVault).setPrice(_tokenId, _price);
            emit PriceUpdated(
                _msgSender(),
                oldPrice,
                _price,
                _tokenId,
                _tokenAddress
            );
        } else {
            uint256 oldPrice = collectionOps.updatePriceAsOwner(
                msg.sender,
                _tokenAddress,
                _tokenId,
                _price
            );
            emit PriceUpdated(
                _msgSender(),
                oldPrice,
                _price,
                _tokenId,
                _tokenAddress
            );
        }
    }

    // Only owner of token can use this function
    function cancelAuctionOrSale(address _tokenAddress, uint256 _tokenId)
        external
        _validateTokenOwner(_tokenAddress, _tokenId)
    {
        if (_tokenAddress == MarketNFTVault) {
            if (_msgSender() != Ownable(MarketNFTVault).owner()) {
                require(
                    IMarketNFTVault(MarketNFTVault).getBidders(_tokenId) ==
                        address(0),
                    "You can't cancel when you have bidders"
                );
            }
            address payable prevBidder = payable(
                IMarketNFTVault(MarketNFTVault).getBidders(_tokenId)
            );
            IMarketNFTVault(MarketNFTVault).setBidders(_tokenId, address(0));
            uint256 _prevPrice = IMarketNFTVault(MarketNFTVault).getPrice(
                _tokenId
            );
            IMarketNFTVault(MarketNFTVault).setPrice(_tokenId, 0);
            require(
                IMarketNFTVault(MarketNFTVault).getStatus(_tokenId) > 0,
                "This token is not on an auction or on sale"
            );
            uint8 state = IMarketNFTVault(MarketNFTVault).getStatus(_tokenId);
            IMarketNFTVault(MarketNFTVault).setStatus(_tokenId, 0);

            if (state == 3) {
                if (
                    IMarketNFTVault(MarketNFTVault).getDeadline(_tokenId) != 0
                ) {
                    IMarketNFTVault(MarketNFTVault).setDeadline(_tokenId, 0);
                }

                if (prevBidder != address(0)) {
                    IWETH(WETH).transfer(prevBidder, _prevPrice);
                }

                IMarketNFTVault(MarketNFTVault).setInstantSellPrice(
                    _tokenId,
                    0
                );
                IMarketNFTVault(MarketNFTVault).setMinBidIncrease(_tokenId, 0);
            }

            emit AuctionCancelled(_msgSender(), _tokenAddress, _tokenId);
        } else {
            collectionOps.cancelAuctionOrSale(
                msg.sender,
                _tokenAddress,
                _tokenId
            );
            emit AuctionCancelled(_msgSender(), _tokenAddress, _tokenId);
        }
    }

    //Time respect to seconds
    function createDeadlineAuction(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _price,
        uint8 _minBidIncreasePercent,
        uint256 _deadline,
        uint256 _instantBuyPrice
    ) public _validateTokenOwner(_tokenAddress, _tokenId) {
        if (MarketNFTVault == _tokenAddress) {
            require(
                IMarketNFTVault(MarketNFTVault).getStatus(_tokenId) != 3,
                "This item is on auction already"
            );
            require(
                IMarketNFTVault(MarketNFTVault).getDeadline(_tokenId) == 0,
                "This item already has a deadline"
            );

            IMarketNFTVault(MarketNFTVault).setMinBidIncrease(
                _tokenId,
                _minBidIncreasePercent
            );
            IMarketNFTVault(MarketNFTVault).setStatus(_tokenId, 3);
            if (_instantBuyPrice > 0) {
                IMarketNFTVault(MarketNFTVault).setInstantSellPrice(
                    _tokenId,
                    _price
                );
            }

            IMarketNFTVault(MarketNFTVault).setPrice(_tokenId, _price);
            uint256 deadline = _deadline;
            IMarketNFTVault(MarketNFTVault).setDeadline(_tokenId, deadline);
        } else {
            collectionOps.createDeadlineAuction(
                msg.sender,
                _tokenAddress,
                _tokenId,
                _price,
                _minBidIncreasePercent,
                _deadline,
                _instantBuyPrice
            );
        }

        emit AuctionWithDeadlineStarted(
            _msgSender(),
            _tokenAddress,
            _tokenId,
            _price,
            _minBidIncreasePercent,
            _deadline,
            _instantBuyPrice
        );
    }

    function makeOffer(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _offer
    ) external payable _validateOfferer(_tokenAddress, _tokenId, _offer) {
        if (_tokenAddress == MarketNFTVault) {
            if (IMarketNFTVault(MarketNFTVault).getDeadline(_tokenId) != 0) {
                require(
                    IMarketNFTVault(MarketNFTVault).getDeadline(_tokenId) >=
                        block.timestamp,
                    "Auction reached to the deadline :/ "
                );
            }
            //  IWETH(WETH).approve(address(this), _offer);
            address prevBidder = IMarketNFTVault(MarketNFTVault).getBidders(
                _tokenId
            );
            uint256 _prevPrice = IMarketNFTVault(MarketNFTVault).getPrice(
                _tokenId
            );
            IMarketNFTVault(MarketNFTVault).setBidders(_tokenId, _msgSender());

            if (prevBidder != address(0)) {
                IWETH(WETH).transfer(prevBidder, _prevPrice);
            }
            IWETH(WETH).deposit{value: _offer}();
            if (msg.value > _offer) {
                payable(msg.sender).transfer(msg.value - _offer);
            }

            increaseBid(_tokenId, _offer);
        } else {
            IWETH(WETH).deposit{value: _offer}();
            if (msg.value > _offer) {
                payable(msg.sender).transfer(msg.value - _offer);
            }

            IWETH(WETH).approve(collectionOperations, _offer);

            collectionOps.makeOffer(
                msg.sender,
                _tokenAddress,
                _tokenId,
                _offer
            );
        }
        emit MadeOffer(_msgSender(), _tokenAddress, _tokenId, _offer);
    }

    function acceptOffer(address _tokenAddress, uint256 _id)
        external
        _validateTokenOwner(_tokenAddress, _id)
    {
        if (_tokenAddress == MarketNFTVault) {
            require(
                IMarketNFTVault(MarketNFTVault).getStatus(_id) == 3,
                "This token is not on an Auction"
            );
            IMarketNFTVault(MarketNFTVault).setStatus(_id, 0);

            require(
                IMarketNFTVault(MarketNFTVault).getBidders(_id) != address(0),
                "There are no offers to claim!"
            );
            address _lastBidder = IMarketNFTVault(MarketNFTVault).getBidders(
                _id
            );
            IMarketNFTVault(MarketNFTVault).setBidders(_id, address(0));
            address payable _owner = payable(
                IERC721(MarketNFTVault).ownerOf(_id)
            );

            uint256 _lastPrice = IMarketNFTVault(MarketNFTVault).getPrice(_id);
            _trade(_id, _lastPrice, _lastBidder);
            if (IMarketNFTVault(MarketNFTVault).getInstantSellPrice(_id) > 0) {
                IMarketNFTVault(MarketNFTVault).setInstantSellPrice(_id, 0);
            }
            if (IMarketNFTVault(MarketNFTVault).getDeadline(_id) != 0) {
                IMarketNFTVault(MarketNFTVault).setDeadline(_id, 0);
            }

            emit AuctionEnded(
                _owner,
                _lastBidder,
                _lastPrice,
                _tokenAddress,
                _id
            );
        } else {
            (
                address owner,
                address lastBidder,
                uint256 lastPrice,
                address tokenAddress,
                uint256 id
            ) = collectionOps.acceptOffer(msg.sender, _tokenAddress, _id);
            emit AuctionEnded(owner, lastBidder, lastPrice, tokenAddress, id);
        }
    }

    function _justTrade(address tokenAddr, uint256 _id) internal {
        if (tokenAddr == MarketNFTVault) {
            address payable _owner = payable(IERC721(tokenAddr).ownerOf(_id));
            address payable _buyer = payable(_msgSender());
            uint256 _price = IMarketNFTVault(tokenAddr).getPrice(_id);
            uint256 instPrice = IMarketNFTVault(tokenAddr).getInstantSellPrice(
                _id
            );
            uint8 _loyaltyFee = IMarketNFTVault(tokenAddr).getloyaltyFee(_id);
            IMarketNFTVault(tokenAddr).justTransfer(_owner, _buyer, _id);
            uint8 feePercent = IMarketNFTVault(tokenAddr).getFeePercent();
            if (instPrice > 0) {
                _price = instPrice;
            }
            // Fee Cut
            uint256 _commissionValue = _price.mul(feePercent).div(100);
            uint256 _loyaltyValue = _price.mul(_loyaltyFee).div(100);
            uint256 _sellerValue = (_price.sub(_commissionValue)).sub(
                _loyaltyValue
            );
            address payable _creatorArtist = payable(
                IMarketNFTVault(MarketNFTVault).getCreatorArtist(_id)
            );

            _owner.transfer(_sellerValue);
            payable(adminFeeAddress).transfer(_commissionValue);

            if (_creatorArtist != msg.sender)
                payable(_creatorArtist).transfer(_loyaltyValue);
            // If buyer sent more than price, we send them back their rest of funds
            if (msg.value > _price) {
                _buyer.transfer(msg.value - _price);
            }
        }
    }

    function _trade(
        uint256 _id,
        uint256 _price,
        address buyer
    ) internal {
        address payable _owner = payable(IERC721(MarketNFTVault).ownerOf(_id));
        address payable _buyer = payable(buyer);
        address payable _creatorArtist = payable(
            IMarketNFTVault(MarketNFTVault).getCreatorArtist(_id)
        );

        uint8 _loyaltyFee = IMarketNFTVault(MarketNFTVault).getloyaltyFee(_id);
        uint8 feePercent = IMarketNFTVault(MarketNFTVault).getFeePercent();
        // Fee Cut
        uint256 _commissionValue = _price.mul(feePercent).div(100);
        uint256 _loyaltyValue = _price.mul(_loyaltyFee).div(100);
        uint256 _sellerValue = (_price.sub(_commissionValue)).sub(
            _loyaltyValue
        );
        IMarketNFTVault(MarketNFTVault).justTransfer(_owner, _buyer, _id);

        IWETH(WETH).transfer(_owner, _sellerValue);
        IWETH(WETH).transfer(adminFeeAddress, _commissionValue);
        if (_creatorArtist != msg.sender && _owner != msg.sender)
            IWETH(WETH).transfer(_creatorArtist, _loyaltyValue);
    }
}
