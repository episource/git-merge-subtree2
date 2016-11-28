#!/bin/bash
# This test merges the sub-directory "subtree" of repository/branch repo1/master
# into the sub-directory "my-repo1-subtree" of repository/branch repo2/master.
# Later on a conflict is provoked by prepending a line to repo1's version and
# appending a line to repo2's version. A second merge should succeed with the
# conflict being resolved automatically.

SCRIPT_DIR=$( dirname $( readlink -e $0 ) )
. "$SCRIPT_DIR/../_utils.sh"

function the-test() {
    # Initialize first repo
    mkdir -p repo1/subtree && cd repo1
    git init
    echo -en "b\nc\nd" > subtree/subtree.txt
    git add -A
    git commit -m "repo1: initial commit"

    # Initialize second repo
    mkdir -p ../repo2 && cd ../repo2
    git init
    echo "some existing content" > repo2.txt
    git add -A
    git commit -m "repo2: initial commit"

    # Merge repo1/subtree to sub-directory "my-repo1-subtree"
    git remote add repo1 ../repo1
    git fetch repo1
    git merge --allow-unrelated-histories --no-edit -s subtree2 -Xtheir-prefix=subtree -Xmy-prefix=my-repo1-subtree repo1/master

    # Update repo1
    cd ../repo1
    echo -en "a\n$(cat subtree/subtree.txt)" > subtree/subtree.txt
    git add -A
    git commit -m "repo1: update"

    # Update subtree within repo2
    cd ../repo2
    echo -en "\ne\n" >> my-repo1-subtree/subtree.txt
    git add -A
    git commit -m "repo2: update repo's 1 subtree"

    # Re-Merge repo1/subtree
    git fetch repo1
    git merge --no-edit -s subtree2 -Xtheir-prefix=subtree -Xmy-prefix=my-repo1-subtree repo1/master

    # Assert
    diff -c - my-repo1-subtree/subtree.txt << EOF
a
b
c
d
e
EOF
    
    return $?
}

invoke-test $@