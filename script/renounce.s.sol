pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {L1mETHAdapter} from "../src/L1mETHAdapter.sol";
import {L2mETHAdapter} from "../src/L2mETHAdapter.sol";
import {EndpointV2} from "../test/MockEndpoint.sol";

abstract contract Addresses {
    address public constant MLSPSecL1_8203 = 0x849738999Ba1F3D995d28bDB35efA2E47B4c8203;
    address public constant MLSPSecL2_5037 = 0x71a1f9186C381265c736544b70A24E23deCa5037;

    address public constant L1mETHAdapterContract = 0x4f24535e67EbBDB274a1a7AA3E33339E05F0E46d;
    address public constant L2mETHAdapterContract = 0x4f24535e67EbBDB274a1a7AA3E33339E05F0E46d;
    address public constant EndPointAddress = 0x1a44076050125825900e736c501f859c50fE728c;
}

contract RenounceMETH is Addresses, Script {
  function run() public {
    vm.startBroadcast();
    if (block.chainid == 1) {
      // ----- L1mETHAdapter -----//
      // Check Delegator and transfer if necessary
      if (EndpointV2(EndPointAddress).delegates(L1mETHAdapterContract) != MLSPSecL1_8203) {
          L1mETHAdapter(L1mETHAdapterContract).setDelegate(MLSPSecL1_8203);
      }
      require(EndpointV2(EndPointAddress).delegates(L1mETHAdapterContract) == MLSPSecL1_8203, "Error: L1mETHAdapterContract Delegator should be MLSPSecL1_8203");

      // Check Owner and transfer if necessary
      if (L1mETHAdapter(L1mETHAdapterContract).owner() != MLSPSecL1_8203) {
          L1mETHAdapter(L1mETHAdapterContract).transferOwnership(MLSPSecL1_8203);
      }
      require(L1mETHAdapter(L1mETHAdapterContract).owner() == MLSPSecL1_8203, "Error: L1mETHAdapter Owner should be MLSPSecL1_8203");
    }

    if (block.chainid == 5000) {
      // ----- L2mETHAdapter -----//
      // Check Delegator and transfer if necessary
      if (EndpointV2(EndPointAddress).delegates(L2mETHAdapterContract) != MLSPSecL2_5037) {
          L2mETHAdapter(L2mETHAdapterContract).setDelegate(MLSPSecL2_5037);
      }
      require(EndpointV2(EndPointAddress).delegates(L2mETHAdapterContract) == MLSPSecL2_5037, "Error: L2mETHAdapterContract Delegator should be MLSPSecL2_5037");

      // Check Owner and transfer if necessary
      if (L2mETHAdapter(L2mETHAdapterContract).owner() != MLSPSecL2_5037) {
          L2mETHAdapter(L2mETHAdapterContract).transferOwnership(MLSPSecL2_5037);
      }
      require(L2mETHAdapter(L2mETHAdapterContract).owner() == MLSPSecL2_5037, "Error: L2mETHAdapter Owner should be MLSPSecL2_5037");
    }
    vm.stopBroadcast();
  }
}