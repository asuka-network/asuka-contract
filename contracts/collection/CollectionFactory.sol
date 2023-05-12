// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "../utils/Signature.sol";

interface ICollection {
    function initialize(
        address _creator,
        string memory _name,
        string memory _symbol,
        address _fcollection
    ) external;
}

contract CollectionFactory is AccessControlEnumerableUpgradeable {
    using ClonesUpgradeable for address;
    using Signature for bytes32;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    event CollectionLogicUpdated(address addr);
    event CollectionCreated(
        string id,
        address owner,
        address token,
        uint256 mintFeeAmount,
        uint256 burnReturnAmount,
        bool feePerNft,
        bool allowMintFree
    );

    event CollectionUpdated(
        address token,
        uint256 mintFeeAmount,
        uint256 burnReturnAmount,
        bool feePerNft,
        bool allowMintFree
    );

    struct TokenInfo {
        address owner;
        uint256 mintFeeAmount;
        uint256 burnReturnAmount;
        bool feePerNft;
        bool allowMintFree;
    }

    address public treasury;

    address public collectionLogic;

    address public asukaToken;

    mapping(address => TokenInfo) public tokenInfos;

    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "CollectionFactory: Must Have Admin Role"
        );
        _;
    }

    modifier onlyOperator() {
        require(
            hasRole(OPERATOR_ROLE, _msgSender()),
            "CollectionFactory: Must Have Operator Role"
        );
        _;
    }

    function initialize(
        address _asukaToken,
        address _treasury,
        address _logic
    ) external initializer {
        __AccessControlEnumerable_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(OPERATOR_ROLE, _msgSender());
        _setupRole(SIGNER_ROLE, _msgSender());
        asukaToken = _asukaToken;
        treasury = _treasury;
        collectionLogic = _logic;
    }

    function setCollectionLogic(address _logic) external onlyOperator {
        require(_logic != address(0), "CollectionFactory: address is invalid");
        collectionLogic = _logic;
        emit CollectionLogicUpdated(_logic);
    }

    function setTreasury(address _treasury) external onlyAdmin {
        require(
            _treasury != address(0),
            "CollectionFactory: address is invalid"
        );
        treasury = _treasury;
    }

    function setAsukaToken(address _asukaToken) external onlyAdmin {
        require(
            _asukaToken != address(0),
            "CollectionFactory: address is invalid"
        );
        asukaToken = _asukaToken;
    }

    function createCollection(
        string calldata _id,
        string calldata _name,
        string calldata _symbol,
        uint256 _mintFeeAmount,
        uint256 _burnReturnAmount,
        bool _feePerNft,
        bool _allowMintFree,
        bytes calldata _signature
    ) external {
        address sender = _msgSender();

        require(
            collectionLogic != address(0),
            "CollectionFactory: logic is invalid"
        );

        _verifySignature(
            keccak256(abi.encodePacked(_msgSender(), _id)),
            _signature
        );

        address collection = collectionLogic.clone();

        ICollection(collection).initialize(
            _msgSender(),
            _name,
            _symbol,
            address(this)
        );

        tokenInfos[collection] = TokenInfo(
            sender,
            _mintFeeAmount,
            _burnReturnAmount,
            _feePerNft,
            _allowMintFree
        );

        emit CollectionCreated(
            _id,
            sender,
            collection,
            _mintFeeAmount,
            _burnReturnAmount,
            _feePerNft,
            _allowMintFree
        );
    }

    function setToken(
        address _token,
        uint256 _mintFeeAmount,
        uint256 _burnReturnAmount,
        bool _feePerNft,
        bool _allowMintFree
    ) public {
        address sender = _msgSender();

        TokenInfo storage tokenInfo = tokenInfos[_token];

        require(tokenInfo.owner == sender, "CollectionFactory: Must be owner");

        tokenInfo.mintFeeAmount = _mintFeeAmount;
        tokenInfo.burnReturnAmount = _burnReturnAmount;
        tokenInfo.allowMintFree = _allowMintFree;
        tokenInfo.feePerNft = _feePerNft;

        emit CollectionUpdated(
            _token,
            _mintFeeAmount,
            _burnReturnAmount,
            _feePerNft,
            _allowMintFree
        );
    }

    function mintFee(
        address _token,
        uint256 _amount
    ) public view returns (uint256) {
        TokenInfo memory tokenInfo = tokenInfos[_token];

        if (tokenInfo.owner == address(0)) {
            return 0;
        }

        if (tokenInfo.feePerNft) {
            return tokenInfo.mintFeeAmount * _amount;
        }

        return tokenInfo.mintFeeAmount;
    }

    function burnReturn(
        address _token,
        uint256 _amount
    ) public view returns (uint256) {
        TokenInfo memory tokenInfo = tokenInfos[_token];

        if (tokenInfo.owner == address(0)) {
            return 0;
        }

        if (tokenInfo.feePerNft) {
            return tokenInfo.burnReturnAmount * _amount;
        }

        return tokenInfo.burnReturnAmount;
    }

    function allowMintFree(address _token) public view returns (bool) {
        TokenInfo memory tokenInfo = tokenInfos[_token];

        if (tokenInfo.owner == address(0)) {
            return false;
        }

        return tokenInfo.allowMintFree;
    }

    function _verifySignature(
        bytes32 _messageHash,
        bytes memory _signature
    ) internal view {
        bytes32 prefixed = _messageHash.prefixed();
        address singer = prefixed.recoverSigner(_signature);

        require(
            hasRole(SIGNER_ROLE, singer),
            "CollectionFactory: Signature invalid"
        );
    }
}
