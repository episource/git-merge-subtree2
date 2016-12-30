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
    echo "source file" > subtree/subtree.old
    git add -A
    git commit -m "source: initial commit"

    # Initialize target branch
    git checkout --orphan target
    echo "target branch" > file.txt
    git add -A
    git commit -m "target: initial commit"

    # Initialize subproject
    git subproject init my-subproject source --their-prefix=subtree --filter-is-regexp --filter="^.*\.old"
    
    # Ensure only subtree.txt was pulled
    if [[ ! -f my-subproject/subtree.old ]]; then
        echo "missing subtree.old"
        return 1
    fi
       
    # Rename source file    
    git checkout source
    mv subtree/subtree.old subtree/subtree.new
    git add -A
    git commit -m "source: update"

    # Update filter and pull changes
    git checkout target
    git subproject pull my-subproject --filter-is-regexp --filter="^.*\.new" || return $?

    # Assert
    # ...file has been renamed locally
    if [[ ! -f my-subproject/subtree.new ]]; then
        echo "missing subtree.new"
        return 1
    fi
    if [[ -f my-subproject/subtree.old ]]; then
        echo "unexpected file subtree.old"
        return 1
    fi
    
    # ... subtree.new content matches
    diff -c - my-subproject/subtree.new << EOF || return $?
source file
EOF

    # Add subtree.old again
    git checkout source
    echo "back again" > subtree/subtree.old
    git add -A
    git commit -m "source: add subtree.old again"

    # Pull subproject changes
    git checkout source
    git subproject pull my-subproject
    
    # Assert subproject.old has not been pulled again
    if [[ -f my-subproject/subtree.old ]]; then
        echo "unexpected file subtree.old"
        return 1
    fi
}

invoke-test $@