// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Upgradeable} from "openzeppelin-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC20PermitUpgradeable} from "openzeppelin-upgradeable/token/ERC20/extensions/IERC20PermitUpgradeable.sol";
import {IERC165Upgradeable} from "openzeppelin-upgradeable/utils/introspection/IERC165Upgradeable.sol";

interface IL2UpgradablePermitERC20 is IERC20Upgradeable, IERC20PermitUpgradeable, IERC165Upgradeable {
    function l1Token() external returns (address);

    function mint(address _to, uint256 _amount) external;

    function burn(address _from, uint256 _amount) external;

    event Mint(address indexed _account, uint256 _amount);
    event Burn(address indexed _account, uint256 _amount);
}
