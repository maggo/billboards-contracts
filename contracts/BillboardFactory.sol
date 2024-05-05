// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Billboard} from "./Billboard.sol";

contract BillboardFactory is UUPSUpgradeable, AccessControlUpgradeable {
    using StorageSlot for bytes32;

    // keccak256("cool.billboards.master_copy");
    bytes32 public constant BILLBOARD_MASTER_COPY_SLOT =
        0x6836db037f53679d1b632fd6e4fe3feedef61446dbed2d1639a16eb61fc1143a;
    // keccak256("cool.billboards.nonce");
    bytes32 public constant NONCE_SLOT =
        0x64dd3d1dc344747c561ad71629f7a0795b4b224e710830553fc7a9cdd8053d36;

    event BillboardCreated(
        address indexed billboardProxy,
        address indexed billboardImplementation,
        address indexed deployer,
        string name
    );

    constructor() {
        _disableInitializers();
    }

    function init(address billboardMasterCopy) public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();

        BILLBOARD_MASTER_COPY_SLOT.getAddressSlot().value = billboardMasterCopy;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyRole(DEFAULT_ADMIN_ROLE) {}

    function computeSalt(uint256 nonce) internal pure returns (bytes32) {
        return keccak256(abi.encode(nonce, "billboard"));
    }

    function computeNextAddress() external view returns (address) {
        uint256 nonce = NONCE_SLOT.getUint256Slot().value;
        bytes32 salt = computeSalt(nonce);
        return
            Clones.predictDeterministicAddress(
                BILLBOARD_MASTER_COPY_SLOT.getAddressSlot().value,
                salt
            );
    }

    function create(
        string memory name_,
        string memory symbol_,
        string memory image_,
        uint256 minimumPrice_,
        uint256 minimumPriceIncrement_
    ) external returns (address) {
        uint256 nonce = NONCE_SLOT.getUint256Slot().value++;
        bytes32 salt = computeSalt(nonce);
        address billboardMasterCopy = BILLBOARD_MASTER_COPY_SLOT
            .getAddressSlot()
            .value;
        // Deploy & init proxy
        address payable billboardProxy = payable(
            Clones.cloneDeterministic(billboardMasterCopy, salt)
        );
        Billboard(billboardProxy).init({
            owner_: msg.sender,
            name_: name_,
            symbol_: symbol_,
            image_: image_,
            minimumPrice_: minimumPrice_,
            minimumPriceIncrement_: minimumPriceIncrement_
        });
        emit BillboardCreated(
            billboardProxy,
            billboardMasterCopy,
            msg.sender,
            name_
        );
        return billboardProxy;
    }
}
