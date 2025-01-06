// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PermissionedERC4626UpgradeableBase, IERC20} from './PermissionedERC4626UpgradeableBase.sol';
import {IAccessControl} from 'openzeppelin-contracts/contracts/access/IAccessControl.sol';

contract PermissionedERC4626Upgradeable is PermissionedERC4626UpgradeableBase {
  bytes32 public immutable ALLOWED_ROLE;
  IAccessControl public immutable ACCESS_CONTROL;
  constructor(bytes32 allowedRole, IAccessControl accessControl) {
    ALLOWED_ROLE = allowedRole;
    ACCESS_CONTROL = accessControl;
  }

  function _isAddressAllowed(address user) internal virtual override view returns(bool) {
    return ACCESS_CONTROL.hasRole(ALLOWED_ROLE, user);
  }
}