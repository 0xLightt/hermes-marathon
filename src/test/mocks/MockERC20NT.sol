// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC20NT} from "../../libraries/ERC20NT.sol";

contract MockERC20NT is ERC20NT {
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) ERC20NT(_name, _symbol, _decimals) {}

    function mint(address to, uint256 value) public virtual {
        _mint(to, value);
    }

    function burn(address from, uint256 value) public virtual {
        _burn(from, value);
    }
}
