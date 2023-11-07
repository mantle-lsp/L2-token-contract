// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {TimelockController} from "openzeppelin/governance/TimelockController.sol";
import {Script, console2} from "forge-std/Script.sol";

import {METHL2} from "../src/METHL2.sol";

struct Deployments {
    TimelockController proxyAdmin;
    TransparentUpgradeableProxy proxy;
    METHL2 mETHL2;
}

contract METHL2Script is Script {
    address public immutable l1TokenAddress = vm.envAddress("L1_TOKEN_ADDRESS");
    address public immutable l2BridgeAddress = vm.envAddress("L2_BRIDGE_ADDRESS");
    address public immutable adminAddress = vm.envAddress("ADMIN_ADDRESS");

    TimelockController public proxyAdmin;
    METHL2 public implementationContract;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(msg.sender);
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

        Deployments memory deps;
        deps.proxyAdmin = proxyAdmin;
        deps.proxy = proxyContract;
        deps.mETHL2 = implementationContract;

        writeDeployments(deps);
    }

    function _deploymentsFile() internal view returns (string memory) {
        string memory root = vm.projectRoot();
        return string.concat(root, "/deployments/", vm.toString(block.chainid));
    }

    function writeDeployments(Deployments memory deps) public {
        vm.writeFileBinary(_deploymentsFile(), abi.encode(deps));
    }
}
