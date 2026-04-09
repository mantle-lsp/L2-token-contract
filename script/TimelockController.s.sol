// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {Script, console2} from "forge-std/Script.sol";

struct TimelockDeployments {
    address timelock3d;
    address timelock24h;
}

/**
 * @title TimelockControllerScript
 * @notice Deploys two TimelockController instances via CREATE2: 3-day and 24-hour minDelay.
 *
 * Usage:
 *   forge script script/TimelockController.s.sol:TimelockControllerScript --sig "deploy()" \
 *     --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv
 *
 * Environment:
 *   - TIMELOCK_UPGRADER (required): first proposer / canceller
 *   - TIMELOCK_ADMIN (required): receives DEFAULT_ADMIN_ROLE after setup; deployer renounces admin
 *   - TIMELOCK_SALT_3D (optional): bytes32 salt for 3d timelock; default keccak256("TimelockController_3d")
 *   - TIMELOCK_SALT_24H (optional): bytes32 salt for 24h timelock; default keccak256("TimelockController_24h")
 *
 * Proposer / canceller / executor: TIMELOCK_UPGRADER (deployer only holds admin until renounce).
 */
contract TimelockControllerScript is Script {
    uint256 internal constant MIN_DELAY_3D = 3 days;
    uint256 internal constant MIN_DELAY_24H = 24 hours;

    /// @dev Matches OpenZeppelin TimelockController role constants (not visible as `Type.ROLE` on this compiler).
    bytes32 internal constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 internal constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 internal constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");

    function setUp() public {}

    function deploy() public {
        address deployer = msg.sender;
        address upgrader = vm.envAddress("TIMELOCK_UPGRADER");
        address admin = vm.envAddress("TIMELOCK_ADMIN");

        require(admin != address(0), "TIMELOCK_ADMIN required");

        bytes32 salt_24h  = vm.envOr("TIMELOCK_SALT_24H", keccak256(bytes("TimelockController-24h")));
        bytes32 salt_3day = vm.envOr("TIMELOCK_SALT_3D",  keccak256(bytes("TimelockController-3day")));

        address[] memory controllers = new address[](1);
        controllers[0] = deployer;

        bytes memory args = abi.encode(0, controllers, controllers, deployer);
        bytes32 bytecodeHash = hashInitCode(type(TimelockController).creationCode, args);
        address predictedAddress_24h  = computeCreate2Address(salt_24h,  bytecodeHash);
        address predictedAddress_3day = computeCreate2Address(salt_3day, bytecodeHash);

        console2.log("=============================");
        console2.log("TimelockController (CREATE2)");
        console2.log("=============================");
        console2.log("Deployer:", deployer);
        console2.log("Upgrader:", upgrader);
        console2.log("Admin:", admin);
        console2.log("Predicted address_24h:", predictedAddress_24h);
        console2.log("Predicted address_3day:", predictedAddress_3day);
        console2.log();

        vm.startBroadcast(deployer);

        TimelockController tl_24h = new TimelockController{salt: salt_24h}(
            0,
            controllers,
            controllers,
            deployer
        );
        require(address(tl_24h) == predictedAddress_24h, "CREATE2 address mismatch: 24h");

        TimelockController tl_3day = new TimelockController{salt: salt_3day}(
            0,
            controllers,
            controllers,
            deployer
        );
        require(address(tl_3day) == predictedAddress_3day, "CREATE2 address mismatch: 3day");

        _configureTimelock(tl_24h, MIN_DELAY_24H, deployer, upgrader, admin);
        _configureTimelock(tl_3day, MIN_DELAY_3D, deployer, upgrader, admin);

        vm.stopBroadcast();

        console2.log("Timelock_24h:", address(tl_24h));
        console2.log("Timelock_3day:", address(tl_3day));

        _writeDeployments(
            TimelockDeployments({timelock3d: address(tl_3day), timelock24h: address(tl_24h)})
        );
    }
    /// @dev Grant DEFAULT_ADMIN_ROLE to `finalAdmin`, operational roles, set min delay via timelock, then deployer renounces its roles.
    function _configureTimelock(
        TimelockController t,
        uint256 finalMinDelay,
        address deployer,
        address upgrader,
        address finalAdmin
    ) internal {
        // AccessControl.DEFAULT_ADMIN_ROLE
        bytes32 adminRole = bytes32(0);
        t.grantRole(adminRole, finalAdmin);
        t.grantRole(PROPOSER_ROLE, upgrader);
        t.grantRole(CANCELLER_ROLE, upgrader);
        t.grantRole(EXECUTOR_ROLE, upgrader);
        _scheduleAndExecuteUpdateDelay(t, finalMinDelay);
        if (t.hasRole(PROPOSER_ROLE, deployer)) {
            t.revokeRole(PROPOSER_ROLE, deployer);
        }
        if (t.hasRole(CANCELLER_ROLE, deployer)) {
            t.revokeRole(CANCELLER_ROLE, deployer);
        }
        if (t.hasRole(EXECUTOR_ROLE, deployer)) {
            t.revokeRole(EXECUTOR_ROLE, deployer);
        }
        if (t.hasRole(adminRole, deployer)) {
            t.renounceRole(adminRole, deployer);
        }
    }

    function _scheduleAndExecuteUpdateDelay(TimelockController t, uint256 newDelay) internal {
        bytes memory data = abi.encodeCall(TimelockController.updateDelay, (newDelay));
        bytes32 predecessor = bytes32(0);
        bytes32 salt = bytes32(0);
        t.schedule(address(t), 0, data, predecessor, salt, 0);
        t.execute(address(t), 0, data, predecessor, salt);
    }

    function _writeDeployments(TimelockDeployments memory deps) internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/timelock-", vm.toString(block.chainid), ".json");
        string memory json = "deployments";
        vm.serializeAddress(json, "timelock3d",  deps.timelock3d);
        string memory out = vm.serializeAddress(json, "timelock24h", deps.timelock24h);
        vm.writeJson(out, path);
        console2.log("Deployments saved to:", path);
    }
}
