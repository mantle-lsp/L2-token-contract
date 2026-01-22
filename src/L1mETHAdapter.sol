// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {OFTAdapterUpgradeable} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTAdapterUpgradeable.sol";
import {ProtocolEvents} from "./interfaces/ProtocolEvents.sol";

contract L1mETHAdapter is
    ProtocolEvents,
    OFTAdapterUpgradeable
{
    // errors
    error UnexpectedInitializeParams();

    struct Init {
        address delegate;
        address owner;
    }

    // @dev _token is the proxy address of L1cmETH
    constructor(address _token, address _lzEndpoint) OFTAdapterUpgradeable(_token, _lzEndpoint) {}

    /**
     * @dev Initializes the OFTAdapter.
     * @dev The delegate typically should be set as the admin of the contract.
     * @dev Ownable is not initialized here on purpose. It should be initialized in the child contract to
     * accommodate the different version of Ownable.
     */
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
