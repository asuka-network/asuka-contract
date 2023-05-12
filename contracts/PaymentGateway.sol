// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PaymentGateway is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;

    struct GameDeposit {
        address receivePayment;
        uint256 protocolFee;
        bool enabled;
    }

    uint256 public constant ONE_HUNDRED_PERCENT = 10000; // 100%

    address public treasury;

    // gameId => GameDeposit
    mapping(string => GameDeposit) public gameDeposits;

    mapping(string => mapping(address => bool)) public gameDepositPaymentTokens;

    event SetGameDeposit(
        string gameId,
        address[] paymentTokens,
        address receivePayment,
        uint256 protocolFee,
        bool enabled
    );

    event SetGameDepositStatus(string gameId, bool enabled);

    event SetGameDepositProtocolFee(string gameId, uint256 protocolFee);

    event SetGameDepositReceivePayment(string gameId, address receivePayment);

    event SetGameDepositPaymentToken(
        string gameId,
        address[] paymentTokens,
        bool status
    );

    event GameDeposited(
        string gameId,
        address sender,
        address paymentToken,
        uint256 amount,
        uint256 partnerAmount,
        uint256 protocolAmount
    );

    function initialize() external initializer {
        __ReentrancyGuard_init();
        __Pausable_init();
        __Ownable_init();
        treasury = msg.sender;
    }

    function setTreasury(address _treasury) public onlyOwner {
        require(_treasury != address(0), "Invalid Address");
        treasury = _treasury;
    }

    function setGameDeposit(
        string calldata _gameId,
        address[] calldata _paymentTokens,
        address _receivePayment,
        uint256 _protocolFee,
        bool _enabled
    ) external whenNotPaused onlyOwner {
        require(
            _paymentTokens.length > 0 && _receivePayment != address(0),
            "Invalid params"
        );

        gameDeposits[_gameId] = GameDeposit(
            _receivePayment,
            _protocolFee,
            _enabled
        );

        for (uint256 i = 0; i < _paymentTokens.length; i++) {
            gameDepositPaymentTokens[_gameId][_paymentTokens[i]] = true;
        }

        emit SetGameDeposit(
            _gameId,
            _paymentTokens,
            _receivePayment,
            _protocolFee,
            _enabled
        );
    }

    function setGameDepositStatus(string calldata _gameId, bool _enabled)
        external
        whenNotPaused
        onlyOwner
    {
        GameDeposit storage gameDeposit = gameDeposits[_gameId];

        require(gameDeposit.receivePayment != address(0), "Invalid Game");

        gameDeposit.enabled = _enabled;

        emit SetGameDepositStatus(_gameId, _enabled);
    }

    function setGameDepositProtocolFee(
        string calldata _gameId,
        uint256 _protocolFee
    ) external whenNotPaused onlyOwner {
        GameDeposit storage gameDeposit = gameDeposits[_gameId];

        require(gameDeposit.receivePayment != address(0), "Invalid Game");

        gameDeposit.protocolFee = _protocolFee;

        emit SetGameDepositProtocolFee(_gameId, _protocolFee);
    }

    function setGameDepositReceivePayment(
        string calldata _gameId,
        address _receivePayment
    ) external whenNotPaused onlyOwner {
        GameDeposit storage gameDeposit = gameDeposits[_gameId];

        require(gameDeposit.receivePayment != address(0), "Invalid Game");

        gameDeposit.receivePayment = _receivePayment;

        emit SetGameDepositReceivePayment(_gameId, _receivePayment);
    }

    function setGameDepositPaymentToken(
        string calldata _gameId,
        address[] calldata _paymentTokens,
        bool _status
    ) external whenNotPaused onlyOwner {
        GameDeposit memory gameDeposit = gameDeposits[_gameId];

        require(gameDeposit.receivePayment != address(0), "Invalid Game");

        for (uint256 i = 0; i < _paymentTokens.length; i++) {
            gameDepositPaymentTokens[_gameId][_paymentTokens[i]] = _status;
        }

        emit SetGameDepositPaymentToken(_gameId, _paymentTokens, _status);
    }

    function depositGame(
        string calldata _gameId,
        address _paymentToken,
        uint256 _amount
    ) external payable whenNotPaused {
        address sender = _msgSender();
        GameDeposit memory gameDeposit = gameDeposits[_gameId];

        require(gameDeposit.receivePayment != address(0), "Invalid Game");

        require(
            gameDepositPaymentTokens[_gameId][_paymentToken],
            "Invalid Payment Token"
        );

        uint256 feeProtocol = _calculateFee(_amount, gameDeposit.protocolFee);
        uint256 partnerPayment = _amount - feeProtocol;

        if (_paymentToken == address(0)) {
            require(msg.value == _amount, "Invalid Game");

            if (feeProtocol > 0) {
                payable(treasury).transfer(feeProtocol);
            }

            if (partnerPayment > 0) {
                payable(gameDeposit.receivePayment).transfer(partnerPayment);
            }
        } else {
            if (feeProtocol > 0) {
                IERC20(_paymentToken).safeTransferFrom(
                    sender,
                    treasury,
                    feeProtocol
                );
            }

            if (partnerPayment > 0) {
                IERC20(_paymentToken).safeTransferFrom(
                    sender,
                    gameDeposit.receivePayment,
                    partnerPayment
                );
            }
        }

        emit GameDeposited(
            _gameId,
            sender,
            _paymentToken,
            _amount,
            partnerPayment,
            feeProtocol
        );
    }

    function _calculateFee(uint256 _amount, uint256 _feePercent)
        internal
        pure
        returns (uint256)
    {
        return (_amount * _feePercent) / ONE_HUNDRED_PERCENT;
    }
}
