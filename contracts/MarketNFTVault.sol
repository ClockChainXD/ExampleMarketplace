// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/utils/Context.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@openzeppelin/contracts/utils/Counters.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "@openzeppelin/contracts/utils/Address.sol";

import "@openzeppelin/contracts/utils/Strings.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

// File: @openzeppelin/contracts/introspection/IERC165.sol

// File: @openzeppelin/contracts/token/ERC721/IERC721.sol

// File: @openzeppelin/contracts/token/ERC721/IERC721Metadata.sol

// File: @openzeppelin/contracts/token/ERC721/IERC721Enumerable.sol

// File: @openzeppelin/contracts/token/ERC721/IERC721Receiver.sol

// File: @openzeppelin/contracts/introspection/ERC165.sol

// File: @openzeppelin/contracts/utils/Address.sol

// File: @openzeppelin/contracts/utils/EnumerableSet.sol

// File: @openzeppelin/contracts/utils/EnumerableMap.sol

interface IWETH {
    function deposit() external payable;

    function withdraw(uint256 wad) external;

    function transfer(address to, uint256 value) external returns (bool);
}

// File: @openzeppelin/contracts/utils/Strings.sol

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

    function getAcceptedPaymentMethod(uint256 _tokenId)
        external
        view
        returns (address);

    function setAcceptedPaymentMethod(address paymentAddress, uint256 _tokenId)
        external;

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

    function getisWhiteListed(address) external view returns (bool);

    function setisWhiteListed(address _user, bool status) external;

    function justTransfer(
        address from,
        address to,
        uint256 _id
    ) external;

    function justBurn(uint256 _id) external;

    function mint(
        address owner,
        string memory _tokenURI,
        uint8 _loyaltyfee
    ) external returns (uint256);
}

pragma experimental ABIEncoderV2;
pragma solidity >=0.8.0;

contract MarketNFTVault is ERC721URIStorage, Ownable, IMarketNFTVault {
    using Counters for Counters.Counter;
    using Address for address;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    address public adminFeeAddress;
    uint8 public feePercent = 2;
    mapping(address => bool) private contractForAccess;
    // fee's of tokenId's
    mapping(uint256 => uint8) private loyaltyFee;
    // status of a Nft Token
    mapping(uint256 => uint8) public status;

    //deadline respect to tokenId
    mapping(uint256 => uint256) private deadlines;

    mapping(uint256 => address) private creatorArtist;
    // minBidIncrease for every tokenId
    mapping(uint256 => uint8) private minBidIncrease;
    // accepted payment method as erc20 address (weth or wbnb currently)
    mapping(uint256 => address) private acceptedPaymentMethod;
    mapping(uint256 => uint256) private price;
    // Map the number of tokens per nftId
    mapping(uint256 => uint256) private nftCount;

    // Map the number of tokens burnt per nftId
    mapping(uint256 => uint256) private nftBurnCount;

    // Used for generating the tokenId of new NFT minted
    Counters.Counter private _tokenIds;

    // Map the nftId for each tokenId
    mapping(uint256 => uint256) private nftIds;

    Counters.Counter private _nftIdCount;
    // Map the nftName for a tokenId (parent: nftId child: tokenId)
    mapping(uint256 => string) private nftNames;

    mapping(uint256 => address) private bidders;

    mapping(uint256 => uint256) private instantSellPrice;

    mapping(address => bool) private isWhiteListed;

    modifier _hasAccess() {
        require(Address.isContract(_msgSender()), "You are a person??");

        require(
            contractForAccess[_msgSender()],
            "This contract does not have access"
        );
        _;
    }

    modifier _validateTokenOwner(uint256 _tokenId, address _sender) {
        require(!Address.isContract(_sender), "You are a contract??");

        require(isWhiteListed[_sender] != true, "YOU ARE BLACKLISTED!");
        require(
            _sender == ownerOf(_tokenId) || (_sender == owner()),
            "This is not the owner"
        );
        require(_exists(_tokenId), "Error,tokenId does not exist");
        _;
    }

    modifier _validateBuyer(uint256 _tokenId, address _sender) {
        require(!Address.isContract(_sender), "You are a contract??");

        require(isWhiteListed[_sender] != true, "YOU ARE BLACKLISTED!");
        require(_exists(_tokenId), "Error, wrong tokenId");
        require(_sender != ownerOf(_tokenId), "Can not buy what you own");
        require(
            contractForAccess[_msgSender()],
            "This contract does not have access"
        );
        _;
    }
    modifier _validateOfferer(
        uint256 _tokenId,
        uint256 _offer,
        address _sender
    ) {
        require(!Address.isContract(_sender), "You are a contract??");
        require(isWhiteListed[_sender] != true, "YOU ARE BLACKLISTED!");
        require(_exists(_tokenId), "Error, wrong tokenId");
        require(_sender != ownerOf(_tokenId), "Can not buy what you own");
        require(
            (_offer >
                price[_tokenId] +
                    (price[_tokenId] * minBidIncrease[_tokenId]) /
                    100) ||
                (bidders[_tokenId] == address(0) && _offer <= price[_tokenId]),
            "This offer is lower than minimum offer value, (maybe someone offered a bigger price just before you) "
        );
        require(status[_tokenId] == 3, "This token is not on auction");
        require(
            contractForAccess[_msgSender()],
            "This contract does not have access"
        );
        _;
    }

    constructor() ERC721("LEXITNFT", "LEXIT") {
        //    _setBaseURI(_baseURI);
        adminFeeAddress = _msgSender();
        _tokenIds.increment();
    }

    function getAcceptedPaymentMethod(uint256 _tokenId)
        external
        view
        override
        returns (address)
    {
        return acceptedPaymentMethod[_tokenId];
    }

    function setAcceptedPaymentMethod(address paymentMethod, uint256 _tokenId)
        external
        override
        _hasAccess
    {
        acceptedPaymentMethod[_tokenId] = paymentMethod;
    }

    function validateTokenOwner(uint256 _tokenId, address _sender)
        external
        view
        override
        _validateTokenOwner(_tokenId, _sender)
        returns (bool)
    {
        return true;
    }

    function validateBuyer(uint256 _tokenId, address _sender)
        external
        view
        override
        _validateBuyer(_tokenId, _sender)
        returns (bool)
    {
        return true;
    }

    function validateOfferer(
        uint256 _tokenId,
        uint256 _offer,
        address _sender
    )
        external
        view
        override
        _validateOfferer(_tokenId, _offer, _sender)
        returns (bool)
    {
        return true;
    }

    function justTransfer(
        address from,
        address to,
        uint256 _id
    ) external override _hasAccess {
        _transfer(from, to, _id);
    }

    function justBurn(uint256 _id) external override _hasAccess {
        _burn(_id);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        require(status[tokenId] == 0, "Youcan'ttransferlistedNFT");
    }

    function getDeadline(uint256 _id) external view override returns (uint256) {
        return deadlines[_id];
    }

    function setDeadline(uint256 _id, uint256 _dl)
        external
        override
        _hasAccess
    {
        deadlines[_id] = _dl;
    }

    /*
     * 0=Not on Sale Nor On Auction
     * 1=On Auction
     * 2=On justSell
     */

    function getStatus(uint256 _id) external view override returns (uint8) {
        return status[_id];
    }

    function setStatus(uint256 _id, uint8 _status)
        external
        override
        _hasAccess
    {
        status[_id] = _status;
    }

    function getCreatorArtist(uint256 _id)
        external
        view
        override
        returns (address)
    {
        return creatorArtist[_id];
    }

    function setCreatorArtist(uint256 _id, address _adres)
        external
        override
        _hasAccess
    {
        creatorArtist[_id] = _adres;
    }

    function getminBidIncrease(uint256 _id)
        external
        view
        override
        returns (uint8)
    {
        return minBidIncrease[_id];
    }

    function setMinBidIncrease(uint256 _id, uint8 _minbid)
        external
        override
        _hasAccess
    {
        minBidIncrease[_id] = _minbid;
    }

    function getContractForAccess(address _conthash)
        external
        view
        override
        returns (bool)
    {
        return contractForAccess[_conthash];
    }

    function setContractForAccess(address _conthash, bool _status)
        external
        override
        onlyOwner
    {
        contractForAccess[_conthash] = _status;
    }

    function getBidders(uint256 _id) external view override returns (address) {
        return bidders[_id];
    }

    function setBidders(uint256 _id, address _bidder)
        external
        override
        _hasAccess
    {
        bidders[_id] = _bidder;
    }

    function getPrice(uint256 _id) external view override returns (uint256) {
        return price[_id];
    }

    function setPrice(uint256 _id, uint256 _newprice)
        external
        override
        _hasAccess
    {
        price[_id] = _newprice;
    }

    function getInstantSellPrice(uint256 _id)
        external
        view
        override
        returns (uint256)
    {
        return instantSellPrice[_id];
    }

    function setInstantSellPrice(uint256 _id, uint256 _newprice)
        external
        override
        _hasAccess
    {
        instantSellPrice[_id] = _newprice;
    }

    /**
     * @dev Get nftId for a specific tokenId.
     */
    function getNftId(uint256 _tokenId)
        external
        view
        override
        returns (uint256)
    {
        return nftIds[_tokenId];
    }

    function getloyaltyFee(uint256 _id) external view override returns (uint8) {
        return loyaltyFee[_id];
    }

    /**
     * @dev Get the associated nftName for a specific nftId.
     */
    function getNftName(uint256 _nftId)
        external
        view
        override
        returns (string memory)
    {
        return nftNames[_nftId];
    }

    /**
     * @dev Get the associated nftName for a unique tokenId.
     */
    function getNftNameOfTokenId(uint256 _tokenId)
        external
        view
        override
        returns (string memory)
    {
        uint256 nftId = nftIds[_tokenId];
        return nftNames[nftId];
    }

    function getNftCount(uint256 _tokenId)
        external
        view
        override
        returns (uint256)
    {
        return nftCount[_tokenId];
    }

    function setNftCount(uint256 _tokenId, uint256 _count)
        external
        override
        _hasAccess
    {
        nftCount[_tokenId] = _count;
    }

    function getNftBurntCount(uint256 _tokenId)
        external
        view
        override
        returns (uint256)
    {
        return nftBurnCount[_tokenId];
    }

    function setNftBurntCount(uint256 _tokenId, uint256 _count)
        external
        override
        _hasAccess
    {
        nftBurnCount[_tokenId] = _count;
    }

    function getisWhiteListed(address _user)
        external
        view
        override
        returns (bool)
    {
        return isWhiteListed[_user];
    }

    function setisWhiteListed(address _user, bool _status)
        external
        override
        onlyOwner
    {
        isWhiteListed[_user] = _status;
    }

    /**
     * @dev Mint NFTs. Only the owner can call it.
     */
    function mint(
        address owner,
        string memory _tokenURI,
        uint8 _loyaltyfee
    ) external override _hasAccess returns (uint256) {
        uint256 _nftId = _nftIdCount.current();

        uint256 newId = _tokenIds.current();
        _tokenIds.increment();

        nftIds[newId] = _nftId;
        nftCount[_nftId] = nftCount[_nftId].add(1);
        _safeMint(owner, newId);
        _setTokenURI(newId, _tokenURI);
        loyaltyFee[newId] = _loyaltyfee;
        status[newId] = 0;
        creatorArtist[newId] = owner;
        return newId;
    }

    /**
     * @dev Set a unique name for each nftId. It is supposed to be called once.
     */
    function setNftName(uint256 _nftId, string memory _name)
        external
        override
        _validateTokenOwner(_nftId, _msgSender())
    {
        require(_exists(_nftId), "Error, wrong nftId");
        require(_msgSender() == ownerOf(_nftId), "Only Owner Can set the name");

        nftNames[_nftId] = _name;
    }

    function getFeePercent() external view override returns (uint8) {
        return feePercent;
    }

    function setFee(address _feeAddress, uint8 _feePercent)
        external
        override
        onlyOwner
    {
        adminFeeAddress = _feeAddress;
        feePercent = _feePercent;
    }
}
