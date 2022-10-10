// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

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

interface ILazyCollectionFactory {
    function setAcceptedTokens(address nftAddress, bool status) external;

    function setRedeemed(
        uint256 tokenId,
        uint256 minPrice,
        uint8 creatorFee,
        address creator,
        address owner
    ) external;
}

contract LazyCollection is ERC721URIStorage, EIP712 {
    using ECDSA for bytes32;
    using Strings for uint256;
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    mapping(address => uint256) public pendingWithdrawals;
    mapping(address => bool) public isArtist;
    mapping(address => string) public preUnlockURI;

    Counters.Counter private _totalSupply;
    Counters.Counter private genCounter;

    address public owner;
    address public factory;
    address[] public payees;
    address public collectionAcceptedPaymentMethod;
    address private collectionOperations;
    uint8[] public shares;
    mapping(uint256 => bool) public lockedContent;

    mapping(uint256 => uint256) public genNftCounter;

    mapping(uint256 => Generations) public gens;
    uint8 public marketCut;
    string public BaseURI;
    string public baseExtension = ".json";
    event ArtistAdded(address newArtist);
    event ArtistRemoved(address oldArtist);
    event PayeesAndSharesChanged(address[] newPayeesList, uint8[] newShareList);
    event NewGenerationCreated(
        uint256 indexed id,
        string name,
        uint256 lastTokenId,
        uint256 genSupply,
        uint256 price
    );
    event PaymentSplitted(address[] guys, uint8[] shares, uint256 amount);
    modifier isOwner() {
        require(msg.sender == owner, "You are not the owner!");
        _;
    }

    modifier isFactory() {
        require(msg.sender == factory, "You are not the factory??");
        _;
    }
    modifier _IsOperator() {
        require(msg.sender == collectionOperations);
        _;
    }

    /// Generation is for representing different priced collection NFTs that redeemable.
    struct VirtualCollection {
        Generations generation;
        uint8 creatorFee;
    }
    struct Generations {
        uint256 id;
        string name;
        uint256 lastTokenId;
        uint256 price;
    }

    constructor(
        string memory name,
        string memory symbol,
        address acceptedPayment,
        uint256 initialPrice,
        uint256 initialSupply,
        address collectionOps
    ) ERC721(name, symbol) EIP712(name, "1") {
        factory = msg.sender;
        collectionAcceptedPaymentMethod = acceptedPayment;
        Generations memory newGen;
        newGen.id = 0;
        newGen.name = name;
        newGen.lastTokenId = initialSupply;
        newGen.price = initialPrice;
        gens[0] = newGen;
        _totalSupply.increment();
        genCounter.increment();
        genNftCounter[0] = genNftCounter[0] + 1;
        collectionOperations = collectionOps;
    }

    function justTransfer(
        address from,
        address to,
        uint256 _id
    ) external _IsOperator {
        _transfer(from, to, _id);
    }

    function createNewGeneration(
        string memory _name,
        uint256 genSupply,
        uint256 price
    ) external {
        require(
            owner == msg.sender || isArtist[msg.sender],
            "Signature invalid or unauthorized"
        );
        uint256 currGen = genCounter.current();
        uint256 _lastTokenId = gens[currGen - 1].lastTokenId + genSupply;
        genCounter.increment();
        Generations memory newGen;
        newGen.id = currGen;
        newGen.name = _name;
        newGen.lastTokenId = _lastTokenId;
        newGen.price = price;
        gens[currGen] = newGen;
        genNftCounter[currGen] = genNftCounter[currGen] + 1;

        emit NewGenerationCreated(
            currGen,
            _name,
            _lastTokenId,
            genSupply,
            price
        );
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return BaseURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }

    function justBurn(uint256 _tokenId) external {
        _burn(_tokenId);
    }

    function redeem(
        address redeemer,
        VirtualCollection calldata virtualNft,
        bytes32 digest,
        bytes memory signature
    ) public payable returns (uint256) {
        uint256 currid = _totalSupply.current();
        if (virtualNft.generation.id > 0) {
            require(
                genNftCounter[virtualNft.generation.id] <
                    virtualNft.generation.lastTokenId -
                        gens[virtualNft.generation.id - 1].lastTokenId,
                "Generation reached max supply"
            );
            // make sure signature is valid and get the address of the signer

            currid =
                genNftCounter[virtualNft.generation.id] +
                1 +
                gens[virtualNft.generation.id - 1].lastTokenId;
        } else {
            require(
                genNftCounter[0] < virtualNft.generation.lastTokenId,
                "Generation reached max supply"
            );

            currid = genNftCounter[0];
        }

        genNftCounter[virtualNft.generation.id] =
            genNftCounter[virtualNft.generation.id] +
            1;

        address signer = _verify(virtualNft, digest, signature);

        // make sure that the signer is authorized to mint NFTs
        require(
            owner == signer || isArtist[signer],
            "Signature invalid or unauthorized"
        );

        // make sure that the redeemer is paying enough
        require(
            IWETH(collectionAcceptedPaymentMethod).balanceOf(msg.sender) >=
                virtualNft.generation.price,
            "Insufficient funds to redeem"
        );
        IWETH(collectionAcceptedPaymentMethod).deposit{
            value: virtualNft.generation.price
        }();

        if (msg.value > virtualNft.generation.price) {
            payable(msg.sender).transfer(
                msg.value - virtualNft.generation.price
            );
        }

        // Creator and fee split length should be equal
        // first assign the token to the signer, to establish provenance on-chain
        _mint(signer, currid);
        _totalSupply.increment();

        // transfer the token to the redeemer
        _transfer(signer, redeemer, currid);
        ILazyCollectionFactory(factory).setRedeemed(
            currid,
            virtualNft.generation.price,
            virtualNft.creatorFee,
            signer,
            redeemer
        );
        uint256 collectionFirstSale = (
            virtualNft.generation.price.mul(100 - marketCut)
        ).div(100);

        // record payment to signer's custom payment split and fee to redPlatform

        splitPayment(collectionFirstSale);
        IWETH(collectionAcceptedPaymentMethod).transfer(
            factory,
            virtualNft.generation.price - collectionFirstSale
        );

        return currid;
    }

    function initialize(
        address[] memory _payees,
        uint8[] memory _shares,
        address _owner,
        uint8 _cut,
        string memory _baseUri
    ) external isFactory {
        uint8 totalShare = 100;
        for (uint8 i = 0; i < _shares.length; i++) {
            totalShare -= _shares[i];
        }
        require(
            totalShare == 0,
            "You can't make shares list more or less than 100 total"
        );
        payees = _payees;
        shares = _shares;
        owner = _owner;
        marketCut = _cut;
        BaseURI = _baseUri;
    }

    function splitPayment(uint256 amount) internal {
        address[] memory guys = payees;
        uint8[] memory _shares = shares;

        for (uint256 i = 0; i < guys.length; i++) {
            uint256 guyShare = (amount * _shares[i]) / 100;
            pendingWithdrawals[guys[i]] =
                pendingWithdrawals[guys[i]] +
                guyShare;
        }
        emit PaymentSplitted(guys, _shares, amount);
    }

    function addArtists(address[] memory newArtists) public isOwner {
        for (uint256 i = 0; i < newArtists.length; i++) {
            isArtist[newArtists[i]] = true;
            emit ArtistAdded(newArtists[i]);
        }
    }

    function removeArtists(address[] memory oldArtists) public isOwner {
        for (uint256 i = 0; i < oldArtists.length; i++) {
            isArtist[oldArtists[i]] = false;
            emit ArtistRemoved(oldArtists[i]);
        }
    }

    function changePayeesAndShares(
        address[] memory newPayeesList,
        uint8[] memory newShareList
    ) public isOwner {
        require(
            newPayeesList.length == newShareList.length,
            "CHANGING FAILED::: Share or Payees List is shorter than the other"
        );

        uint8 totalShare = 100;
        for (uint8 i = 0; i < newShareList.length; i++) {
            totalShare -= newShareList[i];
        }
        require(
            totalShare == 0,
            "You can't make shares list more or less than 100 total"
        );
        payees = newPayeesList;
        shares = newShareList;
        emit PayeesAndSharesChanged(newPayeesList, newShareList);
    }

    function withdraw() public {
        require(
            pendingWithdrawals[msg.sender] != 0,
            "You don't have any payee or not authorized"
        );

        // IMPORTANT: casting msg.sender to a payable address is only safe if ALL members of the minter role are payable addresses.
        address payable receiver = payable(msg.sender);

        uint256 amount = pendingWithdrawals[receiver];
        // zero account before transfer to prevent re-entrancy attack
        pendingWithdrawals[receiver] = 0;
        IWETH(collectionAcceptedPaymentMethod).transfer(receiver, amount);
    }

    function availableToWithdraw() public view returns (uint256) {
        return pendingWithdrawals[msg.sender];
    }

    /// @notice Returns a hash of the given VirtualCollection, prepared using EIP712 typed data hashing rules.
    /// @param virtualNft An VirtualCollection to hash.
    function _hash(VirtualCollection calldata virtualNft)
        internal
        view
        returns (bytes32)
    {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "VirtualCollection(string name,uint256 lastTokenId,uint256 price,uint8 creatorFee)"
                        ),
                        virtualNft.generation.name,
                        virtualNft.generation.lastTokenId,
                        virtualNft.generation.price,
                        virtualNft.creatorFee
                    )
                )
            );
    }

    /// @notice Verifies the signature for a given VirtualCollection, returning the address of the signer.
    /// @dev Will revert if the signature is invalid. Does not verify that the signer is authorized to mint NFTs.
    /// @param virtualNft An VirtualCollection describing an unminted NFT.
    /// @param signature An EIP712 signature of the given virtualNft.
    function _verify(
        VirtualCollection calldata virtualNft,
        bytes32 _digestH,
        bytes memory signature
    ) internal view returns (address) {
        /*  bytes32 digest = _hash(virtualNft);
        return ECDSA.recover(digest,signature); */

        return _digestH.toEthSignedMessageHash().recover(signature);
    }

    function _verifyTest(
        VirtualCollection calldata virtualNft,
        bytes memory signature
    ) external view returns (address) {
        bytes32 digest = _hash(virtualNft);
        return ECDSA.recover(digest, signature);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721)
        returns (bool)
    {
        return ERC721.supportsInterface(interfaceId);
    }
}
