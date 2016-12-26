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
    git subproject init my-subproject source --their-prefix=subtree --filter="^.*\.txt"
    
    # Ensure only subtree.txt was pulled
     if [[ ! -f my-subproject/subtree.txt ]]; then
        echo "missing subtree.txt"
        return 1
    fi
    if [[ -f my-subproject/subtree.ex ]]; then
        echo "unexpected file subtree.ex"
        return 1
    fi
    
    # Update source - change only excluded files, so that push without pull is
    # possible    
    git checkout source
    echo "changed there" > subtree/subtree.ex
    git add -A
    git commit -m "source: update"

    # Update subproject within target branch
    git checkout target
    echo -en "\ne\n" >> my-subproject/subtree.txt
    echo "changed here" > subtree/subtree.ex
    git add -A
    git commit -m "target: update my-subproject"

    # Push changes
    git subproject push my-subproject || return $?

    # Assert
    CURRENT_BRANCH=$( git symbolic-ref --short HEAD )
    [[ "$CURRENT_BRANCH" == "target" ]] || return 1
    
    git checkout source
    
    # ... subtree.ex has been left unchanged
    diff -c - subtree/subtree.ex << EOF || return $?
changed there
EOF
    
    # ... subtree.txt has been updated
    diff -c - subtree/subtree.txt << EOF
b
c
d
e
EOF
    
    return $?
}

invoke-test $@