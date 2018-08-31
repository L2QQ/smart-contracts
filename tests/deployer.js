const fs = require('fs')
const Web3 = require('web3')
const { QtumRPC } = require('qtumjs')


class Deployer {

    constructor(connection) {
        this.web3 = new Web3()
        this.rpc = new QtumRPC(connection)
        this.token = {
            abi: JSON.parse(fs.readFileSync('./bin/contracts/QRC20Token.abi')),
            bin: fs.readFileSync('./bin/contracts/QRC20Token.bin').toString(),
            json: JSON.parse(fs.readFileSync('./bin/contracts/QRC20Token.json'))
        }
        this.l2dex = {
            abi: JSON.parse(fs.readFileSync('./bin/contracts/l2dex.abi')),
            bin: fs.readFileSync('./bin/contracts/l2dex.bin').toString(),
            json: JSON.parse(fs.readFileSync('./bin/contracts/l2dex.json'))
        }
        this.gasLimit = 2500000
        this.gasPrice = 0.0000005
    }

    async deployToken(name, symbol, decimals, creatorAddress) {
        var parametersTypes = null
        this.token.abi.forEach(object => {
            if (object.type == 'constructor' && !parametersTypes) {
                parametersTypes = []
                object.inputs.forEach(parameter => {
                    parametersTypes.push(parameter.type)
                })
            }
        })
        if (parametersTypes) {
            const parametersBin = this.web3.eth.abi.encodeParameters(parametersTypes, [ name, symbol, decimals ])
            return this.rpc.rawCall('createcontract', [
                '0x' + this.token.bin + parametersBin.slice(2),
                this.gasLimit,
                this.gasPrice,
                creatorAddress
            ])
        }
    }
}

module.exports = Deployer