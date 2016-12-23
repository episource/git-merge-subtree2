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
    echo -en "a\n$(cat subtree/subtree.txt)\nx\n" > subtree/subtree.txt
    git add -A
    git commit -m "source: update"

    # Update subtree within target branch
    git checkout target
    echo -en "\ne\n" >> my-subproject/subtree.txt
    git add -A
    git commit -m "target: update my-subtree"

    # Re-Merge source:subtree => expect conflict!
    STD_ERROUT=$( git subproject pull my-subproject 2>&1 )
    [[ $? -ne 1 ]] && return 1
    echo "$STD_ERROUT" | tee /proc/self/fd/2 | grep -qi "unmerged files" || return 1
    [[ "$(git diff --diff-filter=U --name-only)" == *my-subproject/subtree.txt ]] || return 1
    
    # Try to continue without resolving the conflicts => expect error
    STD_ERROUT=$( git subproject continue 2>&1 )
    [[ $? -ne 1 ]] && return 1
    echo "$STD_ERROUT" | tee /proc/self/fd/2 | grep -qi "unmerged files" || return 1
    
    # Resolve conflicts & finalize pull
    git checkout --theirs -- my-subproject/subtree.txt
    git add my-subproject/subtree.txt
    git subproject continue

    # Assert
    diff -c - my-subproject/subtree.txt << EOF
a
b
c
d
x
EOF
    
    return $?
}

invoke-test $@