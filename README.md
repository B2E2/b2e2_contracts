# B2E2 - Smart Contracts

This repository contains the smart contracts referenced in the 'Energy Token Model' whitepaper. The German version of the whitepaper can be downloaded [here](https://it-architecture.enbw.com/whitepaper-energy-token-model/), an English version is not yet available.

The Blockchain identities are implemented with the [ERC725](https://github.com/ethereum/EIPs/issues/725) and [ERC735](https://github.com/ethereum/EIPs/issues/735) standards. The energy tokens are implemented with the [ERC1155](https://github.com/ethereum/EIPs/issues/1155) standard.

The latest version of the sequence and entity relationship diagrams from the whitepaper can be found in the directory './documentation'.  

## Cloning the repository
    git clone --recursive <<todo: official github repo URL>>

## Installing Dependencies
    sudo npm install -g truffle ganache ganache-cli
    cd Energietokens-Implementierung
    npm install
	cd dependencies/jsmnSol
	npm install

## Building & Deployment
Launch Ganache:

    ganache-cli -l 1000000000

Choose a sender address from the list that's printed and replace the address in the line containing `from:` in `truffle-config.js` by it.

Then (in a different terminal instance) compile the contracts and deploy them:

    truffle compile
    truffle deploy

## Testing
Launch Ganache:

    ganache-cli -l 1000000000 -m "bread leave edge glide soda seat trim armed canyon rural cross scheme"

Copy sender address 0 from the list that's printed and replace the address in the line containing `from:` in `truffle-config.js` by it.

Copy private key 9 and change the definition of `account9Sk` at the top of `test/IdentityContract.test.js` to it.

Run the tests (in a different terminal instance):

    truffle deploy # required for tests to run successfully
    truffle test