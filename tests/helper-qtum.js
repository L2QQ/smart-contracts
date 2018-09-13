const fs = require('fs')
const Web3 = require('web3')
const EthUtil = require('ethereumjs-util')
const { QtumRPC } = require('qtumjs')
const QtumCore = require('qtumcore-lib')
const wif = require('wif')
const secp256k1 = require('secp256k1')
const bs58check = require('bs58check')
const RIPEMD160 = require('ripemd160')


class HelperQtum {

    constructor(connection, testnet) {
        this.web3 = new Web3()
        this.rpc = new QtumRPC(connection)
        this.network = testnet ? QtumCore.Networks.testnet : QtumCore.Networks.mainnet
        this.contracts = {
            ecrpk: {
                bin: fs.readFileSync('./ECRecoverPublicKey.bin').toString()
            },
            token: {
                abi: JSON.parse(fs.readFileSync('./bin/QRC20Token.abi')),
                bin: fs.readFileSync('./bin/QRC20Token.bin').toString()
            },
            l2: {
                abi: JSON.parse(fs.readFileSync('./bin/L2QTUM.abi')),
                bin: fs.readFileSync('./bin/L2QTUM.bin').toString()
            }
        }
        this.gasLimit = 2500000
        this.gasPrice = 0.0000005
    }

    async requestAddressesByAccount(accountName = '') {
        return await this.rpc.rawCall('getaddressesbyaccount', [ accountName ])
    }

    async requestAccountBalance(accountName = '') {
        return await this.rpc.rawCall('getbalance', [ accountName ])
    }

    async requestReceivedByAccount(accountName = '') {
        return await this.rpc.rawCall('getreceivedbyaccount', [ accountName ])
    }

    async requestReceivedByAddress(address) {
        return await this.rpc.rawCall('getreceivedbyaddress', [ address ])
    }

    async requestNewAddress(accountName = '') {
        return await this.rpc.rawCall('getnewaddress', [ accountName ])
    }

    async requestTransaction(transactionId) {
        return this.rpc.rawCall('gettransaction', [ transactionId ])
    }

    async requestTransactionReceipt(transactionId) {
        return this.rpc.rawCall('gettransactionreceipt', [ transactionId ])
    }

    // DEPLOY CONTRACTS

    async deployECRecoverPublicKey(creatorAddress) {
        return this.rpc.rawCall('createcontract', [ this.contracts.ecrpk.bin, this.gasLimit, this.gasPrice, creatorAddress ])
    }

    async deployToken(name, symbol, decimals, creatorAddress) {
        const parametersTypes = this.getContractConstructorParameters(this.contracts.token.abi)
        if (parametersTypes.length == 3) {
            const parametersBin = this.web3.eth.abi.encodeParameters(parametersTypes, [ name, symbol, decimals ])
            const bytecode = `${this.contracts.token.bin}${parametersBin.slice(2)}`
            return this.rpc.rawCall('createcontract', [ bytecode, this.gasLimit, this.gasPrice, creatorAddress ])
        }
    }

    async deployL2(oracle, ecrpkAddress, creatorAddress) {
        const parametersTypes = this.getContractConstructorParameters(this.contracts.l2.abi)
        if (parametersTypes.length == 2) {
            const parametersBin = this.web3.eth.abi.encodeParameters(parametersTypes, [ oracle, ecrpkAddress ])
            const bytecode = `${this.contracts.l2.bin}${parametersBin.slice(2)}`
            return this.rpc.rawCall('createcontract', [ bytecode, this.gasLimit, this.gasPrice, creatorAddress ])
        }
    }

    // CRYPTO

    // data - data to hash as Buffer
    // returns hash as Buffer
    sha3(data) {
        return EthUtil.sha3(data)
    }

    // data - data to hash as Buffer
    // returns hash as Buffer
    sha256(data) {
        return EthUtil.sha256(data)
    }

    privateKeyToBuffer(privateKey) {
        return wif.decode(privateKey).privateKey
    }

    // privateKey - private key as string or Buffer
    // compressed - flag indicates if public key should be in compressed format
    // returns public key as Buffer
    privateKeyToPublicKey(privateKey, compressed = true) {
        if (typeof(privateKey) == 'string') {
            privateKey = this.privateKeyToBuffer(privateKey)
        }
        return secp256k1.publicKeyCreate(privateKey, compressed)
    }

    privateKeyToAddressQtum(publicKey) {
        const publicKeyObj = new QtumCore.PublicKey(publicKey.toString('hex'))
        const addressQtum = publicKeyObj.toAddress(this.network).toString()
        return addressQtum
    }

    privateKeyToAddressEthereum(publicKey) {
        const publicKeyHash = this.sha256(publicKey)
        const addressEthereum = new RIPEMD160().update(publicKeyHash).digest()
        return addressEthereum.toString('hex')
    }

    addressQtumToEthereum(addressQtum) {
        const addressEthereum = bs58check.decode(addressQtum).slice(1)
        return `0x${addressEthereum.toString('hex')}`
    }

    // HELPER FUNCTIONS

    async transferQtum(receiverAddress, amount) {
        return this.rpc.rawCall('sendtoaddress', [ receiverAddress, amount ])
    }

    getContractConstructorParameters(abi) {
        let parametersTypes = []
        abi.forEach(object => {
            if (object.type == 'constructor') {
                object.inputs.forEach(parameter => {
                    parametersTypes.push(parameter.type)
                })
                return parametersTypes
            }
        })
        return parametersTypes
    }
}

module.exports = HelperQtum