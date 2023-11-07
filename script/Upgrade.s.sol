// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/* solhint-disable no-console */

import "openzeppelin-contracts/lib/forge-std/src/Script.sol";
import {ITransparentUpgradeableProxy, TransparentUpgradeableProxy} from "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
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

    function scheduleAndExecute(TimelockController controller, address target, uint256 value, bytes memory data) public {
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
