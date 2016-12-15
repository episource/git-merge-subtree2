#!/bin/bash

SCRIPT_DIR=$( dirname $( readlink -e $0 ) )
. "$SCRIPT_DIR/../_utils.sh"

function the-test() {
    # Initialize repo
    mkdir -p repo && cd repo
    git init
    
    # Initialize source branch
    git checkout --orphan source
    mkdir subtree
    echo -en "b\nc\nd" > subtree/subtree.txt
    git add -A
    git commit -m "source: initial commit"

    # Initialize target branch
    git checkout --orphan target
    echo "target branch" > file.txt
    git add -A
    git commit -m "target: initial commit"

    # Initialize subproject
    git subproject init my-subproject source --their-prefix=subtree

    # Try to push (no changes)
    STDERROUT=$( git subproject push my-subproject 2>&1 )
    [[ $? -eq 0 ]] && return 1
    
    echo "$STDERROUT" | tee /proc/self/fd/2 | grep -qi "no changes to pull/push"
    return $?
}

invoke-test $@