// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockTKO
 * @author NusantaraPad Team
 * @notice Mock TKO token for BSC Testnet simulation
 * @dev Standard BEP-20 with public mint function for testing purposes
 */
contract MockTKO is ERC20 {
    uint8 private constant _DECIMALS = 18;

    constructor() ERC20("Mock TKO", "mTKO") {}

    /**
     * @notice Mint tokens to any address (for testing only)
     * @param to The address to receive minted tokens
     * @param amount The amount of tokens to mint (in wei)
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @notice Returns the number of decimals used for token amounts
     * @return The number of decimals (18)
     */
    function decimals() public pure override returns (uint8) {
        return _DECIMALS;
    }
}
