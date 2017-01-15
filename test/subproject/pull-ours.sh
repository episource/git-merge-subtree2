#!/bin/bash
# This test adds the subdirectory "subtree" of branch 'source' 
# (source:subtree) as subproject "my-subproject" of branch target 
# (target:my-subproject). Later on a resolvable conflict is provoked by
# prepending a line to source's version and appending another line to target's
# version. The next pull operation is expected to succeed.

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

    # Update source 
    git checkout source
    echo "greetings from source branch" > subtree/subtree.txt
    git add -A
    git commit -m "source: update"

    # Update subtree within target branch
    git checkout target
    echo "greetings from target branch" > my-subproject/subtree.txt
    git add -A
    git commit -m "target: update my-subtree"

    # Merge using theirs
    git subproject pull my-subproject --ours || return 1
    
    # Assert theirs
    diff -c - my-subproject/subtree.txt << EOF
greetings from target branch
EOF
    
    return $?
}

invoke-test $@