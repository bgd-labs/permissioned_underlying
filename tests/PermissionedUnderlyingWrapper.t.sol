// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PermissionedUnderlyingWrapper, PermissionedUnderlyingWrapperBase, IERC20} from '../src/contracts/PermissionedUnderlyingWrapper.sol';
import {Gateway} from '../src/contracts/Gateway.sol';
import {IPool, DataTypes} from 'aave-v3-origin/contracts/interfaces/IPool.sol';
import {TestnetProcedures, ConfiguratorInputTypes, TestnetERC20, TestVars, PoolConfigurator} from 'lib/aave-address-book/lib/aave-v3-origin/tests/utils/TestnetProcedures.sol';
import {IAaveOracle, IPriceOracleGetter} from 'aave-v3-origin/contracts/interfaces/IAaveOracle.sol';
import {ERC1967Proxy} from 'openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol';

contract PriceSource {
  uint256 public immutable PRICE;

  constructor(address oracle, address weth) {
    PRICE = IAaveOracle(oracle).getAssetPrice(address(weth));
  }

  function latestAnswer() external view returns (uint256) {
    return PRICE;
  }
}

contract PermissionedUnderlyingWrapperTest is TestnetProcedures {
  IERC20 public underlyingToken;
  PermissionedUnderlyingWrapper public token;

  IERC20 public aToken;
  IERC20 public vToken;

  Gateway public gateway;

  struct ExtendedTestVars {
    TestVars vars;
    address gatewayOwner;
    address allowedUser;
    uint120 initialAmount;
    uint128 amount;
    address randUser;
    address liquidator;
  }

  modifier initializeTest(ExtendedTestVars memory t) {
    vm.assume(t.allowedUser != address(0));
    vm.assume(t.gatewayOwner != address(0));
    vm.assume(t.randUser != address(0));
    vm.assume(t.liquidator != address(0));
    t.amount = uint128(t.initialAmount) + 10 ** 12;
    initTestEnvironment();

    underlyingToken = IERC20(address(new TestnetERC20('test', 'TEST', 18, address(this))));
    token = new PermissionedUnderlyingWrapper();
    token = PermissionedUnderlyingWrapper(
      address(
        new ERC1967Proxy(
          address(token),
          abi.encodeWithSelector(
            PermissionedUnderlyingWrapper.initialize.selector,
            underlyingToken,
            address(this)
          )
        )
      )
    );

    gateway = new Gateway(IPool(report.poolProxy));
    gateway = Gateway(
      address(
        new ERC1967Proxy(
          address(gateway),
          abi.encodeWithSelector(Gateway.initialize.selector, t.gatewayOwner)
        )
      )
    );

    ConfiguratorInputTypes.InitReserveInput[] memory input = _generateInitConfig(
      t.vars,
      report,
      poolAdmin,
      true
    );

    input[0].underlyingAsset = address(token);

    vm.startPrank(poolAdmin);
    PoolConfigurator(report.poolConfiguratorProxy).initReserves(input);
    PoolConfigurator(report.poolConfiguratorProxy).setReserveBorrowing(address(token), true);
    address[] memory assets = new address[](1);
    address[] memory sources = new address[](1);
    assets[0] = address(token);
    sources[0] = address(new PriceSource(report.aaveOracle, address(weth)));

    IAaveOracle(report.aaveOracle).setAssetSources(assets, sources);
    vm.stopPrank();

    DataTypes.ReserveData memory data = IPool(report.poolProxy).getReserveDataExtended(
      address(token)
    );
    aToken = IERC20(data.aTokenAddress);
    vToken = IERC20(data.variableDebtTokenAddress);

    token.setRestrictedAddress(address(aToken));
    token.setAllowedUser(address(gateway));

    deal(address(underlyingToken), t.allowedUser, t.amount);

    vm.prank(t.gatewayOwner);
    gateway.setAddressAllowed(t.allowedUser, true);
    vm.startPrank(t.allowedUser);
    _;
  }

  function test_depositToPoolRestricted(ExtendedTestVars memory t) public initializeTest(t) {
    underlyingToken.approve(address(token), t.amount);
    token.deposit(t.amount, t.allowedUser);

    token.approve(report.poolProxy, t.amount);
    vm.expectRevert(
      abi.encodeWithSelector(
        PermissionedUnderlyingWrapperBase.NotAllowedToSendToRestricted.selector,
        address(aToken),
        address(t.allowedUser)
      )
    );
    IPool(report.poolProxy).deposit(address(token), t.amount, address(this), 0);

    token.approve(address(gateway), t.amount);
    gateway.depositToPool(address(token), t.amount, t.allowedUser, 0);

    assertEq(aToken.balanceOf(t.allowedUser), t.amount);
  }

  function test_borrowAvailable(ExtendedTestVars memory t) public initializeTest(t) {
    underlyingToken.approve(address(token), t.amount);
    token.deposit(t.amount, t.allowedUser);

    token.approve(address(gateway), t.amount);
    gateway.depositToPool(address(token), t.amount, t.allowedUser, 0);

    vm.startPrank(poolAdmin);
    deal(address(weth), t.randUser, t.amount);
    vm.startPrank(t.randUser);
    weth.approve(report.poolProxy, t.amount);
    IPool(report.poolProxy).deposit(address(weth), t.amount, t.randUser, 0);
    IPool(report.poolProxy).borrow(address(token), t.amount / 2, 2, 0, t.randUser);
    assertEq(vToken.balanceOf(t.randUser), t.amount / 2);
  }

  function test_repayAvailable(ExtendedTestVars memory t) public initializeTest(t) {
    underlyingToken.approve(address(token), t.amount);
    token.deposit(t.amount, t.allowedUser);

    token.approve(address(gateway), t.amount);
    gateway.depositToPool(address(token), t.amount, t.allowedUser, 0);

    vm.startPrank(poolAdmin);
    wbtc.mint(t.randUser, t.amount);
    vm.startPrank(t.randUser);
    wbtc.approve(report.poolProxy, t.amount);
    IPool(report.poolProxy).deposit(address(wbtc), t.amount, t.randUser, 0);
    IPool(report.poolProxy).borrow(address(token), t.amount / 2, 2, 0, t.randUser);
    token.approve(address(gateway), t.amount / 2);
    gateway.repayToPool(address(token), t.amount / 2, 2, t.randUser);
    assertEq(vToken.balanceOf(t.randUser), 0);
  }

  function test_liquidationAvailable(ExtendedTestVars memory t) public initializeTest(t) {
    underlyingToken.approve(address(token), t.amount);
    token.deposit(t.amount, t.allowedUser);

    token.approve(address(gateway), t.amount);
    gateway.depositToPool(address(token), t.amount, t.allowedUser, 0);

    vm.startPrank(poolAdmin);
    deal(address(weth), t.randUser, t.amount);
    vm.startPrank(t.randUser);
    weth.approve(report.poolProxy, t.amount);
    IPool(report.poolProxy).deposit(address(weth), t.amount, t.randUser, 0);
    vm.mockCall(
      address(report.aaveOracle),
      abi.encodeWithSelector(IPriceOracleGetter.getAssetPrice.selector, address(token)),
      abi.encode(0)
    );
    IPool(report.poolProxy).borrow(address(token), t.amount, 2, 0, t.randUser);
    vm.clearMockedCalls();

    deal(address(token), t.liquidator, t.amount);
    vm.startPrank(t.liquidator);
    token.approve(address(gateway), t.amount);
    assertEq(weth.balanceOf(t.liquidator), 0);
    gateway.liquidationCallToPool(address(weth), address(token), t.randUser, t.amount, false);

    assertGe(weth.balanceOf(t.liquidator), 0);
  }

  function test_withdrawAvailable(ExtendedTestVars memory t) public initializeTest(t) {
    underlyingToken.approve(address(token), t.amount);
    token.deposit(t.amount, t.allowedUser);

    token.approve(address(gateway), t.amount);
    gateway.depositToPool(address(token), t.amount, t.randUser, 0);

    vm.startPrank(t.randUser);
    IPool(report.poolProxy).withdraw(address(token), t.amount, t.randUser);
    assertEq(token.balanceOf(t.randUser), t.amount);
  }

  function test_gatewayRestricted(ExtendedTestVars memory t) public initializeTest(t) {
    vm.stopPrank();
    vm.startPrank(t.randUser);
    deal(address(underlyingToken), t.randUser, t.amount);
    underlyingToken.approve(address(token), t.amount);
    token.deposit(t.amount, t.randUser);

    token.approve(address(gateway), t.amount);
    vm.expectRevert(
      abi.encodeWithSelector(Gateway.AddressNotAllowed.selector, address(t.randUser))
    );
    gateway.depositToPool(address(token), t.amount, t.randUser, 0);
  }
}
