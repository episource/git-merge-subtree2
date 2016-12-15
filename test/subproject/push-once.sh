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

    # Update subproject within target branch
    git checkout target
    echo -en "\ne\n" >> my-subproject/subtree.txt
    git add -A
    git commit -m "target: update my-subtree"

    # Push changes
    git subproject push my-subproject

    # Assert
    CURRENT_BRANCH=$( git symbolic-ref --short HEAD )
    [[ "$CURRENT_BRANCH" == "target" ]] || return 1
    
    git checkout source
    diff -c - subtree/subtree.txt << EOF
b
c
d
e
EOF
    
    return $?
}

invoke-test $@