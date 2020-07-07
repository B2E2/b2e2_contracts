# Energietokens-Implementierung
## Cloning the repository
    git clone --recursive git@github.com:BlockInfinity/Energietokens-Implementierung.git

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