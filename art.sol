// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/Counters.sol";
import './AbstractERC1155Factory.sol';
import "./PaymentSplitter.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";


//authors: wen & ellis

contract ArtCollection is AbstractERC1155Factory, PaymentSplitter  {
    using Counters for Counters.Counter;
    Counters.Counter private counter;



    bool burnClosed;
    mapping(uint256 => bool) private isClaimClosed;
    mapping(uint256 => bool) private isSaleClosed;
    mapping(uint256 => ArtCollection) public artCollections;

    event Claimed(uint indexed index, address indexed account, uint amount);
    event Purchased(uint indexed index, address indexed account, uint amount);

    struct ArtCollection {
        uint256 mintPrice;
        uint256 maxSupply;
        uint256 purchased;
        string ipfsHash;
        mapping(address => uint256) claimed;

    }

    constructor(
        string memory _name,
        string memory _symbol,
        address[] memory payees,
        uint256[] memory shares_
    ) ERC1155("gateway.pinata.cloud/ipfs/") PaymentSplitter(payees, shares_) {
        name_ = _name;
        symbol_ = _symbol;

    }

    //unix timestamps
    uint256 public claimWindowOpens = 1636064533;
    uint256 public claimWindowCloses = 1636064533;
    uint256 public purchaseWindowOpens = 1636064533;
    uint256 public burnWindowOpens = 1636064533;

    //Function that adds new art to sell in the contract
    function addArtCollection(
        uint256  _mintPrice, //gwei
        uint256 _maxSupply,    // Maximum Total supply
        uint256 _maxPurchaseSupply,   // Maximum total Supply
        string memory _ipfsHash    //ipfs hash for metadata url
    ) public onlyOwner {
        ArtCollection storage gallery = artCollections[counter.current()];
        gallery.mintPrice = _mintPrice;
        gallery.maxSupply = _maxPurchaseSupply;
        gallery.ipfsHash = _ipfsHash;
        counter.increment();
    }

    //changes art collection for sale by owner designated purchase window
    function changeArtCollection(
        uint256  _mintPrice, //mint price in gwei
        string memory _ipfsHash, //hash for art collection meta data
        uint256 _artCollectionIndex//art collection ID 
    ) external onlyOwner {
        require(exists(_artCollectionIndex), "changeArtCollection: artCollection does not exist");
        artCollections[_artCollectionIndex].mintPrice = _mintPrice; 
        artCollections[_artCollectionIndex].ipfsHash = _ipfsHash;
    }




    //minting function - mints the token that is available for sale during the purchase window
    function mint(uint256 id, uint256 amount, address to) external onlyOwner {
        require(exists(id), "Mint: artCollection does not exist");
        require(totalSupply(id) + amount <= artCollections[id].maxSupply, "Mint: Max supply reached");

        _mint(id, amount,to, "");
    }



    //helper function to close sale
    function closeSale(uint256[] calldata id) external onlyOwner {
        uint256 count = id.length; //id of sale to close for

        for (uint256 i; i < count; i++) {
            require(exists(id[i]), "Close sale: artCollection does not exist");

            isSaleClosed[id[i]] = true;
        }
    }

    function closeClaim(uint256[] calldata id) external onlyOwner {
        //id is the artCollection id to close claiming for
        uint256 count = id.length;

        for (uint256 i; i < count; i++) {
            require(exists(id[i]), "Close claim: artCollection does not exist");

            isClaimClosed[id[i]] = true;
        }
    }

    //Close token burning process if we decide to implement token burning process 
    function closeBurn() external onlyOwner {
        burnClosed = true;
    }

  
    function editWindows(
        uint256 _purchaseWindowOpens,   //unix time stamps for open close times etc
        uint256 _burnWindowOpens,
        uint256 _claimWindowOpens,
        uint256 _claimWindowCloses
    ) external onlyOwner {
        claimWindowOpens = _claimWindowOpens;
        claimWindowCloses = _claimWindowCloses;
        purchaseWindowOpens = _purchaseWindowOpens;
        burnWindowOpens = _burnWindowOpens;
    }


    function purchase(uint256 id, uint256 amount) external payable whenNotPaused {
        //function to purchase art collection tokens
        //art collection id to purchase
        //number of tokens to purchase
        require(!isSaleClosed[id], "Purchase: sale is closed");
        require (block.timestamp >= purchaseWindowOpens, "Purchase: window closed");
        require(totalSupply(id) + amount <= artCollections[id].maxSupply, "Purchase: Max total supply reached");
        require(msg.value == amount * artCollections[id].mintPrice, "Purchase: Incorrect payment");

        artCollections[id].purchased += amount;

        _mint(msg.sender, id, amount, "");

        emit Purchased(id, msg.sender, amount);
    }

    
  
/*  Broken CLAIM FUNCTION NEED TO FIGURE OUT HOW TO FIX -- anyone can claim

    function claim(
        uint256 amount, //amount of art Collection tokens to claim
        uint256 id, //id of art collection to claim from
        uint256 maxAmount // the amount of artCollection tokens to claim
    ) external payable whenNotPaused {
        require(!isClaimClosed[id], "Claim: is closed");
        require (block.timestamp >= claimWindowOpens && block.timestamp <= claimWindowCloses, "Claim: time window closed");
        require(artCollections[id].claimed[msg.sender] + amount <= maxAmount, "Claim: Not allowed to claim given amount"); //Broken claim method , anyone can put values for amount or maxAmount.

        artCollections[id].claimed[msg.sender] = artCollections[id].claimed[msg.sender] + amount;

        _mint(msg.sender, id, amount, "");
        emit Claimed(id, msg.sender, amount);
    }
*/

    //return total supply of all art collection tokens
    function totalSupplyAll() external view returns (uint[] memory) {
        uint[] memory result = new uint[](counter.current());

        for(uint256 i; i < counter.current(); i++) {
            result[i] = totalSupply(i);
        }

        return result;
    }

    //checks if token with id exists 
    function exists(uint256 id) public view override returns (bool) {
        return artCollections[id].maxSupply > 0;
    }

    //Returns token uri for specific token id
    function uri(uint256 _id) public view override returns (string memory) {
            require(exists(_id), "URI: nonexistent token");

            return string(abi.encodePacked(super.uri(_id), artCollections[_id].ipfsHash));
    }
}

interface ERC721Contract is IERC721 {
    function burn(uint256 tokenId) external;
}
