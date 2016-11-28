#!/bin/bash

function invoke-test() {
    TESTDIR=$(mktemp -d)
    cd "$TESTDIR"
    echo "TESTDIR: $TESTDIR"

    the-test
    SUCCESS=$?
    
    [[ $SUCCESS -eq 0 ]] && echo "PASSED" || echo "FAILED"

    if [[ "$@" == *stop* ]]; then
        bash -i
    fi

    rm -rf "$TESTDIR"
    exit $SUCCESS
}