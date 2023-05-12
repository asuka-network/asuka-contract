// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ICollectionFactory {
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

    function allowMintFree(address _token) external view returns (bool);
}

contract Collection is
    AccessControlEnumerableUpgradeable,
    ERC721EnumerableUpgradeable,
    ERC721BurnableUpgradeable,
    ERC721URIStorageUpgradeable
{
    using SafeERC20 for IERC20;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    event Initialized(string name, string symbol);

    uint256 public counter;

    ICollectionFactory public collectionFactory;

    modifier onlyMinter() {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "Collection: must have minter role"
        );
        _;
    }

    function initialize(
        address _creator,
        string memory _name,
        string memory _symbol,
        ICollectionFactory _fcollection
    ) public initializer {
        __ERC721_init(_name, _symbol);
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();

        collectionFactory = _fcollection;
        _setupRole(DEFAULT_ADMIN_ROLE, _creator);
        _setupRole(MINTER_ROLE, _creator);

        emit Initialized(_name, _symbol);
    }

    function mint(string memory uri) public {
        require(bytes(uri).length > 0, "Collection: uri is invalid");

        require(_allowMint(), "Collection: Dont have permission");

        uint256 id = ++counter;

        _chargeFeeMint(1);

        _mint(_msgSender(), id);

        _setTokenURI(id, uri);
    }

    function mintBatch(string[] memory uris) public {
        uint256 length = uris.length;

        require(length > 0, "Collection: array length is invalid");

        require(_allowMint(), "Collection: Dont have permission");

        _chargeFeeMint(length);

        address msgSender = _msgSender();

        uint256 id = counter;

        for (uint256 i = 0; i < length; i++) {
            require(bytes(uris[i]).length > 0, "Collection: uri is invalid");

            id++;

            _mint(msgSender, id);

            _setTokenURI(id, uris[i]);
        }

        counter = id;
    }

    function tokenURI(
        uint256 tokenId
    )
        public
        view
        virtual
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function _burn(
        uint256 tokenId
    )
        internal
        virtual
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        _burnReturn(1);
        super._burn(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    )
        internal
        virtual
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(
            AccessControlEnumerableUpgradeable,
            ERC721Upgradeable,
            ERC721EnumerableUpgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _allowMint() internal view returns (bool) {
        if (hasRole(MINTER_ROLE, _msgSender())) {
            return true;
        }

        return collectionFactory.allowMintFree(address(this));
    }

    function _chargeFeeMint(uint256 _amount) internal {
        uint fee = collectionFactory.mintFee(address(this), _amount);
        if (fee > 0) {
            IERC20(collectionFactory.asukaToken()).safeTransferFrom(
                _msgSender(),
                collectionFactory.treasury(),
                fee
            );
        }
    }

    function _burnReturn(uint256 _amount) internal {
        uint256 amount = collectionFactory.burnReturn(address(this), _amount);
        if (amount > 0) {
            IERC20(collectionFactory.asukaToken()).safeTransferFrom(
                collectionFactory.treasury(),
                _msgSender(),
                amount
            );
        }
    }
}
