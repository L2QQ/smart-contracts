const fs = require('fs')
const Web3 = require('web3')
const EthTx = require('ethereumjs-tx')
const EthUtil = require('ethereumjs-util')
const EthWallet = require('ethereumjs-wallet')


class HelperEthereum {

    constructor(connection) {
        this.web3 = new Web3(connection)
        this.contracts = {
            token: {
                abi: JSON.parse(fs.readFileSync('./bin/ERC20Token.abi')),
                bin: fs.readFileSync('./bin/ERC20Token.bin').toString()
            },
            l2: {
                abi: JSON.parse(fs.readFileSync('./bin/L2Ethereum.abi')),
                bin: fs.readFileSync('./bin/L2Ethereum.bin').toString()
            }
        }
        this.gasLimit = 2500000
        this.gasPrice = 10000000000
    }

    async requestBalance(address) {
        const balance = await this.web3.eth.getBalance(address)
        return Web3.utils.fromWei(balance, 'ether')
    }

    async deployToken(name, symbol, decimals, creatorAddress, creatorPrivateKey) {
        const parametersTypes = this.getContractConstructorParameters(this.contracts.token.abi)
        if (parametersTypes.length == 3) {
            const parametersBin = this.web3.eth.abi.encodeParameters(parametersTypes, [ name, symbol, decimals ])
            const bytecode = `0x${this.contracts.token.bin}${parametersBin.slice(2)}`
            const nonce = await this.getNonce(creatorAddress)
            const transaction = {
                from: creatorAddress,
                value: 0,
                data: bytecode,
                gas: this.gasLimit,
                gasPrice: this.gasPrice,
                nonce: nonce,
                privateKey: creatorPrivateKey
            }
            const signedTransaction = this.signTransaction(transaction)
            return this.sendSignedTransaction(signedTransaction)
        }
    }

    async deployL2(oracle, creatorAddress, creatorPrivateKey) {
        const parametersTypes = this.getContractConstructorParameters(this.contracts.l2.abi)
        if (parametersTypes.length == 1) {
            const parametersBin = this.web3.eth.abi.encodeParameters(parametersTypes, [ oracle ])
            const bytecode = `0x${this.contracts.token.bin}${parametersBin.slice(2)}`
            const nonce = await this.getNonce(creatorAddress)
            const transaction = {
                from: creatorAddress,
                value: 0,
                data: bytecode,
                gas: this.gasLimit,
                gasPrice: this.gasPrice,
                nonce: nonce,
                privateKey: creatorPrivateKey
            }
            const signedTransaction = this.signTransaction(transaction)
            return this.sendSignedTransaction(signedTransaction)
        }
    }

    // HELPER FUNCTIONS

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

    // Transfers ether from sender to receiver
    // amount - amount of weis that should be send with the transaction as string
    // receiverAddress - address of transaction receiver in hex format starting from '0x' as string
    // senderPrivateKey - private key used to sign transaction to become its author as 32-bytes Buffer
    async transferEther(amount, receiverAddress, senderPrivateKey) {
        const senderAddress = `0x${this.getAddressFromPrivateKey(senderPrivateKey).toString('hex')}`
        const nonce = await this.getNonce(senderAddress)
        const transaction = {
            from: senderAddress,
            to: receiverAddress,
            value: amount,
            gas: 21000,
            gasPrice: this.gasPrice,
            nonce: nonce,
            privateKey: senderPrivateKey
        }
        const signedTransaction = this.signTransaction(transaction)
        return this.sendSignedTransaction(signedTransaction)
    }

    // Signs transaction offline so it is ready to send to a blockchain
    // transaction - object in format {
    //     from: '', // address of transaction sender in hex format starting from '0x' as string
    //     to: '', // address of transaction receiver in hex format starting from '0x' as string
    //     value: '0', // amount of weis to send with the transaction as string (optional)
    //     data: '0x', // binary call data in hex format as string (optional)
    //     gas: 21000, // maximal amount of gas can be used to perform as a transaction as string or Number
    //     gasPrice: '1000000000', // gas price in weis as string
    //     nonce: 0, // nonce of the transaction as string or Number
    //     privateKey: Buffer.from(...), // private key paired with address 'from' as 32-bytes Buffer
    // }
    // returns signed raw transaction ready to send a blockchain as Buffer
    signTransaction(transaction) {
        const tx = new EthTx({
            from: transaction.from,
            to: transaction.to,
            value: Web3.utils.toHex(transaction.value || 0),
            data: transaction.data || '0x',
            gasLimit: Web3.utils.toHex(transaction.gas),
            gasPrice: Web3.utils.toHex(transaction.gasPrice),
            nonce: Web3.utils.toHex(transaction.nonce)
        })
        tx.sign(transaction.privateKey)
        return tx.serialize()
    }

    // Sends signed raw transaction to a blockchain
    // signedTransaction - signed raw transaction ready to send a blockchain as Buffer
    sendSignedTransaction(signedTransaction) {
        const signedTransactionHex = `0x${signedTransaction.toString('hex')}`
        return this.web3.eth.sendSignedTransaction(signedTransactionHex)
    }

    // Determines nonce should be used next for a transaction
    // address - address of transaction sender in hex format starting from '0x' as string
    getNonce(address) {
        return this.web3.eth.getTransactionCount(address)
    }

    // Keys management

    // privateKey - Ethereum private key as Buffer
    getPublicKeyFromPrivateKey(privateKey) {
        const wallet = EthWallet.fromPrivateKey(privateKey)
        const publicKey = wallet.getPublicKey()
        return publicKey
    }

    // privateKey - Ethereum public key as Buffer
    getAddressFromPrivateKey(privateKey) {
        const wallet = EthWallet.fromPrivateKey(privateKey)
        const address = wallet.getAddress()
        return address
    }

    // privateKey - Ethereum private key as Buffer
    getAddressFromPublicKey(publicKey) {
        const address = EthUtil.sha3(publicKey.slice(1)).slice(-20)
        return address
    }
}

module.exports = HelperEthereum