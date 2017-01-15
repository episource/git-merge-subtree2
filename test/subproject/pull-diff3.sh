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

    # Re-Merge source:subtree => expect conflict!
    STD_ERROUT=$( git subproject pull my-subproject --diff3 2>&1 )
    [[ $? -ne 1 ]] && return 1
    echo "$STD_ERROUT" | tee /proc/self/fd/2 | grep -qi "unmerged files" || return 1
    [[ "$(git diff --diff-filter=U --name-only)" == *my-subproject/subtree.txt ]] || return 1
    
    # Assert diff3 conflict markers
    diff -c - my-subproject/subtree.txt << EOF
<<<<<<< yours
greetings from target branch
||||||| base
b
c
d
=======
greetings from source branch
>>>>>>> theirs
EOF
    
    return $?
}

invoke-test $@