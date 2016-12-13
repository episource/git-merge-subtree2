#!/bin/bash

SCRIPT_DIR=$( dirname $( readlink -e $0 ) )
. "$SCRIPT_DIR/../_utils.sh"

function the-test() {
    # Initialize first repo
    mkdir -p repo1/subtree && cd repo1
    git init
    echo -en "b\nc\nd\n" > subtree/subtree.txt
    git add -A
    git commit -m "repo1: initial commit"

    # Initialize second repo
    mkdir -p ../repo2 && cd ../repo2
    git init
    echo "some existing content" > repo2.txt
    git add -A
    git commit -m "repo2: initial commit"
    
    # Add repo1/subtree as subproject to repo2
    git remote add repo1 ../repo1
    git fetch repo1
    git subproject init my-subproject remotes/repo1/master --their-prefix=subtree || return $?
    
    # Assert
    diff -c - my-subproject/subtree.txt << EOF
b
c
d
EOF
    
    return $?
}

invoke-test $@