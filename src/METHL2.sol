// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {EnumerableSet} from "openzeppelin/utils/structs/EnumerableSet.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {Initializable} from "openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlEnumerableUpgradeable} from
    "openzeppelin-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import {AccessControlEnumerable} from "openzeppelin/access/AccessControlEnumerable.sol";
import {
    ERC20PermitUpgradeable,
    IERC20PermitUpgradeable
} from "openzeppelin-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {IERC165Upgradeable} from "openzeppelin-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import {IBlockList} from "./interfaces/IBlockList.sol";
import {IL2UpgradablePermitERC20} from "./interfaces/IL2UpgradablePermitERC20.sol";

contract METHL2 is
    Initializable,
    AccessControlEnumerableUpgradeable,
    ERC20PermitUpgradeable,
    IL2UpgradablePermitERC20
{
    bytes32 public constant ADD_BLOCK_LIST_CONTRACT_ROLE = keccak256("ADD_BLOCK_LIST_CONTRACT_ROLE");
    bytes32 public constant REMOVE_BLOCK_LIST_CONTRACT_ROLE = keccak256("REMOVE_BLOCK_LIST_CONTRACT_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    address public l1Token;
    address public l2Bridge;
    uint8 internal decimal;

    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _blockListContracts;
    event BlockListContractAdded(address indexed blockList);
    event BlockListContractRemoved(address indexed blockList);
    
    event NonceUsed(address indexed owner, uint256 nonce);

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

    function forceMint(address account, uint256 amount, bool excludeBlockList) external onlyRole(MINTER_ROLE) {
        if (excludeBlockList) {
            require(!isBlocked(account), string(abi.encodePacked(Strings.toHexString(uint160(account), 20), " is in block list")));
        }
        _mint(account, amount);        
    }

    function forceBurn(address account, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(account, amount);
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
    function useNonce() external virtual returns (uint256 nonce) {
        nonce = _useNonce(_msgSender());
        emit NonceUsed(_msgSender(), nonce);
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

    function isBlocked(address account) public view returns (bool) {
        uint256 length = EnumerableSet.length(_blockListContracts);
        for (uint256 i = 0; i < length; i++) {
            if (IBlockList(EnumerableSet.at(_blockListContracts, i)).isBlocked(account)) {
                return true;
            }
        }
        return false;
    }

    modifier notBlocked(address from, address to) {
        require(!isBlocked(msg.sender), "mETH: 'sender' address blocked");
        require(!isBlocked(from), "mETH: 'from' address blocked");
        require(!isBlocked(to), "mETH: 'to' address blocked");
        _;
    }

    function _transfer(address from, address to, uint256 amount) internal override notBlocked(from, to) {
        return super._transfer(from, to, amount);
    }

    function addBlockListContract(address blockListAddress) external onlyRole(ADD_BLOCK_LIST_CONTRACT_ROLE) {
        (bool success, ) = blockListAddress.call(abi.encodeWithSignature("isBlocked(address)", address(0)));
        require(success, "Invalid block list contract");
        require(EnumerableSet.add(_blockListContracts, blockListAddress), "Already added");
        emit BlockListContractAdded(blockListAddress);
    }

    function removeBlockListContract(address blockListAddress) external onlyRole(REMOVE_BLOCK_LIST_CONTRACT_ROLE) {
        require(EnumerableSet.remove(_blockListContracts, blockListAddress), "Not added");
        emit BlockListContractRemoved(blockListAddress);
    }

    function getBlockLists() external view returns (address[] memory) {
        return _blockListContracts.values();
    }
}
