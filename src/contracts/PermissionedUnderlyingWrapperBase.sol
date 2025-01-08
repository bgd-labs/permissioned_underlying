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

  function _update(address from, address to, uint256 value) internal override onlyAllowedUser(to, from) {
    super._update(from, to, value);
  }

  function _isAddressRestricted(address user) internal view virtual returns (bool);

  function _canSendToRestricted(address user) internal view virtual returns (bool);
}
