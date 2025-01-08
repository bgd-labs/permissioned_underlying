// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPermissionedUnderlyingWrapper {
  function setRestrictedAddress(address _restrictedAddress) external;
  
  function setAllowedUser(address _allowedUser) external;
}