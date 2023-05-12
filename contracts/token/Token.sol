// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ITokenFactory {
    function treasury() external view returns (address);

    function asukaToken() external view returns (address);

    function mintFee(
        address _token,
        uint256 _amount
    ) external view returns (uint256);

    function burnReturn(
        address _token,
        uint256 _amount
    ) external view returns (uint256);
}

contract Token is AccessControlEnumerableUpgradeable, ERC20BurnableUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    event Initialized(string name, string symbol);

    ITokenFactory public tokenFactory;

    modifier onlyMinter() {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "Token: must have minter role"
        );
        _;
    }

    function initialize(
        address _creator,
        string memory _name,
        string memory _symbol,
        ITokenFactory _tokenFactory
    ) public initializer {
        __ERC20_init(_name, _symbol);
        __ERC20Burnable_init();
        __AccessControl_init();
        __AccessControlEnumerable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _creator);
        _setupRole(MINTER_ROLE, _creator);

        tokenFactory = _tokenFactory;

        emit Initialized(_name, _symbol);
    }

    function mint(address _to, uint256 _amount) external onlyMinter {
        _chargeFeeMint(_amount);
        _mint(_to, _amount);
    }

    function _burn(
        address _account,
        uint256 _amount
    ) internal virtual override(ERC20Upgradeable) {
        _burnReturn(_amount);
        super._burn(_account, _amount);
    }

    function _chargeFeeMint(uint256 _amount) internal {
        uint fee = tokenFactory.mintFee(address(this), _amount);
        if (fee > 0) {
            IERC20(tokenFactory.asukaToken()).safeTransferFrom(
                _msgSender(),
                tokenFactory.treasury(),
                fee
            );
        }
    }

    function _burnReturn(uint256 _amount) internal {
        uint256 amount = tokenFactory.burnReturn(address(this), _amount);
        if (amount > 0) {
            IERC20(tokenFactory.asukaToken()).safeTransferFrom(
                tokenFactory.treasury(),
                _msgSender(),
                amount
            );
        }
    }
}
