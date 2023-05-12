// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "../utils/Signature.sol";

interface IToken {
    function initialize(
        address _creator,
        string memory _name,
        string memory _symbol,
        address _tokenFactory
    ) external;
}

contract TokenFactory is AccessControlEnumerableUpgradeable {
    using ClonesUpgradeable for address;
    using Signature for bytes32;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    uint256 public constant MULTIPLIER = 1e4;

    event TokenLogicUpdated(address addressToken);
    event TokenCreated(
        string id,
        address owner,
        address token,
        uint256 mintFee,
        uint256 burnReturn
    );
    event TokenUpdated(address token, uint256 mintFee, uint256 burnReturn);

    struct TokenInfo {
        address owner;
        uint256 mintFee;
        uint256 burnReturn;
    }

    address public treasury;

    address public tokenLogic;

    address public asukaToken;

    mapping(address => TokenInfo) public tokenInfos;

    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "TokenFactory: Must Have Admin Role"
        );
        _;
    }

    modifier onlyOperator() {
        require(
            hasRole(OPERATOR_ROLE, _msgSender()),
            "TokenFactory: Must Have Operator Role"
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
        tokenLogic = _logic;
    }

    function setTokenLogic(address _logic) external onlyOperator {
        require(_logic != address(0), "TokenFactory: address is invalid");
        tokenLogic = _logic;
        emit TokenLogicUpdated(_logic);
    }

    function setAsukaToken(address _asukaToken) external onlyAdmin {
        require(_asukaToken != address(0), "TokenFactory: address is invalid");
        asukaToken = _asukaToken;
    }

    function setTreasury(address _treasury) external onlyAdmin {
        require(_treasury != address(0), "TokenFactory: address is invalid");
        treasury = _treasury;
    }

    function createToken(
        string calldata _id,
        string calldata _name,
        string calldata _symbol,
        uint256 _mintFee,
        uint256 _burnReturn,
        bytes calldata _signature
    ) external {
        address sender = _msgSender();
        require(tokenLogic != address(0), "TokenFactory: logic is invalid");

        _verifySignature(keccak256(abi.encodePacked(sender, _id)), _signature);

        address token = tokenLogic.clone();

        IToken(token).initialize(sender, _name, _symbol, address(this));

        tokenInfos[token] = TokenInfo(sender, _mintFee, _burnReturn);

        emit TokenCreated(_id, sender, token, _mintFee, _burnReturn);
    }

    function setToken(
        address _token,
        uint256 _mintFee,
        uint256 _burnReturn
    ) public {
        address sender = _msgSender();

        TokenInfo storage tokenInfo = tokenInfos[_token];

        require(tokenInfo.owner == sender, "TokenFactory: Must be owner");

        tokenInfo.mintFee = _mintFee;
        tokenInfo.burnReturn = _burnReturn;

        emit TokenUpdated(_token, _mintFee, _burnReturn);
    }

    /**
       unit fee is asuka token
     */
    function mintFee(
        address _token,
        uint256 _amount
    ) public view returns (uint256) {
        TokenInfo memory tokenInfo = tokenInfos[_token];

        if (tokenInfo.owner == address(0)) {
            return 0;
        }

        return (tokenInfo.mintFee * _amount);
    }

    function burnReturn(
        address _token,
        uint256 _amount
    ) public view returns (uint256) {
        TokenInfo memory tokenInfo = tokenInfos[_token];

        if (tokenInfo.owner == address(0)) {
            return 0;
        }

        return (tokenInfo.burnReturn * _amount);
    }

    function _verifySignature(
        bytes32 _messageHash,
        bytes memory _signature
    ) internal view {
        bytes32 prefixed = _messageHash.prefixed();
        address singer = prefixed.recoverSigner(_signature);

        require(
            hasRole(SIGNER_ROLE, singer),
            "TokenFactory: Signature invalid"
        );
    }
}
