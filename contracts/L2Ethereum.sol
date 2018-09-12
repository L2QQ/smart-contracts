pragma solidity ^0.4.24;

import './L2.sol';


contract L2Ethereum is L2 {

    constructor(address _oracle) L2(_oracle) public { }

    // Just use built-in `ecrecover` function
    function recoverSignerAddress(bytes32 dataHash, uint8 v, bytes32 r, bytes32 s) internal returns (address) {
        return ecrecover(dataHash, v, r, s);
    }
}