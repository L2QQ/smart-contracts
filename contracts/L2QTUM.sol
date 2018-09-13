pragma solidity ^0.4.24;

import './L2.sol';


contract L2QTUM is L2 {

    address private ecrpkAddress;
    bytes4 private ecrpkFunctionHash;

    constructor(address _oracle, address _ecrpkAddress) L2(_oracle) public {
        require(_ecrpkAddress != address(0));
        ecrpkAddress = _ecrpkAddress;
        ecrpkFunctionHash = bytes4(keccak256("ecrecover(uint256,uint256,uint256,uint256)"));
    }

    // Since contract's `msg.sender` in QTUM blockchain is received from QTUM compressed public key
    // paired with QTUM private key used to sign a blockchain transaction as
    // RIPEMD160(SHA256(publicKey)) we cannot use built-in `ecrecover` function to
    // compare `msg.sender` with recovered author of off-chain signature because `ecrecover`
    // returns recovered address received from public key as SHA3(publicKey). To workaround
    // this we use precompiled contract (thanks to Vitalik Buterin) grabbed from following link:
    // https://github.com/ethereum/serpent/blob/develop/examples/ecc/ecrecover.se
    // We also faced with unknown issue: method sha256() called from a smart contract fails. This is
    // why we use some hack to call precompiled smart contract implemented sha256() method using it's
    // permanent address 0x0000000000000000000000000000000000000002 from assembly code.
    function recoverSignerAddress(bytes32 dataHash, uint8 v, bytes32 r, bytes32 s) internal returns (address) {
        // Copy contract address and function hash of custom `ecrecover` to use from assembly
        address ecrpkAddress_ = ecrpkAddress;
        bytes4 ecrpkFunctionHash_ = ecrpkFunctionHash;
        // Recover public key from message hash and signature
        bytes32 publicKeyX;
        bytes32 publicKeyY;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, ecrpkFunctionHash_)
            mstore(add(ptr, 0x04), dataHash)
            mstore(add(ptr, 0x24), v)
            mstore(add(ptr, 0x44), r)
            mstore(add(ptr, 0x64), s)
            let result := call(gas, ecrpkAddress_, 0, ptr, 0x84, ptr, 0x80)
            if eq(result, 0) {
                revert(0, 0)
            }
            publicKeyX := mload(add(ptr, 0x40))
            publicKeyY := mload(add(ptr, 0x60))
            mstore(0x40, add(ptr, 0x84))
        }
        // Get SHA256 hash of just recovered public key
        // Hack: call sha256() method using assembly since usual calling sha256() fails for some reason
        bytes32 publicKeyHash;
        uint8 prefix = (publicKeyY & 1) == 0 ? 2 : 3;
        assembly {
            let ptr := mload(0x40)
            mstore8(ptr, prefix)
            mstore(add(ptr, 0x01), publicKeyX)
            let result := call(gas, 2, 0, ptr, 0x21, ptr, 0x20)
            if eq(result, 0) {
                revert(0, 0)
            }
            publicKeyHash := mload(ptr)
            mstore(0x40, add(ptr, 0x22))
        }
        // Get RIPEMD160 hash receiving signer address which can be compared to `msg.sender`
        return address(ripemd160(abi.encodePacked(publicKeyHash)));
    }
}