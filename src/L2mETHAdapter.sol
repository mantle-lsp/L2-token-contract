// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { MintBurnOFTAdapterUpgradeable, IMintableBurnable } from "./MintBurnOFTAdapterUpgradeable.sol";

contract L2mETHAdapter is MintBurnOFTAdapterUpgradeable {
    // errors
    error UnexpectedInitializeParams();

    struct Init {
        address delegate;
        address owner;
    }

    constructor(
        address _token,
        IMintableBurnable _minterBurner,
        address _lzEndpoint
    ) MintBurnOFTAdapterUpgradeable(_token, _minterBurner, _lzEndpoint) {}

    function initialize(Init memory init) external initializer {
        if (init.delegate == address(0) || init.owner == address(0)) {
            revert UnexpectedInitializeParams();
        }
        // delegate can set config of OApp on endpoint
        __OFTAdapter_init(init.delegate);
        // owner can set peer
        __Ownable_init(init.owner);
    }
}
