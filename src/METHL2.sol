// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Initializable} from "openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlEnumerableUpgradeable} from
    "openzeppelin-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import {AccessControlEnumerable} from "openzeppelin/access/AccessControlEnumerable.sol";
import {
    ERC20PermitUpgradeable,
    IERC20PermitUpgradeable
} from "openzeppelin-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {IERC165Upgradeable} from "openzeppelin-upgradeable/utils/introspection/IERC165Upgradeable.sol";

import {IL2UpgradablePermitERC20} from "./interfaces/IL2UpgradablePermitERC20.sol";

contract METHL2 is
    Initializable,
    AccessControlEnumerableUpgradeable,
    ERC20PermitUpgradeable,
    IL2UpgradablePermitERC20
{
    address public l1Token;
    address public l2Bridge;
    uint8 internal decimal;

    modifier onlyL2Bridge() {
        require(msg.sender == l2Bridge, "Only L2 Bridge can mint and burn");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    /// @notice Inititalizes the contract.
    /// @dev MUST be called during the contract upgrade to set up the proxies state.
    function initialize(address _l2Bridge, address _l1Token, address _admin) external initializer {
        __AccessControlEnumerable_init();
        __ERC20_init("mETH", "mETH");
        __ERC20Permit_init("mETH");

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);

        l1Token = _l1Token;
        l2Bridge = _l2Bridge;

        decimal = 18;
    }

    // @dev used by L2Bridge to mint tokens on L2

    function mint(address _to, uint256 _amount) public virtual onlyL2Bridge {
        _mint(_to, _amount);

        emit Mint(_to, _amount);
    }

    // @dev used by L2Bridge to burn tokens on L2
    function burn(address _from, uint256 _amount) public virtual onlyL2Bridge {
        _burn(_from, _amount);

        emit Burn(_from, _amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return decimal;
    }

    /**
     * @dev See {IERC20Permit-nonces}.
     */
    function nonces(address owner)
        public
        view
        virtual
        override(ERC20PermitUpgradeable, IERC20PermitUpgradeable)
        returns (uint256)
    {
        return ERC20PermitUpgradeable.nonces(owner);
    }

    // @dev used to consume a nonce so that the user is able to invalidate a signature. Returns the current value and
    // increments.
    function useNonce() external virtual returns (uint256) {
        return ERC20PermitUpgradeable._useNonce(_msgSender());
    }

    function supportsInterface(bytes4 _interfaceId)
        public
        pure
        override(AccessControlEnumerableUpgradeable, IERC165Upgradeable)
        returns (bool)
    {
        bytes4 firstSupportedInterface = type(IERC165Upgradeable).interfaceId; // IERC165Upgradeable
        bytes4 secondSupportedInterface = IL2UpgradablePermitERC20.l1Token.selector
            ^ IL2UpgradablePermitERC20.mint.selector ^ IL2UpgradablePermitERC20.burn.selector;
        bytes4 thirdSupportedInterface = type(AccessControlEnumerableUpgradeable).interfaceId; // AccessControlEnumerableUpgradeable
        return _interfaceId == firstSupportedInterface || _interfaceId == secondSupportedInterface
            || _interfaceId == thirdSupportedInterface;
    }
}
