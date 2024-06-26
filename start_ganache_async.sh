#!/bin/bash

ganacheOutputTmpFile=`mktemp`
npx ganache-cli --gasLimit 10000000 -m "$MNEMONIC" 2>&1 >> "$ganacheOutputTmpFile" &
tail -n+0 -f "$ganacheOutputTmpFile" | sed '/Listening on/ q'
echo "Chain started"
