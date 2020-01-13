# Energietokens-Implementierung
## Installing Dependencies
    sudo npm install -g truffle ganache
    npm install

## Building & Deployment
Launch Ganache:

    ganache-cli --allowUnlimitedContractSize -l 1000000000

Choose a sender address from the list that's printed and replace the address in the line containing `from:` in `truffle-config.js` by it.

Then (in a different terminal instance) compile the contracts and deploy them:

    truffle compile
    truffle deploy
