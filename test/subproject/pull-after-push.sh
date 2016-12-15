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
    echo -e "b\nc\nd" > subtree/subtree.txt
    git add -A
    git commit -m "source: initial commit"

    # Initialize target branch
    git checkout --orphan target
    echo "target branch" > file.txt
    git add -A
    git commit -m "target: initial commit"

    # Initialize subproject
    git subproject init my-subproject source --their-prefix=subtree || return 1

    # Update source 
    git checkout source
    echo -e "e" >> subtree/subtree.txt
    git add -A
    git commit -m "source: append 'e'"

    # Change target's version of my-subproject before pulling again
    git checkout target
    sed -i -r 's/c/x/g' my-subproject/subtree.txt
    git add -A
    git commit -m "target: replace 2nd line 'c' with 'x'"

    # Update my-subproject
    git subproject pull my-subproject || return 1
    
    diff -c - my-subproject/subtree.txt << EOF
b
x
d
e
EOF
    
    [[ $? -eq 0 ]] || return 1
    
    # Push merged state to source
    git subproject push my-subproject || return 1
    
    # Now change 2nd line in source (x->y)
    git checkout source
    echo -e "b\ny\nd\ne" > subtree/subtree.txt
    git add -A
    git commit -m "source: replace 2nd line 'x' with 'y'"
    
    # Pull again - their should be no conflict (no local changes)!
    git checkout target
    git subproject pull my-subproject --diff3 || return 1

    # Assert
    diff -c - my-subproject/subtree.txt << EOF
b
y
d
e
EOF
    
    return $?
}

invoke-test $@