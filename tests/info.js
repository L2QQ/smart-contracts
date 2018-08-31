const { Qtum, QtumRPC } = require('qtumjs')

const address = '52.14.93.190'
const port = '18533'
const username = 'wardencliffe'
const password = 'iYuN5iGNTLlyRi5mbxeBLUF18skVyG2HqNs2ANrUVS4='
const connection = `http://${username}:${password}@${address}:${port}`

const rpc = new QtumRPC(connection)

async function test() {

    const accountName = ''

    const accountAddress = await rpc.rawCall('getaccountaddress', [ accountName ])
    console.log(`Default address: ${accountAddress}`)

    const accountAddressHex = await rpc.rawCall('gethexaddress', [ accountAddress ])
    console.log(`Default address (hex): ${accountAddressHex}`)
    
    const accountBalance = await rpc.rawCall('getbalance', [ accountName ])
    console.log(`Default account balance: ${accountBalance}`)
    
    //const accountInfo = await rpc.rawCall('getaccountinfo', [ accountAddress ])
    //console.log(`Default account balance: ${accountInfo}`)
    
    const accounts = await rpc.rawCall('listaccounts')
    console.log('List of accounts:')
    console.log(accounts)
    
    const contracts = await rpc.rawCall('listcontracts')
    console.log('List of contracts:')
    console.log(contracts)
    
    //const blockchainInfo = await rpc.rawCall('getblockchaininfo')
    //console.log('Blockchain info:')
    //console.log(blockchainInfo)
 
    //const blockIds = await rpc.rawCall('generate', [ 1 ])
    //console.log('Generated blocks:')
    //console.log(blockIds)
}

test()