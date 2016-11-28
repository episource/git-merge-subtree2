#!/bin/bash
# This test adds the subdirectory "subtree" of branch 'source' 
# (source:subtree) as subproject "my-subproject" of branch target 
# (target:my-subproject). Later on source is changed, but the changes are undone
# with the next commit. The next pull operation should be refused with a message
# indicating, that there's nothing to pull.

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
    echo -en "a\n$(cat subtree/subtree.txt)" > subtree/subtree.txt
    git add -A
    git commit -m "source: update"
    
    # Revert source changes
    git revert --no-edit HEAD

    # Re-Merge source:subtree
    git checkout target
    PULL_STDERROUT=$( git subproject pull my-subproject 2>&1 )
    [[ $? -eq 0 ]] && return 1

    echo "$PULL_STDERROUT" | tee /proc/self/fd/2 | grep -qi "no changes to pull/push"
    return $?
}

invoke-test $@