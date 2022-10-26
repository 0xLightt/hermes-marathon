// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import { Types } from "./Types.sol";
// import { Hashing } from "./Hashing.sol";
import { RLPWriter } from "./rlp/RLPWriter.sol";
import { RLPReader } from "./rlp/RLPReader.sol";
import {BufferChainlink} from "./BufferChainlink.sol";

/**
 * @title Encoding
 * @notice Encoding handles Optimism's various different encoding schemes.
 */
library Encoding {
  using BufferChainlink for BufferChainlink.buffer;

    /**
     * @notice Encode provided calldata using RLP. Provides cheaper external calls in L2 networks.
     *
     * @param data 1 Byte Function Id and Calladata to encode.
     * @param offset Offset for calldata location in ´data´.
     *
     * @dev data is comprised the calldata parameters using standard abi encoding. 
     *
     * @return RLP encoded tx calldata.
     **/
    function encodeCallData(bytes memory data, uint256 offset) internal pure returns (bytes memory) {
        uint length = data.length;

        // Initialize byte list for encoding
        bytes[] memory buffer = new bytes[](length);

        uint256 positon;
        // Reads concsucitve 32 bytes starting from offset
        for (uint256 i = offset + 32; i <= length; ) {

            uint256 slot;
            assembly {
                slot := mload(add(data, i)) // Get next 32 bytes
            }

            // Encode and add extracted 32 bytes buffer
            buffer[positon] = RLPWriter.writeUint(slot);

            unchecked {
                i += 32;
                positon += 1;
            }
        }

        // return encoded byte list
        return RLPWriter.writeList(buffer);
    }

    /**
     * @notice Decode provided RLP encoded data into calldata. Provides cheaper external calls in L2 networks.
     *
     * @param data RLP encoded calladata to decode.
     *
     * @dev data is comprised of the calldata parameters without padding.
     *
     * @return bytes standard abi encoded tx calldata.
     **/
    function decodeCallData(bytes memory data, uint256 maxListLength) internal pure returns (bytes memory) {
        // Get RLP item list from data
        RLPReader.RLPItem[] memory items = RLPReader.readList(data, maxListLength);

        uint256 length = items.length;

        BufferChainlink.buffer memory buffer;
        // Initialize buffer with 32 bytes for each item
        BufferChainlink.init(buffer, length * 32);

        for (uint256 i = 0; i < length; ) {
            bytes memory slot = RLPReader.readBytes(items[i]);

            // Right-shift signifcant bytes to restore padding
            bytes32 val = bytes32(slot) >> (256-slot.length*8);

            // Add extracted 32 bytes buffer
            buffer.appendBytes32(val);

            unchecked {
                i++;
            }
        }
        return buffer.buf;
    }
}
