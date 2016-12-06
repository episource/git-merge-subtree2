#!/bin/bash

SCRIPT_DIR=$( dirname $( readlink -e $0 ) )
. "$SCRIPT_DIR/../_utils.sh"

function the-test() {
    # Initialize repo
    mkdir -p repo && cd repo
    git init
    
    # Initialize source branch
    git checkout --orphan source
    mkdir subtree1 subtree2
    echo -en "b\nc\nd" > subtree1/subtree.txt
    echo -en "e\nf\ng" > subtree2/subtree.txt
    git add -A
    git commit -m "source: initial commit"

    # Initialize target branch
    git checkout --orphan target
    echo "target branch" > file.txt
    git add -A
    git commit -m "target: initial commit"

    # Initialize subprojects
    git subproject init my-subproject1 source --their-prefix=subtree1
    git subproject init my-subproject2 source --their-prefix=subtree2

    # Update subprojects within target branch
    git checkout target
    echo -en "\ne\n" >> my-subproject1/subtree.txt
    echo -en "\nh\n" >> my-subproject2/subtree.txt
    git add -A
    git commit -m "target: update my-subtree"

    # Push changes
    git subproject push my-subproject1
    git subproject push my-subproject2

    # Assert
    CURRENT_BRANCH=$( git symbolic-ref --short HEAD )
    [[ "$CURRENT_BRANCH" == "target" ]] || return 1
    
    git checkout source
    diff -c - subtree1/subtree.txt << EOF || return 1
b
c
d
e
EOF
    diff -c - subtree2/subtree.txt << EOF
e
f
g
h
EOF
    
    return $?
}

invoke-test $@