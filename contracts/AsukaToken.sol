// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

interface IBotPrevention {

    function protect(address sender, address receiver, uint256 amount) external;

}

contract AsukaToken is Ownable, ERC20Burnable, ERC20Votes {

    IBotPrevention public bpContract;

    bool public bpEnabled;
    bool public bpDisabledForever;

    constructor(string memory name, string memory symbol, uint256 initialSupply)
        ERC20(name, symbol)
        ERC20Permit(name)
    {
        _mint(_msgSender(), initialSupply);
    }

    function setBPContract(address addr)
        public
        onlyOwner
    {
        require(address(bpContract) == address(0), "AsukaToken: can only be initialized once");

        bpContract = IBotPrevention(addr);
    }

    function setBPEnabled(bool enabled)
        public
        onlyOwner
    {
        bpEnabled = enabled;
    }

    function setBPDisableForever()
        public
        onlyOwner
    {
        require(!bpDisabledForever, "AsukaToken: bot prevention disabled");

        bpDisabledForever = true;
    }

    function _mint(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(account, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override
    {
        if (bpEnabled && !bpDisabledForever) {
            bpContract.protect(from, to, amount);
        }
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

}