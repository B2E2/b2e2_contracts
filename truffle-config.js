const HDWalletProvider = require('truffle-hdwallet-provider');
const mnemonic = 'gas october undo antenna obvious turtle sunny lazy blanket near liberty august';

module.exports = {
    networks: {
        development: {
            host: '127.0.0.1',
            port: 8545,
            network_id: '*',
            from: '0x3a43F087bB52Fd979d9365Be4908b35220fc0842',
            gas: 8000000,
        },
        volta: {
            provider: () => new HDWalletProvider(mnemonic, 'https://volta-rpc.energyweb.org'),
            network_id: 73799,
            gas: 7000000,
        },
    },
    plugins: ['truffle-contract-size'],
    compilers: {
        solc: {
            version: '0.8.7',
            settings: {
                optimizer: {
                    enabled: true,
                    runs: 10,
                },
                evmVersion: 'petersburg',
            },
        },
    },
};
