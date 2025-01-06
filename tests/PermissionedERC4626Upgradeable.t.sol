// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {IPool, IPoolAddressesProvider, IACLManager, AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {PermissionedERC4626Upgradeable, PermissionedERC4626UpgradeableBase, IAccessControl, IERC20} from '../src/contracts/PermissionedERC4626Upgradeable.sol';
import {ERC20} from 'solidity-utils/mocks/ERC20.sol';

contract PermissionedERC4626UpgradeableTest is Test {

  bytes32 public constant TEST_TOKEN_ROLE = bytes32('TEST_TOKEN_ROLE');
  PermissionedERC4626Upgradeable public token;
  IERC20 public underlyingToken;

  function setUp() public {
    vm.createSelectFork('mainnet', 21565977);
    
    underlyingToken = IERC20(address(new ERC20("test", "TEST")));
    token = new PermissionedERC4626Upgradeable(TEST_TOKEN_ROLE, IAccessControl(address(AaveV3Ethereum.ACL_MANAGER)));
    token.initialize(underlyingToken);
  }

  modifier initializeTest(address allowedUser) {
    grantAccess(allowedUser);
    _;
  }

  /// forge-config: default.fuzz.runs = 100
  function test_depositRestricted(address allowedUser, address restrictedUser, uint256 amount) public initializeTest(allowedUser) {
    vm.assume(amount != 0);
    vm.assume(allowedUser != restrictedUser);
    vm.assume(allowedUser != address(0));
    vm.assume(restrictedUser != address(0));
    
    deal(address(underlyingToken), address(this), amount);
    underlyingToken.approve(address(token), amount);

    vm.expectRevert(abi.encodeWithSelector(PermissionedERC4626UpgradeableBase.RestrictedAddress.selector, restrictedUser));
    token.deposit(amount, restrictedUser);
    
    token.deposit(amount, allowedUser);
  }

  /// forge-config: default.fuzz.runs = 100
  function test_mintRestricted(address allowedUser, address restrictedUser, uint256 amount) public initializeTest(allowedUser) {
    vm.assume(amount != 0);
    vm.assume(allowedUser != restrictedUser);
    vm.assume(allowedUser != address(0));
    vm.assume(restrictedUser != address(0));
    
    deal(address(underlyingToken), address(this), amount);
    underlyingToken.approve(address(token), amount);

    vm.expectRevert(abi.encodeWithSelector(PermissionedERC4626UpgradeableBase.RestrictedAddress.selector, restrictedUser));
    token.mint(amount, restrictedUser);
    
    token.mint(amount, allowedUser);
  }

  /// forge-config: default.fuzz.runs = 100
  function test_transferRestricted(address allowedUser, address restrictedUser, uint256 amount) public initializeTest(allowedUser) {
    vm.assume(amount != 0);
    vm.assume(allowedUser != restrictedUser);
    vm.assume(allowedUser != address(0));
    vm.assume(restrictedUser != address(0));
    grantAccess(address(this));
    
    deal(address(underlyingToken), address(this), amount);
    underlyingToken.approve(address(token), amount);
    token.mint(amount, address(this));

    vm.expectRevert(abi.encodeWithSelector(PermissionedERC4626UpgradeableBase.RestrictedAddress.selector, restrictedUser));
    token.transfer(restrictedUser, amount);
    
    token.transfer(allowedUser, amount);
  }

  /// forge-config: default.fuzz.runs = 100
  function test_transferFromRestricted(address allowedUser, address restrictedUser, uint256 amount) public initializeTest(allowedUser) {
    vm.assume(amount != 0);
    vm.assume(allowedUser != restrictedUser);
    vm.assume(allowedUser != address(0));
    vm.assume(restrictedUser != address(0));
    grantAccess(address(this));
    
    deal(address(underlyingToken), address(this), amount);
    underlyingToken.approve(address(token), amount);
    token.mint(amount, address(this));
    token.approve(allowedUser, amount);
    token.approve(restrictedUser, amount);

    vm.expectRevert(abi.encodeWithSelector(PermissionedERC4626UpgradeableBase.RestrictedAddress.selector, restrictedUser));
    vm.prank(restrictedUser);
    token.transferFrom(address(this), restrictedUser, amount);
    
    vm.prank(allowedUser);
    token.transferFrom(address(this), allowedUser, amount);
  }

  function grantAccess(address user) internal {
    vm.prank(AaveV3Ethereum.ACL_ADMIN);
    AaveV3Ethereum.ACL_MANAGER.grantRole(TEST_TOKEN_ROLE, user);
  }
}