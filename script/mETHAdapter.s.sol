// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {TimelockController} from "openzeppelin/governance/TimelockController.sol";
import {Script, console2} from "forge-std/Script.sol";

import {L1mETHAdapter} from "../src/L1mETHAdapter.sol";
import {L2mETHAdapter} from "../src/L2mETHAdapter.sol";
import {IMintableBurnable} from "../src/MintBurnOFTAdapterUpgradeable.sol";

struct AdapterDeployments {
    address proxyAdmin;
    address proxy;
    address adapter;
}

// EmptyContract serves as a dud implementation for the proxy, which lets us point
// to something and deploy the proxy before we deploy the implementation.
// This helps avoid the cyclic dependencies in init.
contract EmptyContract {}

/**
 * @title mETHAdapterScript
 * @notice Unified deployment script for L1 and L2 mETH Adapters
 * 
 * Usage:
 *   # Deploy L1 Adapter
 *   forge script script/mETHAdapter.s.sol:mETHAdapterScript --sig "deployL1()" \
 *     --rpc-url $L1_RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv
 *   
 *   # Deploy L2 Adapter  
 *   forge script script/mETHAdapter.s.sol:mETHAdapterScript --sig "deployL2()" \
 *     --rpc-url $L2_RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv
 *
 * Environment Variables:
 *   Common:
 *     - DEPLOY_SALT: CREATE2 salt (default: "mETHAdapter")
 *   
 *   L1:
 *     - L1_TOKEN_ADDRESS: mETH token address on L1
 *     - L1_LZ_ENDPOINT_ADDRESS: LayerZero endpoint on L1
 *     - L1_PROXY_ADMIN: Proxy admin (TimelockController) address
 *     - L1_DELEGATE_ADDRESS: Delegate for OApp config
 *     - L1_OWNER_ADDRESS: Owner address
 *   
 *   L2:
 *     - L2_TOKEN_ADDRESS: mETH token address on L2
 *     - L2_MINTER_BURNER_ADDRESS: METHL2 contract address (for mint/burn)
 *     - L2_LZ_ENDPOINT_ADDRESS: LayerZero endpoint on L2
 *     - L2_PROXY_ADMIN: Proxy admin (TimelockController) address
 *     - L2_DELEGATE_ADDRESS: Delegate for OApp config
 *     - L2_OWNER_ADDRESS: Owner address
 */
contract mETHAdapterScript is Script {
    // CREATE2 salt (can be customized via env)
    // bytes32 public salt = vm.envOr("DEPLOY_SALT", bytes32("mETHAdapter_JAN23"));

    function setUp() public {}

    /// @notice Deploy L1 mETH Adapter (lock/unlock mode)
    function deployL1() public {
        address deployer = msg.sender;
        // Load L1 config from env
        address tokenAddress = vm.envAddress("L1_TOKEN_ADDRESS");
        address lzEndpointAddress = vm.envAddress("L1_LZ_ENDPOINT_ADDRESS");
        address proxyAdminAddress = vm.envAddress("L1_PROXY_ADMIN");
        address delegateAddress = vm.envAddress("L1_DELEGATE_ADDRESS");
        address ownerAddress = vm.envAddress("L1_OWNER_ADDRESS");

        console2.log("=============================");
        console2.log("L1 mETH Adapter Deployment (CREATE2)");
        console2.log("=============================");
        console2.log("Token:", tokenAddress);
        console2.log("LZ Endpoint:", lzEndpointAddress);
        console2.log("Proxy Admin:", proxyAdminAddress);
        console2.log("Deployer address:", deployer);
        console2.log();

        vm.startBroadcast(msg.sender);
        EmptyContract empty = EmptyContract(0xa63780C48eb181Ec85e4E7592191B1c5d54fe1A9);
        // EmptyContract empty = deployEmptyContract();
        TransparentUpgradeableProxy proxy = newProxy(empty, deployer, "mETHAdapter");

        // Deploy implementation contract with CREATE2
        L1mETHAdapter impl = new L1mETHAdapter(
            tokenAddress,
            lzEndpointAddress
        );

        console2.log("IMPLEMENTATION ADDRESS:", address(impl));

        // Prepare initialization data
        L1mETHAdapter.Init memory init = L1mETHAdapter.Init({
            delegate: delegateAddress,
            owner: ownerAddress
        });

        upgradeToAndCall(
            ITransparentUpgradeableProxy(address(proxy)),
            address(impl),
            abi.encodeCall(L1mETHAdapter.initialize, init)
        );

        if (deployer != proxyAdminAddress) {
            ITransparentUpgradeableProxy(address(proxy)).changeAdmin(proxyAdminAddress);
        }

        vm.stopBroadcast();

        console2.log("PROXY ADDRESS:", address(proxy));

        // Save deployments
        _writeDeployments("l1-adapter", AdapterDeployments({
            proxyAdmin: proxyAdminAddress,
            proxy: address(proxy),
            adapter: address(impl)
        }));
    }

    /// @notice Deploy L2 mETH Adapter (mint/burn mode)
    function deployL2() public {
        address deployer = msg.sender;
        // Load L2 config from env
        address tokenAddress = vm.envAddress("L2_TOKEN_ADDRESS");
        address minterBurnerAddress = vm.envAddress("L2_MINTER_BURNER_ADDRESS");
        address lzEndpointAddress = vm.envAddress("L2_LZ_ENDPOINT_ADDRESS");
        address proxyAdminAddress = vm.envAddress("L2_PROXY_ADMIN");
        address delegateAddress = vm.envAddress("L2_DELEGATE_ADDRESS");
        address ownerAddress = vm.envAddress("L2_OWNER_ADDRESS");

        console2.log("=============================");
        console2.log("L2 mETH Adapter Deployment (CREATE2)");
        console2.log("=============================");
        console2.log("Token:", tokenAddress);
        console2.log("MinterBurner:", minterBurnerAddress);
        console2.log("LZ Endpoint:", lzEndpointAddress);
        console2.log("Proxy Admin:", proxyAdminAddress);
        console2.log("Deployer address:", deployer);
        console2.log();

        vm.startBroadcast(msg.sender);
        EmptyContract empty = EmptyContract(0xa63780C48eb181Ec85e4E7592191B1c5d54fe1A9);
        // EmptyContract empty = deployEmptyContract();
        TransparentUpgradeableProxy proxy = newProxy(empty, deployer, "mETHAdapter");

        // Deploy implementation contract with CREATE2
        L2mETHAdapter impl = new L2mETHAdapter(
            tokenAddress,
            IMintableBurnable(minterBurnerAddress),
            lzEndpointAddress
        );

        console2.log("IMPLEMENTATION ADDRESS:", address(impl));

        // Prepare initialization data
        L2mETHAdapter.Init memory init = L2mETHAdapter.Init({
            delegate: delegateAddress,
            owner: ownerAddress
        });

        upgradeToAndCall(
            ITransparentUpgradeableProxy(address(proxy)),
            address(impl),
            abi.encodeCall(L2mETHAdapter.initialize, init)
        );

        if (deployer != proxyAdminAddress) {
            ITransparentUpgradeableProxy(address(proxy)).changeAdmin(proxyAdminAddress);
        }

        vm.stopBroadcast();

        console2.log("PROXY ADDRESS:", address(proxy));

        // Save deployments
        _writeDeployments("l2-adapter", AdapterDeployments({
            proxyAdmin: proxyAdminAddress,
            proxy: address(proxy),
            adapter: address(impl)
        }));
    }

    function _writeDeployments(string memory prefix, AdapterDeployments memory deps) internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/", prefix, "-", vm.toString(block.chainid));
        vm.writeFileBinary(path, abi.encode(deps));
        console2.log("Deployments saved to:", path);
    }

    function readL1Deployments(uint256 chainId) public view returns (AdapterDeployments memory) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/l1-adapter-", vm.toString(chainId));
        bytes memory data = vm.readFileBinary(path);
        return abi.decode(data, (AdapterDeployments));
    }

    function readL2Deployments(uint256 chainId) public view returns (AdapterDeployments memory) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/l2-adapter-", vm.toString(chainId));
        bytes memory data = vm.readFileBinary(path);
        return abi.decode(data, (AdapterDeployments));
    }
}
function newProxy(EmptyContract empty, address deployer, string memory name) returns (TransparentUpgradeableProxy) {
    return (new TransparentUpgradeableProxy){salt: keccak256(bytes(name))}(address(empty), address(deployer), "");
}

function upgradeToAndCall(
    ITransparentUpgradeableProxy proxy,
    address implementation,
    uint256 value,
    bytes memory data
) {
    proxy.upgradeToAndCall{value: value}(implementation, data);
}

function upgradeToAndCall(
    ITransparentUpgradeableProxy proxy,
    address implementation,
    bytes memory data
) {
    upgradeToAndCall(proxy, implementation, 0, data);
}

function deployEmptyContract() returns (EmptyContract) {
    bytes32 salt = keccak256(bytes("empty"));
    EmptyContract empty = new EmptyContract{salt: salt}();
    console2.log("empty contract address:", address(empty));
    return empty;
}

