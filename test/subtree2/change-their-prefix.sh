#!/bin/bash
# This test merges the sub-directory "subtree" of branch 'source' 
# (source:subtree) into the sub-directory "my-subtree" of branch target
# (target:my-subtree). Later on source:subtree is renamed to source:subtree2 and
# a resolvable conflict is provoked by prepending a line to source's version and
# appending another line to target's version. A second merge should succeed when
# -Xbase-prefix=subtree is provided explicitly.

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
    >&2 echo "a"
    git add -A
    >&2 echo "b"
    git commit -m "source: initial commit"
    >&2 echo "c"

    # Initialize target branch
    git checkout --orphan target
    echo "target branch" > file.txt
    git add -A
    git commit -m "target: initial commit"

    # Merge source:subtree to sub-directory "my-subtree"
    git merge --allow-unrelated-histories --no-edit -s subtree2 -Xtheir-prefix=subtree -Xmy-prefix=my-subtree source

    # Update and rename source 
    git checkout source
    mv subtree subtree2
    echo -en "a\n$(cat subtree2/subtree.txt)" > subtree2/subtree.txt
    git add -A
    git commit -m "source: update"

    # Update subtree within target branch
    git checkout target
    echo -en "\ne\n" >> my-subtree/subtree.txt
    git add -A
    git commit -m "target: update my-subtree"

    # Re-Merge source:subtree
    git merge --no-edit -s subtree2 -Xbase-prefix=subtree -Xtheir-prefix=subtree2 -Xmy-prefix=my-subtree source

    # Assert
    diff -c - my-subtree/subtree.txt << EOF
a
b
c
d
e
EOF
    
    return $?
}

invoke-test $@