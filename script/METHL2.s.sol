// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {TimelockController} from "openzeppelin/governance/TimelockController.sol";

import {METHL2} from "../src/METHL2.sol";

import {Script, console2} from "forge-std/Script.sol";

contract METHL2Script is Script {
    address public immutable l1TokenAddress = vm.envAddress("L1_TOKEN_ADDRESS");
    address public immutable l2BridgeAddress = vm.envAddress("L2_BRIDGE_ADDRESS");
    address public immutable adminAddress = vm.envAddress("ADMIN_ADDRESS");

    TimelockController public proxyAdmin;
    METHL2 public implementationContract;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(adminAddress);
        implementationContract = new METHL2();

        console2.log("IMPLEMENTATION CONTRACT ADDRESS: ", address(implementationContract));

        proxyAdmin = new TimelockController(
            0,
            new address[](0),
            new address[](0),
            adminAddress
        );

        console2.log("TIMELOCK CONTROLLER ADDRESS: ", address(proxyAdmin));

        bytes memory data = abi.encodeWithSelector(
            implementationContract.initialize.selector, l2BridgeAddress, l1TokenAddress, adminAddress
        );

        TransparentUpgradeableProxy proxyContract = new TransparentUpgradeableProxy(
            address(implementationContract),
            address(proxyAdmin),
            data
        );
        vm.stopBroadcast();

        console2.log("PROXY CONTRACT ADDRESS: ", address(proxyContract));
    }
}
