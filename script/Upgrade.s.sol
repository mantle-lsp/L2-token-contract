// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/* solhint-disable no-console */

import "openzeppelin-contracts/lib/forge-std/src/Script.sol";
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {TimelockController} from "openzeppelin/governance/TimelockController.sol";

import {METHL2} from "../src/METHL2.sol";

struct Deployments {
    TimelockController proxyAdmin;
    TransparentUpgradeableProxy proxy;
    METHL2 mETHL2;
}

contract CalldataPrinter is ScriptBase {
    string private _name;
    mapping(bytes4 => string) private _selectorNames;

    constructor(string memory name) {
        _name = name;
    }

    function setSelectorName(bytes4 selector, string memory name) external {
        _selectorNames[selector] = name;
    }

    fallback() external {
        console2.log("Calldata to %s [%s]:", _name, _selectorNames[bytes4(msg.data[:4])]);
        console2.logBytes(msg.data);
    }
}

contract Upgrade is Script {
    /// @dev Deploys a new implementation contract for a given contract name and returns its proxy address with its new
    /// implementation address.
    /// @param contractName The name of the contract to deploy as implementation.
    /// @return proxyAddr The address of the new proxy contract.
    /// @return implAddress The address of the new implementation contract.
    function _deployImplementation(string memory contractName) internal returns (address, address) {
        Deployments memory depls = readDeployments();
        if (keccak256(bytes(contractName)) == keccak256("METHL2")) {
            METHL2 impl = new METHL2();
            return (address(depls.proxy), address(impl));
        }
        revert("Unknown contract");
    }

    function upgrade(string memory contractName, bool justPrintCalldata) public {
        Deployments memory depls = readDeployments();

        vm.startBroadcast(msg.sender);
        (address proxyAddr, address implAddress) = _deployImplementation(contractName);
        vm.stopBroadcast();

        bytes memory callData = abi.encodeCall(ITransparentUpgradeableProxy.upgradeTo, (implAddress));

        console2.log("=============================");
        console2.log("Onchain addresses");
        console2.log("=============================");
        console2.log(string.concat(contractName, " address (proxy):"));
        console2.log(proxyAddr);
        console2.log("New implementation address:");
        console2.log(implAddress);
        console2.log();

        TimelockController proxyAdmin;

        if (!justPrintCalldata) {
            console2.log("=============================");
            console2.log("SUBMITTING UPGRADE TX ONCHAIN");
            console2.log("=============================");

            proxyAdmin = depls.proxyAdmin;
            vm.startBroadcast();
        } else {
            console2.log("=============================");
            console2.log("REQUESTED NOT TO EXECUTE, justPrintCalldata set to true");
            console2.log("MUST CALL PROXY ADMIN WITH CALLDATA");
            console2.log("=============================");
            console2.log("Proxy:");
            console2.log(proxyAddr);
            console2.log("Calldata to Proxy:");
            console2.logBytes(callData);
            console2.log("---");
            console2.log("ProxyAdmin:");
            console2.log(address(depls.proxyAdmin));
            CalldataPrinter printer = new CalldataPrinter("ProxyAdmin");
            printer.setSelectorName(TimelockController.schedule.selector, "schedule");
            printer.setSelectorName(TimelockController.execute.selector, "execute");

            proxyAdmin = TimelockController(payable(address(printer)));
        }

        // Run the upgrade.
        scheduleAndExecute(proxyAdmin, proxyAddr, 0, callData);
    }

    /// @notice Upgrade METHL2 to V2 with LayerZero Adapter support (upgradeToAndCall)
    /// @param lzAdapter Address of the LayerZero Adapter (can be address(0) to set later)
    /// @param justPrintCalldata If true, only print calldata without executing
    function upgradeToV2(address lzAdapter, bool justPrintCalldata) public {
        Deployments memory depls = readDeployments();
        console2.log("Deployments:", address(depls.proxy));
        console2.log("Deployer address:", msg.sender);
        console2.log("ProxyAdmin:", address(depls.proxyAdmin));
        console2.log("METHL2:", address(depls.mETHL2));

        vm.startBroadcast(msg.sender);
        METHL2 newImpl = new METHL2();
        vm.stopBroadcast();

        address proxyAddr = address(depls.proxy);
        address implAddress = address(newImpl);

        // Build upgradeToAndCall calldata with initializeV2
        bytes memory initData = abi.encodeCall(METHL2.initializeV2, (lzAdapter));
        bytes memory callData = abi.encodeCall(
            ITransparentUpgradeableProxy.upgradeToAndCall,
            (implAddress, initData)
        );

        console2.log("=============================");
        console2.log("METHL2 V2 Upgrade (upgradeToAndCall)");
        console2.log("=============================");
        console2.log("METHL2 address (proxy):");
        console2.log(proxyAddr);
        console2.log("New implementation address:");
        console2.log(implAddress);
        console2.log("LZ Adapter address:", lzAdapter);
        console2.log();

        TimelockController proxyAdmin;

        if (!justPrintCalldata) {
            console2.log("=============================");
            console2.log("SUBMITTING UPGRADE TX ONCHAIN");
            console2.log("=============================");

            proxyAdmin = depls.proxyAdmin;
            vm.startBroadcast();
        } else {
            console2.log("=============================");
            console2.log("REQUESTED NOT TO EXECUTE, justPrintCalldata set to true");
            console2.log("MUST CALL PROXY ADMIN WITH CALLDATA");
            console2.log("=============================");
            console2.log("Proxy:");
            console2.log(proxyAddr);
            console2.log("Calldata to Proxy (upgradeToAndCall):");
            console2.logBytes(callData);
            console2.log("---");
            console2.log("initializeV2 Calldata (for reference):");
            console2.logBytes(initData);
            console2.log("---");
            console2.log("ProxyAdmin:");
            console2.log(address(depls.proxyAdmin));
            CalldataPrinter printer = new CalldataPrinter("ProxyAdmin");
            printer.setSelectorName(TimelockController.schedule.selector, "schedule");
            printer.setSelectorName(TimelockController.execute.selector, "execute");

            proxyAdmin = TimelockController(payable(address(printer)));
        }

        // Run the upgrade with initializeV2
        scheduleAndExecute(proxyAdmin, proxyAddr, 0, callData);

        if (!justPrintCalldata) {
            vm.stopBroadcast();

            // Verify upgrade
            METHL2 upgraded = METHL2(proxyAddr);
            console2.log();
            console2.log("=============================");
            console2.log("Upgrade Verification");
            console2.log("=============================");
            console2.log("lzAdapter:", upgraded.lzAdapter());
            console2.log("l2BridgeEnabled:", upgraded.l2BridgeEnabled());
        }
    }

    function scheduleAndExecute(TimelockController controller, address target, uint256 value, bytes memory data)
        public
    {
        controller.schedule({
            target: target,
            value: value,
            data: data,
            predecessor: bytes32(0),
            delay: 0,
            salt: bytes32(0)
        });
        controller.execute{value: value}({
            target: target,
            value: value,
            payload: data,
            predecessor: bytes32(0),
            salt: bytes32(0)
        });
    }

    function _deploymentsFile() internal view returns (string memory) {
        string memory root = vm.projectRoot();
        return string.concat(root, "/deployments/", vm.toString(block.chainid));
    }

    function readDeployments() public view returns (Deployments memory) {
        bytes memory data = vm.readFileBinary(_deploymentsFile());
        Deployments memory depls = abi.decode(data, (Deployments));

        require(address(depls.mETHL2).code.length > 0, "contracts are not deployed yet");
        return depls;
    }
}
