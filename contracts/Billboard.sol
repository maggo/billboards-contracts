// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract Billboard is Initializable, OwnableUpgradeable, ERC721Upgradeable {
    struct SlotMetadata {
        string imageURI;
        string url;
    }

    mapping(uint256 tokenId => uint256) public minimumPrices;
    mapping(uint256 tokenId => uint256) public currentPrices;
    mapping(uint256 tokenId => address) public lastBuyers;
    mapping(uint256 tokenId => SlotMetadata) public slotMetadata;

    uint256 public minimumPriceIncrement;

    constructor() {
        _disableInitializers();
    }

    function init(
        address owner_,
        string memory name_,
        string memory symbol_,
        uint256 minimumPrice_,
        uint256 minimumPriceIncrement_
    ) public initializer {
        __Ownable_init(owner_);
        __ERC721_init(name_, symbol_);

        minimumPriceIncrement = minimumPriceIncrement_;

        // Mint the 9 slot NFTs
        for (uint256 i = 0; i < 9; i++) {
            _mint(owner_, i);
            minimumPrices[i] = minimumPrice_;
            currentPrices[i] = minimumPrice_;
        }
    }

    function getPrice(uint256 _tokenId) public view returns (uint256) {
        // @TODO Update to use dutch auction system
        return currentPrices[_tokenId];
    }

    function buy(uint256 _tokenId, address _receiver) external payable {
        uint256 currentPrice = getPrice(_tokenId);
        uint256 newPrice = msg.value;
        uint256 priceIncrement = newPrice - currentPrice;

        require(
            priceIncrement >= minimumPriceIncrement,
            "Value must be more than the current price plus the minimum increment"
        );

        address previousBuyer = lastBuyers[_tokenId];

        if (previousBuyer == address(0)) {
            previousBuyer = owner();
        }

        (bool previousBuyerReimbursed, ) = payable(previousBuyer).call{
            value: currentPrice
        }("");
        require(previousBuyerReimbursed, "Failed to reimburse previous owner");

        (bool ownerPaidOut, ) = payable(owner()).call{value: priceIncrement}(
            ""
        );
        require(ownerPaidOut, "Failed to pay out owner");

        // Set new price
        // @TODO Update to use dutch auction system
        currentPrices[_tokenId] = newPrice;

        // Transfer the NFT
        _transfer(ownerOf(_tokenId), _receiver, _tokenId);

        // Set last buyer
        lastBuyers[_tokenId] = _receiver;

        // Reset slot metadata
        slotMetadata[_tokenId] = SlotMetadata("", "");
    }

    function setSlotMetadata(
        uint256 _tokenId,
        string memory _imageURI,
        string memory _url
    ) public {
        require(
            _msgSender() == ownerOf(_tokenId),
            "Only the owner of the slot can set the metadata"
        );

        slotMetadata[_tokenId] = SlotMetadata(_imageURI, _url);
    }

    function getTokenURI(uint256 _tokenId) public view returns (string memory) {
        bytes memory dataURI = abi.encodePacked(
            "{",
            '"name": "Billboard Slot #',
            Strings.toString(_tokenId),
            '",',
            '"description": "An NFT representing a slot in this billboard.",',
            '"image": "',
            slotMetadata[_tokenId].imageURI,
            '",',
            '"external_url: "',
            slotMetadata[_tokenId].url,
            '",',
            "}"
        );
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(dataURI)
                )
            );
    }
}
