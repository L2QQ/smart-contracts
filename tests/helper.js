const fs = require('fs')
const { QtumRPC } = require('qtumjs')


class Helper {

    constructor(connection) {
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
    }

    async getAccountAddress(accountName = '') {
        const accountAddress = await this.rpc.rawCall('getaccountaddress', [ accountName ])
        console.log(`Address of account '${accountName}': ${accountAddress}`)
        return accountAddress
    }

    async transferQTUM(receiver, amount) {
        const transactionId = await this.rpc.rawCall('sendtoaddress', [ receiver, amount ])
        console.log(`Sent ${amount} QTUM to address ${receiver} with transaction ${transactionId}`)
        return transactionId
    }
}

module.exports = Helper