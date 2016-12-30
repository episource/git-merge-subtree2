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
    echo "excluded" > subtree/subtree.ex
    git add -A
    git commit -m "source: initial commit"

    # Initialize target branch
    git checkout --orphan target
    echo "target branch" > file.txt
    git add -A
    git commit -m "target: initial commit"

    # Initialize subproject
    git subproject init my-subproject source --their-prefix=subtree --filter-is-regexp --filter="^.*\.txt"
    
    # Ensure only subtree.txt was pulled
     if [[ ! -f my-subproject/subtree.txt ]]; then
        echo "missing subtree.txt"
        return 1
    fi
    if [[ -f my-subproject/subtree.ex ]]; then
        echo "unexpected file subtree.ex"
        return 1
    fi

    # Update source 
    git checkout source
    echo -en "a\n$(cat subtree/subtree.txt)" > subtree/subtree.txt
    echo "changed there" > subtree/subtree.ex
    git add -A
    git commit -m "source: update"

    # Update subtree within target branch
    git checkout target
    echo -en "\ne\n" >> my-subproject/subtree.txt
    echo "added here" > my-subproject/subtree.ex
    git add -A
    git commit -m "target: update my-subproject"

    # Re-Merge source:subtree
    git subproject pull my-subproject
    
    # Assert subtree.ex has been left unchanged
    diff -c - my-subproject/subtree.ex << EOF || return $?
added here
EOF
    
    # Assert subtree.txt conflict has been resolved
    diff -c - my-subproject/subtree.txt << EOF
a
b
c
d
e
EOF
    
    return $?
}

invoke-test $@