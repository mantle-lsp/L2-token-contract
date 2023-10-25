// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {METHL2} from "../src/METHL2.sol";

import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {TimelockController} from "openzeppelin/governance/TimelockController.sol";

contract METHL2Test is Test {
    address public immutable l1TokenAddress = makeAddr("l1Token");
    address public immutable l2BridgeAddress = makeAddr("l2Bridge");
    address public immutable adminAddress = makeAddr("admin");

    TimelockController public proxyAdmin;
    METHL2 public mETHL2;
    METHL2 public implementationContract;

    function setUp() public {
        implementationContract = new METHL2();
        proxyAdmin = new TimelockController(
            0,
            new address[](0),
            new address[](0),
            adminAddress
        );

        bytes memory data = abi.encodeWithSelector(
            implementationContract.initialize.selector, l2BridgeAddress, l1TokenAddress, adminAddress
        );

        TransparentUpgradeableProxy proxyContract = new TransparentUpgradeableProxy(
            address(implementationContract),
            address(proxyAdmin),
            data
        );

        mETHL2 = METHL2(address(proxyContract));
    }

    function test_sanity() public {
        // sanity check initialization
        assertEq(mETHL2.l1Token(), l1TokenAddress);
        assertEq(mETHL2.l2Bridge(), l2BridgeAddress);
        assertEq(mETHL2.decimals(), 18);

        // sanity check proxy paramters
        bytes32 proxyAdminFromSlot =
            vm.load(address(mETHL2), 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103);
        bytes32 implementationContractFromSlot =
            vm.load(address(mETHL2), 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc);

        assertEq(proxyAdminFromSlot, bytes32(uint256(uint160(address(proxyAdmin)))));
        assertEq(implementationContractFromSlot, bytes32(uint256(uint160(address(implementationContract)))));

        assertEq(proxyAdmin.hasRole(keccak256("TIMELOCK_ADMIN_ROLE"), adminAddress), true);

        vm.expectRevert("Initializable: contract is already initialized");
        implementationContract.initialize(l2BridgeAddress, l1TokenAddress, adminAddress);
    }

    function test_burnmint() public {
        // can burn and mint as bridge

        vm.startPrank(l2BridgeAddress);

        mETHL2.mint(address(this), 1000);
        assertEq(mETHL2.balanceOf(address(this)), 1000);

        mETHL2.burn(address(this), 500);
        assertEq(mETHL2.balanceOf(address(this)), 500);

        vm.stopPrank();

        // can't burn and mint as non-bridge
        vm.expectRevert("Only L2 Bridge can mint and burn");
        mETHL2.mint(address(this), 1000);
        assertEq(mETHL2.balanceOf(address(this)), 500);

        vm.expectRevert("Only L2 Bridge can mint and burn");
        mETHL2.burn(address(this), 500);
        assertEq(mETHL2.balanceOf(address(this)), 500);
    }
}
