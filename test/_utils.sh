#!/bin/bash

function invoke-test() {
    local RUNDIR=$(mktemp -d)
    cd "$RUNDIR"
    echo "RUNDIR: $RUNDIR"

    the-test
    local SUCCESS=$?
    
    [[ $SUCCESS -eq 0 ]] && echo "PASSED" || echo "FAILED"

    if [[ "$@" == *stop* ]]; then
        bash -i
    fi

    rm -rf "$RUNDIR"
    exit $SUCCESS
}

function invoke-all() {
    local TESTDIR="$1"
    local PASSED_COUNT=0
    local FAILED_COUNT=0
    
    if [[ -z "$LOGFILE" ]]; then
        local LOGFILE="/dev/null"
    fi

    for test in $(ls $TESTDIR); do
        [[ "$(basename $test)" == "all.sh" ]] && continue
        
        [[ -s "$LOGFILE" ]] && echo >>"$LOGFILE"
        echo "=== TEST: $(basename $TESTDIR)/$test ===" >>"$LOGFILE"
        >&2 echo -n "TEST: $test... "
        "$SCRIPT_DIR/$test" &>>"$LOGFILE"
        
        if [[ $? -eq 0 ]]; then
            echo "PASSED"
            (( PASSED_COUNT++ ))
        else
            echo "FAILED"
            (( FAILED_COUNT++ ))
        fi
        
        IS_FIRST=
    done

    echo "PASSED: $PASSED_COUNT FAILED: $FAILED_COUNT"
    exit $FAILED_COUNT
}