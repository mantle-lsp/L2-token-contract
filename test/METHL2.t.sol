// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {METHL2} from "../src/METHL2.sol";
import {IBlockList} from "../src/interfaces/IBlockList.sol";

import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {TimelockController} from "openzeppelin/governance/TimelockController.sol";

contract METHL2Test is Test {
    address public immutable l1TokenAddress = makeAddr("l1Token");
    address public immutable l2BridgeAddress = makeAddr("l2Bridge");
    address public immutable adminAddress = makeAddr("admin");
    address public immutable addBlockListContractAccount = makeAddr("addBlockListContract");
    address public immutable removeBlockListContractAccount = makeAddr("removeBlockListContract");

    TimelockController public proxyAdmin;
    METHL2 public mETHL2;
    METHL2 public implementationContract;

    function setUp() public virtual {
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

contract MockBlockList is IBlockList {
    mapping(address => bool) private _blockedAccounts;

    function setBlocked(address account, bool blocked) public {
        _blockedAccounts[account] = blocked;
    }

    function isBlocked(address account) external view override returns (bool) {
        return _blockedAccounts[account];
    }
}

contract METHL2BlockListTest is METHL2Test {
    address public blockedUser = makeAddr("blockedUser");
    address public normalUser = makeAddr("normalUser");
    address public normalUser2 = makeAddr("normalUser2");
    uint256 public amount = 100 ether;
    MockBlockList public blockList;
    MockBlockList public blockList2;
    MockBlockList public dummyBlockList;

    function setUp() public override {
        super.setUp();

        bytes32 addBlockListContractRole = mETHL2.ADD_BLOCK_LIST_CONTRACT_ROLE();
        vm.prank(adminAddress);
        mETHL2.grantRole(addBlockListContractRole, addBlockListContractAccount);
        bytes32 removeBlockListContractRole = mETHL2.REMOVE_BLOCK_LIST_CONTRACT_ROLE();
        vm.prank(adminAddress);
        mETHL2.grantRole(removeBlockListContractRole, removeBlockListContractAccount);

        dummyBlockList = new MockBlockList();
        vm.prank(addBlockListContractAccount);
        mETHL2.addBlockListContract(address(dummyBlockList));

        vm.prank(l2BridgeAddress);
        mETHL2.mint(blockedUser, amount);
        vm.prank(l2BridgeAddress);
        mETHL2.mint(normalUser, amount);
        vm.prank(l2BridgeAddress);
        mETHL2.mint(normalUser2, amount);
        
        blockList = new MockBlockList();
        blockList2 = new MockBlockList();
    }

    function testGetBlockLists() public view {
        address[] memory b = mETHL2.getBlockLists();
        assert(b.length == 1);
        assert(b[0] == address(dummyBlockList));
    }

    function testNormalUserCannotSetBlockList() public {
        vm.prank(blockedUser);
        vm.expectRevert("AccessControl: account 0x701fb51cd343c6a358dcd69a9b90d1024d3c11c5 is missing role 0xd3d225be1126d845fcf8733ea56e6e51b96ef5190bf72aae9f96e0bef924e437");
        mETHL2.addBlockListContract(address(blockList));
        vm.prank(adminAddress);
        vm.expectRevert("AccessControl: account 0xaa10a84ce7d9ae517a52c6d5ca153b369af99ecf is missing role 0xd3d225be1126d845fcf8733ea56e6e51b96ef5190bf72aae9f96e0bef924e437");
        mETHL2.addBlockListContract(address(blockList));
        blockList.setBlocked(blockedUser, true);
    }

    function testNormalUserCannotRemoveBlockList() public {
        vm.prank(addBlockListContractAccount);
        mETHL2.addBlockListContract(address(blockList));
        vm.prank(adminAddress);
        vm.expectRevert("AccessControl: account 0xaa10a84ce7d9ae517a52c6d5ca153b369af99ecf is missing role 0xa7e5f4407fb7a6903f54f2279f3aefe796f21c33a3ea2caae0d0150b895a61a9");
        mETHL2.removeBlockListContract(address(blockList));
    }

    function testBlockedUserCannotTransfer() public {
        // Set the blockList contract
        vm.prank(addBlockListContractAccount);
        mETHL2.addBlockListContract(address(blockList));
        vm.prank(addBlockListContractAccount);
        mETHL2.addBlockListContract(address(blockList2));
        blockList.setBlocked(blockedUser, true);

        address[] memory blockLists = mETHL2.getBlockLists();
        assertEq(blockLists.length, 3);
        assertEq(blockLists[1], address(blockList));
        assertEq(blockLists[2], address(blockList2));

        // Attempt to transfer tokens from the blocked user
        vm.prank(blockedUser);
        vm.expectRevert("mETH: 'sender' address blocked");
        mETHL2.transfer(normalUser, amount);

        vm.prank(blockedUser);
        mETHL2.approve(normalUser2, amount);
        vm.prank(normalUser2);
        vm.expectRevert("mETH: 'from' address blocked");
        mETHL2.transferFrom(blockedUser, normalUser, amount);

        // Attempt to transfer tokens to the blocked user
        vm.prank(normalUser);
        vm.expectRevert("mETH: 'to' address blocked");
        mETHL2.transfer(blockedUser, amount);

        // can transfer when block list contract removed
        vm.prank(removeBlockListContractAccount);
        mETHL2.removeBlockListContract(address(blockList));
        vm.prank(normalUser);
        mETHL2.transfer(blockedUser, amount);

        blockLists = mETHL2.getBlockLists();
        assertEq(blockLists.length, 2);
        assertEq(blockLists[1], address(blockList2));
    }

    function testNormalUserCanTransfer() public {
        // Can transfer when the blockList contract is not set
        vm.prank(blockedUser);
        mETHL2.transfer(normalUser, amount);
        vm.prank(normalUser);
        mETHL2.transfer(blockedUser, amount);

        // Set the blockList contract
        vm.prank(addBlockListContractAccount);
        mETHL2.addBlockListContract(address(blockList));
        blockList.setBlocked(blockedUser, true);

        // Transfer tokens from the normal user
        vm.prank(normalUser);
        mETHL2.transfer(normalUser2, amount);

        // Check the balances to ensure the transfer was successful
        assertEq(mETHL2.balanceOf(normalUser), 0 ether);
        assertEq(mETHL2.balanceOf(normalUser2), amount * 2);
    }

    function testRejectInvalidBlockListContract() public {
        vm.expectRevert("Invalid block list contract");
        vm.prank(addBlockListContractAccount);
        mETHL2.addBlockListContract(address(6));
    }
}

// In practice there may be no need for a standalone Rescuer contract
contract MockRescuer {
    METHL2 mETHL2;
    constructor(address mETHAddress) {
        mETHL2 = METHL2(mETHAddress);
    }
    function forceMint(address account, uint256 amount, bool excludeBlockList) external {
        mETHL2.forceMint(account, amount, excludeBlockList);
    }
    function forceBurn(address account, uint256 amount) external {
        mETHL2.forceBurn(account, amount);
    }
}

contract METHL2ForceMintBurnTest is METHL2Test {
    MockRescuer rescuer;
    address user = makeAddr("user");

    function setUp() public override {
        super.setUp();
        rescuer = new MockRescuer(address(mETHL2));

        bytes32 addBlockListContractRole = mETHL2.ADD_BLOCK_LIST_CONTRACT_ROLE();
        vm.prank(adminAddress);
        mETHL2.grantRole(addBlockListContractRole, addBlockListContractAccount);
        bytes32 removeBlockListContractRole = mETHL2.REMOVE_BLOCK_LIST_CONTRACT_ROLE();
        vm.prank(adminAddress);
        mETHL2.grantRole(removeBlockListContractRole, removeBlockListContractAccount);

    }

    function testOrdinaryAccountCannotForceMintBurn() public {
        vm.expectRevert("AccessControl: account 0x5991a2df15a8f6a256d3ec51e99254cd3fb576a9 is missing role 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6");
        rescuer.forceMint(user, 233, false);
        vm.expectRevert("AccessControl: account 0x5991a2df15a8f6a256d3ec51e99254cd3fb576a9 is missing role 0x3c11d16cbaffd01df69ce1c404f6340ee057498f5f00246190ea54220576a848");
        rescuer.forceBurn(user, 133);
    }

    function testForceMintBurn() public {
        bytes32 minterRole = mETHL2.MINTER_ROLE();
        vm.prank(mETHL2.getRoleMember(mETHL2.DEFAULT_ADMIN_ROLE(), 0));
        mETHL2.grantRole(minterRole, address(rescuer));
        vm.prank(address(rescuer));
        rescuer.forceMint(user, 233, false);

        bytes32 burnerRole = mETHL2.BURNER_ROLE();
        vm.prank(mETHL2.getRoleMember(mETHL2.DEFAULT_ADMIN_ROLE(), 0));
        mETHL2.grantRole(burnerRole, address(rescuer));
        assert(mETHL2.balanceOf(user) == 233);
        vm.prank(address(rescuer));
        rescuer.forceBurn(user, 133);
        assert(mETHL2.balanceOf(user) == 100);
    }

    function testForceMintForBlockedAccount() public {
        bytes32 minterRole = mETHL2.MINTER_ROLE();
        vm.prank(mETHL2.getRoleMember(mETHL2.DEFAULT_ADMIN_ROLE(), 0));
        mETHL2.grantRole(minterRole, address(rescuer));

        vm.prank(address(rescuer));
        rescuer.forceMint(user, 233, true);
        assertEq(mETHL2.balanceOf(user), 233);

        MockBlockList blockList = new MockBlockList();
        vm.prank(addBlockListContractAccount);
        mETHL2.addBlockListContract(address(blockList));
        blockList.setBlocked(user, true);

        vm.expectRevert("0x6ca6d1e2d5347bfab1d91e883f1915560e09129d is in block list");
        vm.prank(address(rescuer));
        rescuer.forceMint(user, 233, true);
        assertEq(mETHL2.balanceOf(user), 233);

        rescuer.forceMint(user, 233, false);
        assertEq(mETHL2.balanceOf(user), 466);
    }
}
