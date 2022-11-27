const HDWalletProvider = require('@truffle/hdwallet-provider');

module.exports = {
    networks: {
        development: {
            provider: () =>
                new HDWalletProvider(process.env.PRIVATE_KEY ?? process.env.MNEMONIC, 'http://localhost:8545'),
            network_id: '*',
            gas: 8000000,
        },
        volta: {
            provider: () =>
                new HDWalletProvider(process.env.PRIVATE_KEY ?? process.env.MNEMONIC, 'https://volta-rpc.energyweb.org'),
            network_id: 73799,
            gas: 8000000,
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
