// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC4626Upgradeable, IERC20, ERC20Upgradeable} from 'openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol';

abstract contract PermissionedUnderlyingWrapperBase is ERC4626Upgradeable {
  error NotAllowedToSendToRestricted(address restricted, address sender);

  modifier onlyAllowedUser(address receiver, address sender) {
    require(
      !_isAddressRestricted(receiver) || _canSendToRestricted(sender),
      NotAllowedToSendToRestricted(receiver, sender)
    );
    _;
  }

  function deposit(
    uint256 assets,
    address receiver
  ) public override onlyAllowedUser(receiver, msg.sender) returns (uint256) {
    return super.deposit(assets, receiver);
  }

  function mint(
    uint256 shares,
    address receiver
  ) public override onlyAllowedUser(receiver, msg.sender) returns (uint256) {
    return super.mint(shares, receiver);
  }

  function transfer(
    address to,
    uint256 amount
  ) public override(ERC20Upgradeable, IERC20) onlyAllowedUser(to, msg.sender) returns (bool) {
    return super.transfer(to, amount);
  }

  function transferFrom(
    address from,
    address to,
    uint256 value
  ) public override(ERC20Upgradeable, IERC20) onlyAllowedUser(to, from) returns (bool) {
    return super.transferFrom(from, to, value);
  }

  function _isAddressRestricted(address user) internal view virtual returns (bool);

  function _canSendToRestricted(address user) internal view virtual returns (bool);
}
