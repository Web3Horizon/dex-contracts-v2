// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

import {IDexerV2Factory} from "src/interfaces/IDexerV2Factory.sol";
import {IDexerV2Pair} from "src/interfaces/IDexerV2Pair.sol";
import {DexerV2Pair} from "src/DexerV2Pair.sol";

contract DexerV2Factory is IDexerV2Factory {
    mapping(address => mapping(address => address)) public pairs;
    address[] public allPairs;

    /* **** Events **** */
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    /* **** Errors **** */
    error DexerV2Factory__IndeticalAddresses();
    error DexerV2Factory__ExistingPair();
    error DexerV2Factory__ZeroAddress();

    function createPair(address tokenA, address tokenB) public returns (address pair) {
        // Check if tokens are the same
        if (tokenA == tokenB) {
            revert DexerV2Factory__IndeticalAddresses();
        }

        // Sort tokens based on their hexidecimal values, this is needed to prevent duplicates based on inputs order
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        // Check if tokens are not a null address
        if (token0 == address(0)) {
            revert DexerV2Factory__ZeroAddress();
        }

        // Check if a pool with this combination already exists
        if (pairs[token0][token1] != address(0)) {
            revert DexerV2Factory__ExistingPair();
        }

        bytes memory bytecode = type(DexerV2Pair).creationCode; // Contains the bytecode needed to create and deploy DexerV2Pair
        bytes32 salt = keccak256(abi.encodePacked(token0, token1)); // Generate an unique salt from a combination of token0 and token1

        // assembly {
        //     pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        // }

        // Create2 is a deterministic way of deploying a smart contract from within a contract
        // It returns the address of the deployment
        pair = Create2.deploy({amount: 0, salt: salt, bytecode: bytecode});

        IDexerV2Pair(pair).initialize(token0, token1);

        pairs[token0][token1] = pair;
        pairs[token1][token0] = pair; // Populate mapping on the reverse direction
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /**
     * @notice Retrieves all pair contracts addresses
     * @return _pairs An array containing all the pair contracts addresses created by this factory.
     */
    function getAllPairs() external view returns (address[] memory _pairs) {
        return allPairs;
    }
}
