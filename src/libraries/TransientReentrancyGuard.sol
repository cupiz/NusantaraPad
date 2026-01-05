// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title TransientReentrancyGuard
 * @author NusantaraPad Team
 * @notice Gas-optimized reentrancy guard using EIP-1153 transient storage
 * @dev Uses TSTORE/TLOAD opcodes for ~100 gas savings vs traditional storage
 * @custom:security-contact security@nusantarapad.io
 */
abstract contract TransientReentrancyGuard {
    /// @dev Transient storage slot for reentrancy lock (keccak256("nusantarapad.reentrancy.guard"))
    bytes32 private constant _REENTRANCY_SLOT = 
        0x8e94fed44239eb2314ab7a406345e6c5a8f0ccedf3b600de3d004e672c33abf4;

    /// @dev Reentrancy lock states
    uint256 private constant _NOT_ENTERED = 0;
    uint256 private constant _ENTERED = 1;

    /// @notice Thrown when a reentrant call is detected
    error ReentrancyGuardReentrantCall();

    /**
     * @dev Prevents reentrant calls using EIP-1153 transient storage
     * @custom:gas Uses ~100 less gas than storage-based reentrancy guards
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    /**
     * @dev Check and set reentrancy lock before function execution
     */
    function _nonReentrantBefore() private {
        assembly {
            // Check if already entered
            if tload(_REENTRANCY_SLOT) {
                // Store error selector and revert
                mstore(0x00, 0x3ee5aeb5) // ReentrancyGuardReentrantCall()
                revert(0x1c, 0x04)
            }
            // Set entered flag
            tstore(_REENTRANCY_SLOT, _ENTERED)
        }
    }

    /**
     * @dev Clear reentrancy lock after function execution
     */
    function _nonReentrantAfter() private {
        assembly {
            tstore(_REENTRANCY_SLOT, _NOT_ENTERED)
        }
    }

    /**
     * @dev Returns true if currently in a nonReentrant function
     * @return True if the reentrancy guard is currently set
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        bool entered;
        assembly {
            entered := tload(_REENTRANCY_SLOT)
        }
        return entered;
    }
}
