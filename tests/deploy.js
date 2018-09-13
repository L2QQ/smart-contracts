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

function sleepPromise(ms) {
    return new Promise(resolve => {
        if (ms > 0) {
            setTimeout(() => {
                resolve()
            }, ms)
        } else {
            resolve()
        }
    })
}

async function waitForTransactionQtum(transactionId) {
    while (true) {
        const transactionReceipt = await helperQtum.requestTransactionReceipt(transactionId)
        if (transactionReceipt.length > 0) {
            return transactionReceipt
        }
        await sleepPromise(1000)
    }
}

async function deployERC20(name, symbol, decimals) {
    const creatorAddress = config.ethereum.accounts.tokenOwner.address
    const creatorPrivateKey = config.ethereum.accounts.tokenOwner.privateKey
    const result = await helperEthereum.deployToken(name, symbol, decimals, creatorAddress, creatorPrivateKey)
    if (!result.status) {
        throw new Error('Unable to deploy ERC20 token to Ethereum')
    }
    console.log(`ERC20 token '${name}' (${symbol}) deployed to Ethereum at address: ${result.contractAddress}`)
    return result
}

async function deployQRC20(name, symbol, decimals) {
    const creatorAddress = config.qtum.accounts.tokenOwner.address
    const result = await helperQtum.deployToken(name, symbol, decimals, creatorAddress)
    const transactionReceipt = await waitForTransactionQtum(result.txid)
    if (transactionReceipt[0].excepted != 'None') {
        throw new Error('Unable to deploy QRC20 token to QTUM')
    }
    console.log(`QRC20 token '${name}' (${symbol}) deployed to QTUM at address: 0x${result.address}`)
    return result
}

async function deployECRecoverPublicKey() {
    const creatorAddress = config.qtum.accounts.l2Owner.address
    const result = await helperQtum.deployECRecoverPublicKey(creatorAddress)
    const transactionReceipt = await waitForTransactionQtum(result.txid)
    if (transactionReceipt[0].excepted != 'None') {
        throw new Error('Unable to deploy ECRecoverPublicKey contract to QTUM')
    }
    console.log(`ECRecoverPublicKey contract deployed to QTUM at address: 0x${result.address}`)
    return result
}

async function deployL2Ethereum() {
    const oracleAddress = config.ethereum.accounts.l2Oracle.address
    const creatorAddress = config.ethereum.accounts.l2Owner.address
    const creatorPrivateKey = config.ethereum.accounts.l2Owner.privateKey
    const result = await helperEthereum.deployL2(oracleAddress, creatorAddress, creatorPrivateKey)
    if (!result.status) {
        throw new Error('Unable to deploy L2 contract to Ethereum')
    }
    console.log(`L2 contract deployed to Ethereum at address: ${result.contractAddress}`)
    return result
}

async function deployL2Qtum(ecrpkAddress) {
    const oracleAddress = helperQtum.addressQtumToAddressEthereum(config.qtum.accounts.l2Oracle.address)
    const creatorAddress = config.qtum.accounts.l2Owner.address
    const result = await helperQtum.deployL2(oracleAddress, ecrpkAddress, creatorAddress)
    const transactionReceipt = await waitForTransactionQtum(result.txid)
    if (transactionReceipt[0].excepted != 'None') {
        throw new Error('Unable to deploy L2 contract to QTUM')
    }
    console.log(`L2 contract deployed to QTUM at address: 0x${result.address}`)
    return result
}

async function deployTestTokens() {

    for (const symbol in config.ethereum.tokens) {
        const token = config.ethereum.tokens[symbol]
        const result = await deployERC20(token.name, token.symbol, token.decimals)
    }

    for (const symbol in config.qtum.tokens) {
        const token = config.qtum.tokens[symbol]
        const result = await deployQRC20(token.name, token.symbol, token.decimals)
    }
}

async function deployL2() {

    const l2Ethereum = await deployL2Ethereum()

    const ecrpk = await deployECRecoverPublicKey()
    const l2Qtum = await deployL2Qtum(ecrpk.address)
}

async function prepareEthereum() {

    const amount = '3000000000000000000'
    const etherHolderPrivateKey = config.ethereum.accounts.l2Owner.privateKey

    await helperEthereum.transferEther(amount, config.ethereum.accounts.tokenOwner.address, etherHolderPrivateKey)
    await helperEthereum.transferEther(amount, config.ethereum.accounts.l2Oracle.address, etherHolderPrivateKey)
    await helperEthereum.transferEther(amount, config.ethereum.accounts.userA.address, etherHolderPrivateKey)
    await helperEthereum.transferEther(amount, config.ethereum.accounts.userB.address, etherHolderPrivateKey)
    await helperEthereum.transferEther(amount, config.ethereum.accounts.userC.address, etherHolderPrivateKey)
}

async function prepareQtum() {

    const amountQtum = 1000000
    
    await helperQtum.transferQtum(config.qtum.accounts.default.address, amountQtum)
    await helperQtum.transferQtum(config.qtum.accounts.tokenOwner.address, amountQtum)
    await helperQtum.transferQtum(config.qtum.accounts.l2Owner.address, amountQtum)
    await helperQtum.transferQtum(config.qtum.accounts.l2Oracle.address, amountQtum)
    await helperQtum.transferQtum(config.qtum.accounts.userA.address, amountQtum)
    await helperQtum.transferQtum(config.qtum.accounts.userB.address, amountQtum)
    await helperQtum.transferQtum(config.qtum.accounts.userC.address, amountQtum)
}

async function prepare() {
    await prepareEthereum()
    await prepareQtum()
}

async function deploy() {
    await deployTestTokens()
    await deployL2()
}

//prepare()
deploy()