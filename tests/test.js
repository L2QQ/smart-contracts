const Deployer = require('./deployer')
const Helper = require('./helper')

const config = require('./config')

const address = '52.14.93.190'
const port = '18533'
const username = 'wardencliffe'
const password = 'iYuN5iGNTLlyRi5mbxeBLUF18skVyG2HqNs2ANrUVS4='
const connection = `http://${username}:${password}@${address}:${port}`

const deployer = new Deployer(connection)
const helper = new Helper(connection)

async function transferQTUM() {

    const transferQTUMToAccount = async function(accountName, amount) {
        const accountAddress = await helper.getAccountAddress(accountName)
        console.log(accountAddress)
        return await helper.transferQTUM(accountAddress, amount)
    }
    
    await transferQTUMToAccount(config.accounts.tokenOwner, 5)
    await transferQTUMToAccount(config.accounts.l2dexOwner, 5)
    await transferQTUMToAccount(config.accounts.userA, 3)
    await transferQTUMToAccount(config.accounts.userB, 3)
    await transferQTUMToAccount(config.accounts.userC, 3)
}

async function deployQRC20Tokens() {

    const tokenOwnerAddress = await helper.getAccountAddress(config.accounts.tokenOwner)

    const resultA = await deployer.deployToken('L2Q Test Token A', 'L2QA', 8, tokenOwnerAddress)
    const resultB = await deployer.deployToken('L2Q Test Token B', 'L2QB', 8, tokenOwnerAddress)
    const resultC = await deployer.deployToken('L2Q Test Token C', 'L2QC', 8, tokenOwnerAddress)

    console.log('Token A deployed:')
    console.log(resultA)
    console.log('Token B deployed:')
    console.log(resultB)
    console.log('Token C deployed:')
    console.log(resultC)
}

transferQTUM()
//deployQRC20Tokens()