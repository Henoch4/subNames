// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title SubNames — subdomain registry for BotNames (standalone v1).
/// Claim a parent label for a small fee, then issue unlimited subnames under
/// it. resolve("dev","alice") → holder. Parent owners can transfer parents.
/// BotNames-linkage (proof of parent ownership) is the upgrade path.
contract SubNames is ReentrancyGuard, Ownable {
    uint256 public constant PARENT_FEE = 0.005 ether;

    mapping(string => address) private _parents; // label => owner
    mapping(string => mapping(string => address)) private _subs; // parent => sub => holder
    string[] private _parentList;

    event ParentClaimed(string indexed parent, address indexed owner);
    event ParentTransferred(string indexed parent, address indexed oldOwner, address indexed newOwner);
    event SubIssued(string indexed parent, string indexed sub, address indexed holder);
    event FeesWithdrawn(address indexed to, uint256 amount);

    constructor() Ownable(msg.sender) {}

    function claimParent(string calldata parent) external payable nonReentrant {
        require(bytes(parent).length > 0 && bytes(parent).length <= 32, "Bad label");
        require(_parents[parent] == address(0), "Taken");
        require(msg.value >= PARENT_FEE, "Fee required");
        _parents[parent] = msg.sender;
        _parentList.push(parent);
        if (msg.value > PARENT_FEE) {
            (bool ok, ) = msg.sender.call{value: msg.value - PARENT_FEE}("");
            require(ok, "Change failed");
        }
        emit ParentClaimed(parent, msg.sender);
    }

    function transferParent(string calldata parent, address newOwner) external {
        require(_parents[parent] == msg.sender, "Not parent owner");
        require(newOwner != address(0), "Zero owner");
        _parents[parent] = newOwner;
        emit ParentTransferred(parent, msg.sender, newOwner);
    }

    function issue(string calldata parent, string calldata sub, address holder) external {
        require(_parents[parent] == msg.sender, "Not parent owner");
        require(bytes(sub).length > 0 && bytes(sub).length <= 32, "Bad label");
        require(holder != address(0), "Zero holder");
        _subs[parent][sub] = holder;
        emit SubIssued(parent, sub, holder);
    }

    function revoke(string calldata parent, string calldata sub) external {
        require(_parents[parent] == msg.sender, "Not parent owner");
        delete _subs[parent][sub];
    }

    function withdrawFees(address to) external onlyOwner nonReentrant {
        uint256 bal = address(this).balance;
        require(bal > 0, "Empty");
        (bool ok, ) = to.call{value: bal}("");
        require(ok, "Pay failed");
        emit FeesWithdrawn(to, bal);
    }

    function parentOwner(string calldata parent) external view returns (address) {
        return _parents[parent];
    }

    function resolve(string calldata parent, string calldata sub) external view returns (address) {
        return _subs[parent][sub];
    }

    function totalParents() external view returns (uint256) {
        return _parentList.length;
    }

    function parentAt(uint256 i) external view returns (string memory) {
        return _parentList[i];
    }
}
