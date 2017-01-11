#!/bin/bash
set -o pipefail


function add-to-path() {
    if [[ -z "$NO_ADD_TO_PATH" ]]; then
        local REPO_ROOT="$( git rev-parse --show-toplevel )"
        command -v cygpath &> /dev/null && REPO_ROOT="$( cygpath $REPO_ROOT )"
        
        export PATH="$REPO_ROOT:$PATH"
        export NO_ADD_TO_PATH=true  
    fi
}

function invoke-test() {
    local RUNDIR=$(mktemp -d)
    cd "$RUNDIR"
    echo "RUNDIR: $RUNDIR"

    # define prefix character for test tracing
    # -> a character different than '+' allows for easier tracing of the git
    #    command under test
    PS4="==> "
    
    set -x
    the-test
    local SUCCESS=$?
    set +x
    
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
        echo "=== TEST: $(basename $TESTDIR)/$test - $(date -Imin) ===" >>"$LOGFILE"
        >&2 echo -n "TEST: $test... "
        "$SCRIPT_DIR/$test" |& cat >>"$LOGFILE"
        
        if [[ $? -eq 0 ]]; then
            echo "PASSED"
            (( PASSED_COUNT++ ))
        else
            echo "FAILED"
            (( FAILED_COUNT++ ))
        fi
    done

    echo "PASSED: $PASSED_COUNT FAILED: $FAILED_COUNT"
    exit $FAILED_COUNT
}


add-to-path