module.exports = {
    ethereum: {
        connection: 'http://52.14.93.190:12933',
        accounts: {
            tokenOwner: {
                privateKey: Buffer.from('5a2b7750a35510214889779e702c34051236ea6981defa7fbeadd1a77770fc70', 'hex'),
                address: '0x792dB58835893e047189f4B6639eda85Ac34113f'.toLocaleLowerCase()
            },
            l2Owner: {
                privateKey: Buffer.from('26655fe5ccb52d03c5f6d31b2676ad525a77ada04ffa33fa2878d0ed261bf2e4', 'hex'),
                address: '0x07FA9eDa277336A4F5B452207dfDE07e12eCC7D9'.toLocaleLowerCase()
            },
            l2Oracle: {
                privateKey: Buffer.from('2a57aa6f124f0ee15047326ef66d9150f6c6ab47390b73a77df573667a5379e6', 'hex'),
                address: '0xe671b4223765C6D39203Fd308d0AFe6451396635'.toLocaleLowerCase()
            },
            userA: {
                privateKey: Buffer.from('7b847487bc832ba667513e25d02276083944eb41a025978804f3e7d96eb25625', 'hex'),
                address: '0x0B7D92778316c4AA34A26febFB3C005b077e1117'.toLocaleLowerCase()
            },
            userB: {
                privateKey: Buffer.from('1cc34bbba75f7dae0c966157533fb16d8d7ec73bc807526a3639277f3230e7c3', 'hex'),
                address: '0x416871e599A146a15e3136535F951e4bad71ABB9'.toLocaleLowerCase()
            },
            userC: {
                privateKey: Buffer.from('f40258936a170b35d5f18fa7c49c47c25522fb35a71a46c24d257b13e369c6f9', 'hex'),
                address: '0xAD1219e0A29Fc581De227622535bb2A781bDfDe6'.toLocaleLowerCase()
            }
        },
        tokens: {
            OMG: {
                name: 'OMGToken',
                symbol: 'OMG',
                decimals: 18
            },
            USDT: {
                name: 'Tether',
                symbol: 'USDT',
                decimals: 6
            }
        }
    },
    qtum: {
        connection: {
            address: '52.14.93.190',
            port: '18533',
            username: 'wardencliffe',
            password: 'iYuN5iGNTLlyRi5mbxeBLUF18skVyG2HqNs2ANrUVS4=',
            testnet: true
        },
        accounts: {
            default: {
                account: '',
                address: 'qfjsCNVFxWRWbuNEyyFBRzpxrYGu8Ut3ut'
            },
            tokenOwner: {
                account: 'token_owner',
                address: 'qXuSATPBQh6C41EmrSuPF5Zud3BJ8BWzTQ'
            },
            l2Owner: {
                account: 'l2_owner',
                address: 'qXdqbhXfpkrheCW2Ugd7sQf956j8ZYuzco'
            },
            l2Oracle: {
                account: 'l2_oracle',
                address: 'qYj4x4zGxVCvMEt66gmNKKEi9EPDX7XJvF'
            },
            userA: {
                account: 'user_a',
                address: 'qL7Y6VoPoGLbCQTSCP2saP2yjkZDtKvsPH'
            },
            userB: {
                account: 'user_b',
                address: 'qZySw2czbLzyfX6whqbBdADgjGSRm7pL9u'
            },
            userC: {
                account: 'user_c',
                address: 'qdq9dGXuJrgXUEhD8FeHXurUvhBKZuBpSF'
            }
        },
        tokens: {
            INK: {
                name: 'INK Coin',
                symbol: 'INK',
                decimals: 9
            },
            BOT: {
                name: 'Bodhi',
                symbol: 'BOT',
                decimals: 8
            },
            QBT: {
                name: 'Qbao',
                symbol: 'QBT',
                decimals: 8
            }
        }
    }
}