// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

library FeDeployer {
    function deployFe(Vm vm, string memory path) internal returns (address) {
        bytes memory initCode = vm.readFileBinary(path);
        address deployed;
        assembly {
            deployed := create(0, add(initCode, 0x20), mload(initCode))
        }
        require(deployed != address(0), string.concat("deploy failed: ", path));
        return deployed;
    }

    function deployFeWithArgs(Vm vm, string memory path, bytes memory args) internal returns (address) {
        bytes memory initCode = vm.readFileBinary(path);
        bytes memory fullCode = bytes.concat(initCode, args);
        address deployed;
        assembly {
            deployed := create(0, add(fullCode, 0x20), mload(fullCode))
        }
        require(deployed != address(0), string.concat("deploy failed: ", path));
        return deployed;
    }

    function deployFeWithValue(Vm vm, string memory path, bytes memory args, uint256 value) internal returns (address) {
        bytes memory initCode = vm.readFileBinary(path);
        bytes memory fullCode = bytes.concat(initCode, args);
        address deployed;
        assembly {
            deployed := create(value, add(fullCode, 0x20), mload(fullCode))
        }
        require(deployed != address(0), string.concat("deploy failed: ", path));
        return deployed;
    }
}
