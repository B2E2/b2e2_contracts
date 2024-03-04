require('dotenv').config();
const {exec, spawn} = require('child_process');
const {parallel, series} = require('gulp');
const fs = require('fs');

// ########################################
// ########################################

exports.build = series(clean, parallel(update_submodule, npm_install_contracts), compile_contracts);

exports.docker_build = series(clean, parallel(npm_install_contracts), compile_contracts);

exports.tests = series(start_test_chain, run_tests, kill_test_chain);

// ########################################
// ########################################

function start_test_chain() {
    return new Promise((resolve, _reject) => {
    // eslint-disable-next-line max-len
        const child = spawn(`npx ganache-cli --gasLimit 10000000 -m '${process.env.MNEMONIC}'`, [], {
            shell: true,
        });

        child.stdout.setEncoding('utf8');
        child.stderr.setEncoding('utf8');

        child.stdout.on('data', function(data) {
            // console.log(data);
            if (data.includes('Listening on')) {
                resolve();
            }
        });

        child.stderr.on('data', function(data) {
            console.error(data);
        });

        child.on('exit', (code, signal) => {
        // TODO: Why can the exit code be null?
            if(code === null)
                code = 0;

            console.log(`Chain exited with code ${code} and signale ${signal}`);
            if(code !== 0) {
                process.exit(1);
            }
        });
    });
}

function kill_test_chain(cb) {
    exec('kill $(ps aux | grep \'[g]anache-cli\' | awk \'{print $2}\')', (error, stdout, stderr) => {
        if (error) {
            console.error(stderr);
            return cb(error);
        }
        console.log(stdout);
        return cb();
    });
}

// ########################################
// ########################################

function run_tests(cb) {
    const child = spawn('npx truffle test --network development', [], {
        shell: true
    });

    child.stdout.setEncoding('utf8');
    child.stderr.setEncoding('utf8');

    child.stdout.on('data', function(data) {
        console.log(data);
    });

    child.stderr.on('data', function(data) {
        console.error(data);
    });

    child.on('exit', (code, _signal) => {
        console.log(`Tests exited with code ${code}`);
        if(code !== 0) {
            process.exit(1);
        }

        return cb();
    });
}

// ########################################
// ########################################

function npm_install_contracts(cb) {
    if (fs.existsSync('./node_modules')) {
        return cb();
    }

    exec('npm ci', (error, stdout, stderr) => {
        if (error) {
            console.error(stderr);
            throw error;
        }
        console.log(stdout);
        return cb();
    });
}

function compile_contracts(cb) {
    if (fs.existsSync('./build')) {
        return cb();
    }

    const child = spawn('npx truffle compile', [], {
        shell: true
    });

    child.stdout.setEncoding('utf8');
    child.stderr.setEncoding('utf8');

    child.stdout.on('data', function(data) {
        console.log(data);
    });

    child.stderr.on('data', function(data) {
        console.error(data);
    });

    child.on('exit', (code, _signal) => {
        console.log(`Server exited with code ${code}`);
        if(code !== 0) {
            process.exit(1);
        }

        return cb();
    });
}

// ########################################
// ########################################

function clean(cb) {
    // eslint-disable-next-line max-len
    exec('rm -rf ./build; rm -rf ./node_modules', (error, stdout, stderr) => {
        if (error) {
            console.error(stderr);
            return cb(error);
        }
        console.log(stdout);
        return cb();
    });
}

// ########################################
// ########################################

function update_submodule(cb) {
    exec('git submodule update --recursive --init', (error, stdout, stderr) => {
        if (error) {
            console.error(stderr);
            return cb(error);
        }
        console.log(stdout);
        return cb();
    });
}
