// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC4626Upgradeable, IERC20, ERC20Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {OwnableUpgradeable} from 'openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol';

abstract contract PermissionedERC4626UpgradeableBase is ERC4626Upgradeable {

  function initialize(IERC20 token) public virtual initializer {
    __ERC4626_init(token);
  } 

  error RestrictedAddress(address user);

  modifier onlyAllowedUser(address user) {
    require(_isAddressAllowed(user), RestrictedAddress(user));
    _;
  }

  function deposit(uint256 assets, address receiver) public override onlyAllowedUser(receiver) returns (uint256) {
    return super.deposit(assets, receiver);
  }

  function mint(uint256 shares, address receiver) public override onlyAllowedUser(receiver) returns (uint256) {
    return super.mint(shares, receiver);
  }

  function transfer(address to, uint256 amount) public override(ERC20Upgradeable, IERC20) onlyAllowedUser(to) returns (bool) {
    return super.transfer(to, amount);
  }

  function transferFrom(address from, address to, uint256 value) public override(ERC20Upgradeable, IERC20) onlyAllowedUser(to) returns (bool) {
    return super.transferFrom(from, to, value);
  }

  function _isAddressAllowed(address user) internal virtual view returns(bool);
}