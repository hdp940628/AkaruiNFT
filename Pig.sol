// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC721A.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

library MerkleProof {

    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return processProof(proof, leaf) == root;
    }

   
   
    function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (computedHash <= proofElement) {
            
                computedHash = _efficientHash(computedHash, proofElement);
            } else {
                
                computedHash = _efficientHash(proofElement, computedHash);
            }
        }
        return computedHash;
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}

contract Pig is Ownable, ERC721A, ReentrancyGuard {
    constructor(
    ) ERC721A("pig", "PIG", 1, 10000) {}

    // For marketing etc.
    function reserveMintBatch(uint256[] calldata quantitys, address[] calldata tos) external onlyOwner {
        for(uint256 j =0;j<quantitys.length;j++){
            require(
                totalSupply() + quantitys[j] <= collectionSize,
                "Too many already minted before dev mint."
            );
            uint256 numChunks = quantitys[j] / maxBatchSize;
            for (uint256 i = 0; i < numChunks; i++) {
                _safeMint(tos[i], maxBatchSize);
            }
            if (quantitys[j] % maxBatchSize != 0){
                _safeMint(tos[j], quantitys[j] % maxBatchSize);
            }
        }
    }

    // metadata URI
    string private _baseTokenURI;

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function withdrawMoney() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function setOwnersExplicit(uint256 quantity) external onlyOwner nonReentrant {
        _setOwnersExplicit(quantity);
    }

    function numberMinted(address owner) public view returns (uint256) {
        return _numberMinted(owner);
    }

    function getOwnershipData(uint256 tokenId)
    external
    view
    returns (TokenOwnership memory)
    {
        return ownershipOf(tokenId);
    }

    function refundIfOver(uint256 price) private {
        require(msg.value >= price, "Need to send more ETH.");
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }
    // allowList mint
    uint256 public allowListMintPrice = 0.010000 ether;
    // default false
    bool public allowListStatus = false;
    uint256 public allowListMintAmount = 1000;
    uint256 public immutable maxPerAddressDuringMint = 1;

    bytes32 private merkleRoot;

    mapping(address => bool) public allowListAppeared;
    mapping(address => uint256) public allowListStock;

    function allowListMint(uint256 quantity, bytes32[] memory proof) external payable {
        require(allowListStatus, "not begun");
        require(totalSupply() + quantity <= collectionSize, "reached max supply");
        require(allowListMintAmount >= quantity, "reached max amount");
        require(isInAllowList(msg.sender, proof), "Invalid Merkle Proof.");
        if(!allowListAppeared[msg.sender]){
            allowListAppeared[msg.sender] = true;
            allowListStock[msg.sender] = maxPerAddressDuringMint;
        }
        require(allowListStock[msg.sender] >= quantity, "reached allow list per address mint amount");
        allowListStock[msg.sender] -= quantity;
        _safeMint(msg.sender, quantity);
        allowListMintAmount -= quantity;
        refundIfOver(allowListMintPrice*quantity);
    }

    function setRoot(bytes32 root) external onlyOwner{
        merkleRoot = root;
    }

    function setAllowListStatus(bool status) external onlyOwner {
        allowListStatus = status;
    }

    function isInAllowList(address addr, bytes32[] memory proof) public view returns(bool) {
        bytes32 leaf = keccak256(abi.encodePacked(addr));
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }

    //public sale
    bool public publicSaleStatus = false;
    uint256 public publicPrice = 0.010000 ether;
    uint256 public amountForPublicSale = 1000;
    // per mint public sale limitation
    uint256 public immutable publicSalePerMint = 1;

    function publicSaleMint(uint256 quantity) external payable {
        require(
        publicSaleStatus,
        "not begun"
        );
        require(
        totalSupply() + quantity <= collectionSize,
        "reached max supply"
        );
        require(
        amountForPublicSale >= quantity,
        "reached max amount"
        );

        require(
        quantity <= publicSalePerMint,
        "reached max amount per mint"
        );

        _safeMint(msg.sender, quantity);
        amountForPublicSale -= quantity;
        refundIfOver(uint256(publicPrice) * quantity);
    }

    function setPublicSaleStatus(bool status) external onlyOwner {
        publicSaleStatus = status;
    }
}