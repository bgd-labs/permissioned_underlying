// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {OwnableUpgradeable} from 'openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol';
import {IPool} from 'aave-v3-origin/contracts/interfaces/IPool.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';

contract Gateway is OwnableUpgradeable {
  using SafeERC20 for IERC20;

  IPool public immutable POOL;
  mapping(address => bool) public isAddressAllowed;

  error AddressNotAllowed(address user);

  modifier onlyAllowedAddress(address user) {
    require(isAddressAllowed[user], AddressNotAllowed(user));
    _;
  }

  constructor(IPool pool) {
    POOL = pool;
  }

  function initialize(address _owner) public initializer {
    __Ownable_init(_owner);
  }

  function setAddressAllowed(address _address, bool _allowed) public onlyOwner {
    isAddressAllowed[_address] = _allowed;
  }

  function depositToPool(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) public onlyAllowedAddress(msg.sender) {
    IERC20 token = IERC20(asset);
    token.safeTransferFrom(msg.sender, address(this), amount);
    token.forceApprove(address(POOL), amount);
    POOL.deposit(asset, amount, onBehalfOf, referralCode);
  }

  function repayToPool(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    address onBehalfOf
  ) public {
    IERC20 token = IERC20(asset);
    token.safeTransferFrom(msg.sender, address(this), amount);
    token.forceApprove(address(POOL), amount);
    POOL.repay(asset, amount, interestRateMode, onBehalfOf);
  }

  function liquidationCallToPool(
    address collateralAsset,
    address debtAsset,
    address user,
    uint256 debtToCover,
    bool receiveAToken
  ) public {
    IERC20 debtToken = IERC20(debtAsset);
    IERC20 collateralToken = IERC20(collateralAsset);
    uint256 collateralBalanceBefore = collateralToken.balanceOf(address(this));

    debtToken.safeTransferFrom(msg.sender, address(this), debtToCover);

    debtToken.forceApprove(address(POOL), debtToCover);
    POOL.liquidationCall(collateralAsset, debtAsset, user, debtToCover, receiveAToken);

    uint256 collateralAmount = collateralToken.balanceOf(address(this)) - collateralBalanceBefore;
    collateralToken.safeTransfer(msg.sender, collateralAmount);
  }
}
