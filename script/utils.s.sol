// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
/* solhint-disable no-console */

import {TimelockController} from "openzeppelin/governance/TimelockController.sol";
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import { BytesLib } from "solidity-bytes-utils/contracts/BytesLib.sol";

import {IOAppCore} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppCore.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import { ExecutorOptions } from "@layerzerolabs/lz-evm-protocol-v2/contracts/messagelib/libs/ExecutorOptions.sol";

import {IOFT, SendParam, MessagingFee, MessagingReceipt, OFTReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {EnforcedOptionParam, IOAppOptionsType3} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppOptionsType3.sol";

import "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";

import {IStatusWrite} from "../src/interfaces/IMessagingStatus.sol";
// import {L1MessagingStatus} from "../src/L1MessagingStatus.sol";
import {L2mETHAdapter} from "../src/L2mETHAdapter.sol";
import {L1mETHAdapter} from "../src/L1mETHAdapter.sol";
import {METHL2} from "../src/METHL2.sol";

import {console2 as console} from "forge-std/console2.sol";

import {Script} from "forge-std/Script.sol";

struct UlnConfig {
    uint64 confirmations;
    // we store the length of required DVNs and optional DVNs instead of using DVN.length directly to save gas
    uint8 requiredDVNCount; // 0 indicate DEFAULT, NIL_DVN_COUNT indicate NONE (to override the value of default)
    uint8 optionalDVNCount; // 0 indicate DEFAULT, NIL_DVN_COUNT indicate NONE (to override the value of default)
    uint8 optionalDVNThreshold; // (0, optionalDVNCount]
    address[] requiredDVNs; // no duplicates. sorted an an ascending order. allowed overlap with optionalDVNs
    address[] optionalDVNs; // no duplicates. sorted an an ascending order. allowed overlap with requiredDVNs
}

struct ExecutorConfig {
    uint32 maxMessageSize;
    address executor;
}

contract CalldataPrinter {
    string private _name;
    mapping(bytes4 => string) private _selectorNames;

    constructor(string memory name) {
        _name = name;
    }

    function setSelectorName(bytes4 selector, string memory name) external {
        _selectorNames[selector] = name;
    }

    fallback() external {
        console.log("Calldata to %s [%s]:", _name, _selectorNames[bytes4(msg.data[:4])]);
        console.logBytes(msg.data);
    }
}

contract Utils is Script {
    using OptionsBuilder for bytes;

    function sendL1(address oapp, uint32 eId, address recipient, uint256 amount, bool skipOption) public {
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        if (skipOption) {
            options = "";
        }
        bytes memory composeMsg = "";
        bytes memory oftCmd = "";

        SendParam memory sp = SendParam({
            dstEid: eId,
            to: bytes32(uint256(uint160(recipient))),
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: options,
            composeMsg: composeMsg,
            oftCmd: oftCmd
        });
        MessagingFee memory fee = IOFT(oapp).quoteSend(sp, false);

        vm.startBroadcast();
        (MessagingReceipt memory messagingRecept, OFTReceipt memory oftReceipt) = IOFT(oapp).send{value: fee.nativeFee}(sp, fee, msg.sender);
        vm.stopBroadcast();

        console.log("=============================");
        console.log("MessagingRecept");
        console.log("=============================");
        console.log("guid");
        console.logBytes32(messagingRecept.guid);
        console.log("nonce");
        console.log(messagingRecept.nonce);
        console.log("fee.nativeFee");
        console.log(messagingRecept.fee.nativeFee);
        console.log("fee.lzTokenFee");
        console.log(messagingRecept.fee.lzTokenFee);
        console.log();

        console.log("=============================");
        console.log("OFTReceipt");
        console.log("=============================");
        console.log("amountSentLD");
        console.log(oftReceipt.amountSentLD);
        console.log("amountReceivedLD");
        console.log(oftReceipt.amountReceivedLD);
        console.log();
    }

    function sendL2(address oapp, uint32 eId, address recipient, uint256 amount, bool skipOption) public {
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        if (skipOption) {
            options = "";
        }
        bytes memory composeMsg = "";
        bytes memory oftCmd = "";

        SendParam memory sp = SendParam({
            dstEid: eId,
            to: bytes32(uint256(uint160(recipient))),
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: options,
            composeMsg: composeMsg,
            oftCmd: oftCmd
        });
        MessagingFee memory fee = IOFT(oapp).quoteSend(sp, false);

        vm.startBroadcast();
        (MessagingReceipt memory messagingRecept, OFTReceipt memory oftReceipt) = IOFT(oapp).send{value: fee.nativeFee}(sp, fee, msg.sender);
        vm.stopBroadcast();

        console.log("=============================");
        console.log("MessagingRecept");
        console.log("=============================");
        console.log("guid");
        console.logBytes32(messagingRecept.guid);
        console.log("nonce");
        console.log(messagingRecept.nonce);
        console.log("fee.nativeFee");
        console.log(messagingRecept.fee.nativeFee);
        console.log("fee.lzTokenFee");
        console.log(messagingRecept.fee.lzTokenFee);
        console.log();

        console.log("=============================");
        console.log("OFTReceipt");
        console.log("=============================");
        console.log("amountSentLD");
        console.log(oftReceipt.amountSentLD);
        console.log("amountReceivedLD");
        console.log(oftReceipt.amountReceivedLD);
        console.log();
    }

    function setPeers(address sourceOApp, uint32[] memory eIds,  address[] memory oApps) public {
        require(eIds.length == oApps.length, "revert: setL1Peers params length not equal");
        vm.startBroadcast();
        for (uint256 i; i < eIds.length; i++) {
            IOAppCore(sourceOApp).setPeer(eIds[i], bytes32(uint256(uint160(oApps[i]))));
        }
        vm.stopBroadcast();
        // check peers
        for (uint256 i; i < eIds.length; i++) {
            require(IOAppCore(sourceOApp).peers(eIds[i]) == bytes32(uint256(uint160(oApps[i]))), "eid and oApp check failed");
        }
    }

    function setConfig(uint32 eid, uint64 confirmations, address oapp, address lib, address[] memory DVNs) public {
        // 0x1a44076050125825900e736c501f859c50fE728c Ethereum Mainnet Endpoint & Mantle Mainnet Endpoint
        // 0x6EDCE65403992e310A62460808c4b910D972f10f Ethereum Sepolia Endpoint & Mantle Sepolia Endpoint
        ILayerZeroEndpointV2 endpoint = ILayerZeroEndpointV2(vm.envAddress("LZ_ENDPOINT"));
        uint32 CONFIG_TYPE_ULN = 2;
        // config
        address[] memory requiredDVNs = new address[](DVNs.length); // place LZ DVN at start, switch to Mantle's in the future
        address[] memory optionalDVNs = new address[](0);
        for (uint256 i; i < DVNs.length; i++) {
            requiredDVNs[i] = DVNs[i];
        }
        UlnConfig memory config = UlnConfig({
            confirmations: confirmations,
            requiredDVNCount: uint8(requiredDVNs.length),
            requiredDVNs: requiredDVNs,
            optionalDVNThreshold: 0,
            optionalDVNCount: uint8(optionalDVNs.length),
            optionalDVNs: optionalDVNs
        });
        SetConfigParam memory scp = SetConfigParam({
            eid: eid,
            configType: CONFIG_TYPE_ULN,
            config: abi.encode(config)
        });
        SetConfigParam[] memory scps = new SetConfigParam[](1);
        scps[0] = scp;

        vm.startBroadcast();
        endpoint.setConfig(oapp, lib, scps);
        vm.stopBroadcast();
    }

    function getConfig(uint32 eid, address oapp, address lib) public view {
        ILayerZeroEndpointV2 endpoint = ILayerZeroEndpointV2(vm.envAddress("LZ_ENDPOINT"));
        uint32 CONFIG_TYPE_ULN = 2;

        bytes memory encodedData = endpoint.getConfig(oapp, lib, eid, CONFIG_TYPE_ULN);
        UlnConfig memory ulnConfig = abi.decode(encodedData, (UlnConfig));
        console.logBytes(encodedData);
        console.log("confirmations");
        console.log(ulnConfig.confirmations);
        console.log("requiredDVNCount");
        console.log(ulnConfig.requiredDVNCount);
        console.log("requiredDVNs (length: %s):", ulnConfig.requiredDVNs.length);
        for (uint256 i = 0; i < ulnConfig.requiredDVNs.length; i++) {
            console.log("    [%s]: %s", i, ulnConfig.requiredDVNs[i]);
        }
    }

    function setIsTransferPausedFor(address targetOApp, uint32 eId, bool isPaused) public {
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        (uint256 nativeFee, uint256 lzTokenFee) = IStatusWrite(targetOApp).quote(eId, abi.encode(block.timestamp, bytes4(keccak256("setIsTransferPaused(bool)")), isPaused), options);
        vm.startBroadcast();
        IStatusWrite(targetOApp).setIsTransferPausedFor{value: nativeFee}(eId, isPaused);
        vm.stopBroadcast();
    }

    function setExchangeRateFor(address targetOApp, uint32 eId, uint256 rate) public {
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        (uint256 nativeFee, uint256 lzTokenFee) = IStatusWrite(targetOApp).quote(eId, abi.encode(block.timestamp, bytes4(keccak256("setExchangeRateFor(uint256)")), rate), options);
        vm.startBroadcast();
        IStatusWrite(targetOApp).setExchangeRateFor{value: nativeFee}(eId, rate);
        vm.stopBroadcast();
    }

    function setEnableFor(address targetOApp, uint32 eId, bool enable) public {
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        (uint256 nativeFee, uint256 lzTokenFee) = IStatusWrite(targetOApp).quote(eId, abi.encode(block.timestamp, bytes4(keccak256("setEnableFor(bool)")), enable), options);
        vm.startBroadcast();
        IStatusWrite(targetOApp).setEnableFor{value: nativeFee}(eId, enable);
        vm.stopBroadcast();
    }

    function setCapFor(address targetOApp, uint32 eId, uint256 cap) public {
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        (uint256 nativeFee, uint256 lzTokenFee) = IStatusWrite(targetOApp).quote(eId, abi.encode(block.timestamp, bytes4(keccak256("setCapFor(uint256)")), cap), options);
        vm.startBroadcast();
        IStatusWrite(targetOApp).setCapFor{value: nativeFee}(eId, cap);
        vm.stopBroadcast();
    }

    function enforcedOptionsL1(address l1Adaptor, uint32 eId, uint16[] memory types, uint128[] memory gases) public {
        require(types.length == gases.length, "Types and Gases arrays must be same length");
        EnforcedOptionParam[] memory aEnforcedOptions = new EnforcedOptionParam[](types.length);

        // Loop through the arrays to construct options
        for (uint i = 0; i < types.length; i++) {
            aEnforcedOptions[i] = EnforcedOptionParam({
                eid: eId,
                msgType: types[i],
                options: OptionsBuilder.newOptions().addExecutorLzReceiveOption(
                    gases[i],
                    0  // msg.value
                )
            });
        }
        console.log("oApp address");
        console.log(address(l1Adaptor));
        console.log("-----------------------------");
        console.log("params");
        console.logBytes(abi.encodeWithSelector(IOAppOptionsType3(l1Adaptor).setEnforcedOptions.selector, aEnforcedOptions));
        console.log("-----------------------------");
        vm.startBroadcast();
        IOAppOptionsType3(l1Adaptor).setEnforcedOptions(aEnforcedOptions);
        vm.stopBroadcast();
    }

    function enforcedOptionsL2(address oapp, uint32 eId, uint16[] memory types, uint128[] memory gases) public {
        require(types.length == gases.length, "Types and Gases arrays must be same length");

        EnforcedOptionParam[] memory aEnforcedOptions = new EnforcedOptionParam[](types.length);

        // Loop through the arrays to construct options
        for (uint i = 0; i < types.length; i++) {
            aEnforcedOptions[i] = EnforcedOptionParam({
                eid: eId,
                msgType: types[i],
                options: OptionsBuilder.newOptions().addExecutorLzReceiveOption(
                    gases[i],
                    0  // msg.value
                )
            });
        }
        console.log("oApp address");
        console.log(address(oapp));
        console.log("-----------------------------");
        console.log("params");
        console.logBytes(abi.encodeWithSelector(IOAppOptionsType3(oapp).setEnforcedOptions.selector, aEnforcedOptions));
        console.log("-----------------------------");
        vm.startBroadcast();
        IOAppOptionsType3(oapp).setEnforcedOptions(aEnforcedOptions);
        vm.stopBroadcast();
    }

    function parseOptions(bytes memory _abiEncodedOptions) public pure returns(bytes memory data) {
        bytes memory enforcedOptions = abi.decode(_abiEncodedOptions, (bytes));

        require(BytesLib.toUint16(enforcedOptions, 0) == 3, "Invalid options type");

        uint256 position = 2; // skip first 2 bytes(type 3)
        while (position < enforcedOptions.length) {
            // need to equal with ExecutorOptions.WORKER_ID = 1
            uint8 workerId = BytesLib.toUint8(enforcedOptions, position);
            position += 1;

            // get block length
            uint16 blockLength = BytesLib.toUint16(enforcedOptions, position);
            position += 2;

            // need to equal with ExecutorOptions.OPTION_TYPE_LZRECEIVE = 1
            uint8 optionType = BytesLib.toUint8(enforcedOptions, position);
            position += 1;

            // Extract option data (length = blockLength - 1, because blockLength includes 1 byte of optionType)
            data = BytesLib.slice(enforcedOptions, position, blockLength - 1);
            position += blockLength - 1;

            console.log("-------------workerId----------------");
            console.log(workerId);
            console.log("--------------optionType---------------");
            console.log(optionType);
            console.log("--------------data---------------");
            console.logBytes(data);
        }
    }
    function decodeLzReceiveOption(bytes calldata data) public pure {
        (uint128 gas, uint128 value) = ExecutorOptions.decodeLzReceiveOption(data);
        console.log("-------------gas----------------");
        console.log(gas);
        console.log("--------------value---------------");
        console.log(value);
    }
}
