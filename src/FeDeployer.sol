// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

library FeDeployer {
    function deployFe(Vm vm, string memory path) internal returns (address) {
        bytes memory initCode = fromHex(vm.readFile(path));
        address deployed;
        assembly {
            deployed := create(0, add(initCode, 0x20), mload(initCode))
        }
        require(deployed != address(0), string.concat("deploy failed: ", path));
        return deployed;
    }

    function deployFeWithArgs(Vm vm, string memory path, bytes memory args) internal returns (address) {
        bytes memory initCode = fromHex(vm.readFile(path));
        bytes memory fullCode = bytes.concat(initCode, args);
        address deployed;
        assembly {
            deployed := create(0, add(fullCode, 0x20), mload(fullCode))
        }
        require(deployed != address(0), string.concat("deploy failed: ", path));
        return deployed;
    }

    function deployFeWithValue(Vm vm, string memory path, bytes memory args, uint256 value) internal returns (address) {
        bytes memory initCode = fromHex(vm.readFile(path));
        bytes memory fullCode = bytes.concat(initCode, args);
        address deployed;
        assembly {
            deployed := create(value, add(fullCode, 0x20), mload(fullCode))
        }
        require(deployed != address(0), string.concat("deploy failed: ", path));
        return deployed;
    }

    function fromHex(string memory s) internal pure returns (bytes memory) {
        bytes memory strBytes = bytes(s);
        uint256 start = 0;
        while (start < strBytes.length && isWhitespace(strBytes[start])) {
            start++;
        }

        if (
            start + 1 < strBytes.length &&
            strBytes[start] == bytes1("0") &&
            (strBytes[start + 1] == bytes1("x") || strBytes[start + 1] == bytes1("X"))
        ) {
            start += 2;
        }

        uint256 digits = 0;
        for (uint256 i = start; i < strBytes.length; i++) {
            if (isWhitespace(strBytes[i])) continue;
            digits++;
        }
        require(digits % 2 == 0, "odd hex length");

        bytes memory out = new bytes(digits / 2);
        uint256 outIndex = 0;
        uint8 high = 0;
        bool highNibble = true;
        for (uint256 i = start; i < strBytes.length; i++) {
            bytes1 ch = strBytes[i];
            if (isWhitespace(ch)) continue;
            uint8 val = fromHexChar(ch);
            if (highNibble) {
                high = val;
                highNibble = false;
            } else {
                out[outIndex] = bytes1((high << 4) | val);
                outIndex++;
                highNibble = true;
            }
        }
        return out;
    }

    function isWhitespace(bytes1 ch) private pure returns (bool) {
        return ch == 0x20 || ch == 0x0a || ch == 0x0d || ch == 0x09;
    }

    function fromHexChar(bytes1 c) private pure returns (uint8) {
        uint8 b = uint8(c);
        if (b >= 48 && b <= 57) return b - 48;
        if (b >= 65 && b <= 70) return b - 55;
        if (b >= 97 && b <= 102) return b - 87;
        revert("invalid hex");
    }
}
