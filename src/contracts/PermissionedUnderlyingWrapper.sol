// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PermissionedUnderlyingWrapperBase, IERC20} from './PermissionedUnderlyingWrapperBase.sol';
import {OwnableUpgradeable} from 'openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol';
import {IPermissionedUnderlyingWrapper} from './interfaces/IPermissionedUnderlyingWrapper.sol';

contract PermissionedUnderlyingWrapper is IPermissionedUnderlyingWrapper, PermissionedUnderlyingWrapperBase, OwnableUpgradeable {
  address public restrictedAddress;
  address public allowedUser;

  function initialize(IERC20 token, address owner) public virtual initializer {
    __ERC4626_init(token);
    __Ownable_init(owner);
  }

  function setRestrictedAddress(address _restrictedAddress) public onlyOwner {
    restrictedAddress = _restrictedAddress;
  }

  function setAllowedUser(address _allowedUser) public onlyOwner {
    allowedUser = _allowedUser;
  }

  function _isAddressRestricted(address user) internal view override returns (bool) {
    if (restrictedAddress == address(0)) {
      return true;
    }

    return user == restrictedAddress;
  }

  function _canSendToRestricted(address user) internal view override returns (bool) {
    return user == allowedUser;
  }
}
