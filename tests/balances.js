const HelperEthereum = require('./helper-ethereum')
const HelperQtum = require('./helper-qtum')

const config = require('./config')
const connectionEthereum = config.ethereum.connection
const configQtum = config.qtum.connection
const connectionQtum = configQtum.username && configQtum.password ?
    `http://${configQtum.username}:${configQtum.password}@${configQtum.address}:${configQtum.port}` :
    `http://${configQtum.address}:${configQtum.port}`

const helperEthereum = new HelperEthereum(connectionEthereum)
const helperQtum = new HelperQtum(connectionQtum)


async function getBalancesQtum() {

    const accountNames = [
        //'',
        //config.qtum.accounts.tokenOwner.account,
        config.qtum.accounts.l2Owner.account,
        config.qtum.accounts.l2Oracle.account,
        config.qtum.accounts.userA.account,
        config.qtum.accounts.userB.account,
        config.qtum.accounts.userC.account,
    ]

    console.log('QTUM accounts:')
    for (let i = 0; i < accountNames.length; ++i) {
        const accountName = accountNames[i]
        const accountBalance = await helperQtum.requestAccountBalance(accountName)
        console.log(`  Balance of account '${accountName.length > 0 ? accountName : 'default'}': ${accountBalance}`)
        const accountAddresses = await helperQtum.requestAddressesByAccount(accountName)
        for (let j = 0; j < accountAddresses.length; ++j) {
            const accountAddress = accountAddresses[j]
            const received = await helperQtum.requestReceivedByAddress(accountAddress)
            console.log(`    Has address '${accountAddress}' received ${received}`)
        }
    }
}

async function getBalancesEthereum() {

    const accountAddresses = [
        config.ethereum.accounts.tokenOwner.address,
        config.ethereum.accounts.l2Owner.address,
        config.ethereum.accounts.l2Oracle.address,
        config.ethereum.accounts.userA.address,
        config.ethereum.accounts.userB.address,
        config.ethereum.accounts.userC.address,
    ]

    console.log('Ethereum accounts:')
    for (let i = 0; i < accountAddresses.length; ++i) {
        const accountAddress = accountAddresses[i]
        const accountBalance = await helperEthereum.requestBalance(accountAddress)
        console.log(`  Balance of account '${accountAddress}': ${accountBalance}`)
    }
}

async function getBalances() {
    await getBalancesQtum()
    await getBalancesEthereum()
}

getBalances()